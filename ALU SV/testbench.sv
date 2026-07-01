// Code your testbench here
// or browse Examples

`timescale 1ns/1ns
`define TIME_PERIOD 10
`define num_of_trans 5
`define finish_time ((`num_of_trans*`TIME_PERIOD)+50)

//------------------INTERFACE-----------------------
interface my_if(input bit clk, input bit reset);
  
//   enum {ADD,SUB,MUL,DIV}modsel;
  
  logic [3:0] val1;
  logic [3:0] val2;
  logic [7:0] res1;
  logic [7:0] res2;
  logic [1:0] modsel;
  
  
  clocking cb @(posedge clk);
    input res1,res2;
    output val1,val2,modsel;
  endclocking
  
  modport DUT ( input val1,val2,modsel,
               output res1,res2);
  modport TB (clocking cb);
    endinterface
    
//------------------CLASS DEF----------------------
    //--------------TRANSACTION CLASS--------------
    
    class transaction;
  rand logic [3:0] val1;
  rand logic [3:0] val2;
  logic [7:0] res1;
  logic [7:0] res2;
  randc logic [1:0] modsel;
      
       constraint add {if (modsel==1||modsel==3) val1>val2;if(modsel==3) val2>0;}
      
      covergroup cg_modsel;
        option.goal = 100;
        option.per_instance = 1;
        
        cp_mod: coverpoint modsel {
          option.weight = 0;
          
          bins valid_mod[] = {[0:3]};
        }
        
        cp_val1: coverpoint val1 {
          bins min = {0};
          bins max = {15};
          bins middle_values = {[1:14]};
        }
        
        cp_val2: coverpoint val2 {
          bins min = {0};
          bins max = {15};
          bins middle_values = {[1:14]};
        }
        
        
      endgroup: cg_modsel
      
      function new();
      cg_modsel = new();
      endfunction
      
      function void print_cov;
        $display ("COV IS = %0f",cg_modsel.get_coverage());
        $display ("INST COV IS = %0f",cg_modsel.get_inst_coverage());
