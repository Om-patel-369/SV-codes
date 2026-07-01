// Code your testbench here
// or browse Examples
//-----------------MACRO-------------------------
`timescale 1ns/1ns
`define rep 10
`define time_period 10
`define finish_time ((`time_period*`rep)+100)
//---------------interface----------------------

interface ram_if #(ADD_WIDTH = 8,DATA_WIDTH = 32)(input bit clk,input bit reset);
  
  logic [ADD_WIDTH-1:0]add;
  logic [DATA_WIDTH-1:0]din;//write
  logic [DATA_WIDTH-1:0]dout;//read
  bit w_en;
  bit r_en;
  
  clocking cb @(posedge clk);
    input dout;
    output add,din,w_en,r_en;
    endclocking
  
  clocking cb1 @(posedge clk);
    output dout;
    input add,din,w_en,r_en;
    endclocking

  
//   modport DUT (clocking cb1,input clk,input reset);
//     modport TB (clocking cb, output clk,output reset);
   
    endinterface
//--------------------transaction------------------

      class transaction #(ADD_WIDTH=8,DATA_WIDTH=32);
  rand logic [ADD_WIDTH-1:0]add;
  rand logic [DATA_WIDTH-1:0]din;
       logic [DATA_WIDTH-1:0]dout;
       bit w_en;
       bit r_en;
  
   bit count;//for w-r-w seq.
  
  function pre_randomize();
     count=~count;
    if (count) begin
    w_en=1;
    r_en=0;end
    
     else begin
      w_en=0;
      add.rand_mode(0);
      r_en=1; end
   endfunction
        
        function post_randomize();
          add.rand_mode(1);
   endfunction
                          
  
endclass
//------------------generator-----------------------
    
    class generator;
      mailbox #(transaction) gen2drv;
      transaction tr1;
      transaction copy_tr1;
      
      function new(mailbox #(transaction) gen2drv);
        this.gen2drv = gen2drv;
      endfunction
      
      task run;
        tr1 = new();
        
        repeat (`rep) begin
         
          tr1_rand_assert: assert (tr1.randomize());
          copy_tr1=new tr1;
          gen2drv.put(copy_tr1);
          $display ("@%0t GEN:\n tr1=%p",$time,copy_tr1);
          
        end
      endtask
    endclass
    
//-------------------driver------------------------
    
    class driver;
      virtual ram_if vif;
      transaction tr1;
      mailbox #(transaction) gen2drv;
      
      function new ( mailbox #(transaction) gen2drv,virtual ram_if vif);
        this.gen2drv = gen2drv;
        this.vif = vif;
      endfunction
      
      task run();
        wait(vif.reset==0);
        forever begin
          gen2drv.get(tr1);
 // drive data@every +ve -edge
          @(vif.cb);
          
        vif.add=tr1.add;
        vif.din=tr1.din;
        vif.w_en=tr1.w_en;
        vif.r_en=tr1.r_en;
        
        $display ("@%0t DRV:ADD=%0d DIN=%0d W_EN=%0d R_EN=%0d",$time,vif.add,vif.din,vif.w_en,vif.r_en);
        end 
      endtask
    endclass
    
//-----------------monitor-------------------------
    class monitor;
      virtual ram_if vif;
      transaction rec_tr; 
      mailbox #(transaction) mon2scb;
      
      function new (mailbox #(transaction) mon2scb,virtual ram_if vif);
        this.mon2scb = mon2scb;
        this.vif = vif;
      endfunction
      
      task run();
        wait(vif.reset==0);
        forever begin
          rec_tr = new();
          
           @(vif.cb); //similar to @posedge vif.clk? 
          
          // Sample on each Negative edge clock
          @(negedge vif.clk); //direct this,work?
          rec_tr.din=vif.din;
          rec_tr.add=vif.add;
          rec_tr.w_en=vif.w_en;
          rec_tr.r_en=vif.r_en;
          rec_tr.dout=vif.dout; 

         mon2scb.put(rec_tr);
        $display ("@%0t MON:%p",$time,rec_tr);
        end
      endtask
    endclass
//------------------scoreboard----------------------
  
      class scoreboard #(DATA_WIDTH=32,ADD_WIDTH=8);
      mailbox #(transaction) mon2scb;
      transaction sb_tr;
        logic [DATA_WIDTH-1:0] exp_write;
        logic [DATA_WIDTH-1:0] exp_read;
        int match;
        int mismatch;
        int no_of_trans;
        
  logic [DATA_WIDTH-1:0]exp_mem[(2**ADD_WIDTH)-1:0];
      
      function new(mailbox #(transaction) mon2scb);
        this.mon2scb = mon2scb;
      endfunction
            
      task run();
        forever begin
          
          mon2scb.get(sb_tr);
          $display ("@%0t SB get : Add = %0h, Data in = %0h, w_en = %0b, r_en = %0b, Dout = %0h",$time,sb_tr.add,sb_tr.din,sb_tr.w_en,sb_tr.r_en,sb_tr.dout);
          no_of_trans++;
          
          if (sb_tr.w_en)
            exp_mem[sb_tr.add]=sb_tr.din;
          else if (sb_tr.r_en) begin
            exp_read=exp_mem[sb_tr.add];
          if (exp_read==sb_tr.dout) begin
                match++;
            $display ("MATCHED"); end
            else begin
              mismatch++;
              $display ("MISMATCHED EXP:%0d GOT:%0d",exp_read,sb_tr.dout); end end
            
          else 
            $display ("SB:write & read both disabled"); 
        end    
      endtask
    endclass
        
//--------------------- environment----------------------

      class environment;
  mailbox #(transaction) gen2drv;
  mailbox #(transaction) mon2scb;
  virtual ram_if vif;
        
        generator g1;
        driver d1;
        monitor m1;
        scoreboard sb1;
        
        function new(virtual ram_if vif);
          this.vif = vif;
          gen2drv = new();
          mon2scb = new();
          
          g1=new(gen2drv);
          d1=new(gen2drv,vif);
          m1=new(mon2scb,vif);
          sb1=new(mon2scb);
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
//---------------------program test -------------------
    
program test (ram_if tb_if);

      environment e1;
      
      initial begin
        
        e1 = new(tb_if);
        
        fork
        e1.run();
          wait (e1.sb1.no_of_trans==`rep);
        join_any
        disable fork;
      end
          
        final begin
        $display ("PASS COUNT:%0d  FAIL COUNT:%0d",e1.sb1.match,e1.sb1.mismatch);
      end
    endprogram
    
 //---------------------top --------------------------
    
    module top;
      bit clk;
      bit reset;
      
      ram_if p_if(clk,reset);
      ram dut (p_if);
      test t1 (p_if);
      
      initial begin
        forever #(`time_period/2) clk =~clk;
      end
      
      initial begin
        reset = 1;
        $display ("@%0t:RESET",$time);
        @(p_if.cb);
        reset = 0;
        $display ("@%0t:RESET released",$time);
      end
      
      initial begin
        #`finish_time $finish;
      end
      
      initial begin
        $dumpfile ("dumpfile.vcd");
        $dumpvars;
      end
      
      
      endmodule