//         $display ("HITCOUNT IS = %0f",cg_modsel.cp_mod.get_hitcount());
//         $display ("INST HIT CoUNT IS = %0f",cg_modsel.cp_mod.get_inst_hitcount());
      endfunction
          
     
    endclass
    //---------------GENERATOR--------------------
    class generator;
      mailbox #(transaction) gen2drv;
      transaction tr1;
      
      function new(mailbox #(transaction) gen2drv);
        this.gen2drv = gen2drv;
      endfunction
      
      task run ();
        transaction tr_copy;
        string testcase;
        if (!$value$plusargs("testcase=%s",testcase))
          testcase = "default";
        
        tr1 = new();
        
//         tr1.cg_modsel = new();
        
        
        repeat (`num_of_trans) begin
          
          
        case (testcase)
          
          "max_boundary": begin
            tr1.add.constraint_mode(0);
            ass1 : assert (tr1.randomize() with {val1==15;val2==15;}); end 
          
           "min_boundary": begin
             tr1.add.constraint_mode(0);
             ass2 : assert (tr1.randomize() with {val1==0;val2==0;});end
          
          "neg_sub": begin
            tr1.add.constraint_mode(0);
            ass3 : assert (tr1.randomize() with {val1<val2;modsel==1;});end
            
           
            default : begin
              tr1.add.constraint_mode(1);
              ass4 : assert (tr1.randomize()); end
          endcase
          
          tr_copy=new tr1;
                                     
          gen2drv.put(tr_copy);
          $display ("AFT RAND VALUE @%0t:%p",$time,tr_copy);
        end
         
      endtask
    endclass
    
    //----------------DRIVER------------------------
    
    class driver;
      virtual my_if vif;
      mailbox #(transaction) gen2drv;
      transaction tr1;
      
      function new(mailbox #(transaction) gen2drv,virtual my_if vif);
        this.vif = vif;
        this.gen2drv = gen2drv;
      endfunction
      
      task run();
        
        forever begin
        
        gen2drv.get(tr1);
          @(vif.cb);
        vif.val1=tr1.val1;
        vif.val2=tr1.val2;
        vif.modsel=tr1.modsel;
          $display("---------------------------");
          $display ("DRV @%0t: val1 =%0d val2=%0d modesel=%0d",$time,vif.val1,vif.val2,vif.modsel);
        end
      endtask
      
    endclass
    
    //------------------monitor--------------------
    
    class monitor;
      
      mailbox #(transaction) mon2scb;
      virtual my_if vif;
      transaction tr2;
      
      function new(mailbox #(transaction) mon2scb,virtual my_if vif);
        this.vif = vif;
        this.mon2scb = mon2scb;
      endfunction
      
      task run();
        
        forever begin
        
        tr2 = new();
        @(vif.cb);
          @(negedge vif.clk);
          
        tr2.val1 = vif.val1;
        tr2.val2 = vif.val2;
        tr2.modsel = vif.modsel;
        tr2.res1 = vif.res1;
        tr2.res2 = vif.res2;
        mon2scb.put(tr2);
          $display ("MON @%0t: tr2 -> %p",$time,tr2);
        end
      endtask
    endclass
    
    //------------------SCOREBOARD ---------------
    
    class scoreboard;
      mailbox #(transaction) mon2scb;
      transaction tr2;
      logic [7:0] exp_res1;
      logic [7:0] exp_res2;
      int pass;
      int fail;
         
      function new(mailbox #(transaction) mon2scb);
        this.mon2scb = mon2scb;
      endfunction
      
      task run ();
        
        forever begin 
          
        #1;
        tr2 = new();   
        mon2scb.get(tr2);
          tr2.cg_modsel.sample();
          tr2.print_cov;
        case (tr2.modsel)
      
      0: exp_res1 = tr2.val1+tr2.val2;
      1: exp_res1 = tr2.val1-tr2.val2;
      2: exp_res2 = tr2.val1*tr2.val2;
      3: exp_res2 = tr2.val1/tr2.val2;
      
      default:$display ("INVALID MOD");
        endcase
        
        if (tr2.modsel==0 || tr2.modsel==1) begin
          if (exp_res1 === tr2.res1)begin
            $display ("SB:ADD/SUB MATCHED");
            pass++;end
        else begin
          $display ("SB:ADD/SUB MISMATCHED TR.RES1=%0d EXP_RES1=%0d",tr2.res1,exp_res1);
          fail++;end
        end
        else begin
          if (exp_res2 === tr2.res2) begin
            $display ("SB:MUL/DIV MATCHED");
            pass++; end
        else begin
          $display ("SB:MUL/DIV MISMATCHED TR.RES2=%0d EXP_RES2=%0d",tr2.res2,exp_res2);
          fail++;end 
        end
        end
        $display("------------tr.end--------------");
      endtask
      
      function void pass_fail_count();
        $display ("\n TOTAL PASS=%0d TOTAL FAIL=%0d\n",pass,fail);
    endfunction
      
        endclass
        
        //-------------environment------------------
class environment;
  
  mailbox #(transaction) gen2drv;
  mailbox #(transaction) mon2scb;
  virtual my_if vif;
  
  generator g1;
  driver d1;
  monitor m1;
  scoreboard sb1;
  
  function new(virtual my_if vif);
    gen2drv = new();
    mon2scb = new();
    this.vif = vif;
    
    g1 = new(gen2drv);
    d1 = new(gen2drv,vif);
    m1 = new(mon2scb,vif);
    sb1 = new(mon2scb);
  endfunction
  
  task run();
    
    fork
     g1.run();
    d1.run();
    m1.run();
    sb1.run();
    join
  endtask
  
endclass
    

    
    //----------------Program-----------------------
    
    program automatic test(my_if.TB test_if);
      environment e1;
      
      initial begin
        
        e1=new(test_if);
        fork
          e1.run();
           wait (`num_of_trans==(e1.sb1.pass+e1.sb1.fail));
        join_any
        $display("\nEND TIME: %0t",$time);
         disable fork;
         end
      
      final begin
        e1.sb1.pass_fail_count();
      end
       
    endprogram
    
    //-------------------TOP ----------------------
    
    
    module top;
      bit clk;
      bit reset;
      
      my_if p_if(clk,reset);
      ALU dut (p_if);
      test t1 (p_if.TB);
      
      initial begin
        forever #(`TIME_PERIOD/2) clk = ~clk;
      end
      
      initial begin
       
       #`finish_time $finish;
      end
      
//       initial begin
//         reset = 1;
//         @(p_if.cb);
//         reset = 0;
//       end
      
      initial begin
        $dumpfile ("dumpfile.vcd");
        $dumpvars;
      end
      endmodule
               
//--------------------END-------------------------------------------------OVER-----------------------------------------------FINISH-------------------------