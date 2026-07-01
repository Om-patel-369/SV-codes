// Code your testbench here
// or browse Examples


`define rep 17
`define time_period 10
`define finish ((`rep *`time_period)+10); 


//____________________INTERFACE_____________________

interface fifo_if #(ADD_WIDTH=8,DATA_WIDTH=32)
                 (input bit clk,input bit reset);
  
  
    logic [DATA_WIDTH-1:0] w_data;
    logic [DATA_WIDTH-1:0] r_data;
    bit w_en;
    bit r_en;
    bit full;
    bit empty;
  
  
  clocking cb1 @(negedge clk); //changed
    input w_data,w_en,r_en;
    output r_data;
  endclocking
  
  clocking cb2 @(posedge clk);
    output w_data,w_en,r_en;
    input full,empty,r_data;
  endclocking
  
//   modport DUT (clocking cb1,input reset,input clk);
//     modport TB (clocking cb2,input reset,input clk);
    
  endinterface
      
//__________________TRANSACTION________________________
      
    class transaction#(ADD_WIDTH=8,DATA_WIDTH=32);
    rand logic [DATA_WIDTH-1:0] w_data;
    logic [DATA_WIDTH-1:0] r_data;
    rand bit w_en;
    rand bit r_en;
    bit full;
    bit empty;
    int count;
      
      constraint c_en { (w_en==0)<->(r_en==1);
                    (r_en==0)<->(w_en==1);
                   w_data inside {[1:1000]};}
    //  constraint c_full {if (count>=`rep/2) r_en==1; else w_en==1;}
      
      // For generating Write-Read-Write
//       constraint c_full_empty { if(count%ADD_WIDTH == 0) w_en==0; else r_en==0;}
        
    endclass
//___________________GENERATOR_______________     
     class generator;
       mailbox #(transaction) gen2drv;
       transaction t1,copy_t;
       
       function new(mailbox #(transaction) gen2drv);
         this.gen2drv=gen2drv;
       endfunction
       
       task run();
         
         t1 = new();
         repeat(`rep) begin
           
           
           rand_ass: assert (t1.randomize());
           t1.count++;
           $display("@%0t GEN: %p",$time,t1);
           copy_t = new t1;
           gen2drv.put(copy_t); end
       endtask
       
       endclass
 //_________________________DRIVER_____________________
      
      class driver;
       mailbox #(transaction) gen2drv;
       virtual fifo_if vif;
       transaction t1;
       
       function new(mailbox #(transaction) gen2drv,virtual fifo_if vif);
         this.gen2drv=gen2drv;
         this.vif=vif;
       endfunction
       
       task run();
         wait(vif.reset==0);
         $display("\n@%0t DRV: reset over\n", $time);
         
         forever begin
           gen2drv.get(t1);
//            @(vif.cb2);
            
           vif.w_data=t1.w_data;
           vif.w_en= t1.w_en;
           vif.r_en= t1.r_en;
           $display("@%0t DRV:W_data=%0d  w_en=%0d r_en=%0d",$time,vif.w_data,vif.w_en,vif.r_en);
           @(vif.cb2);
         end
       endtask
       endclass
//________________________MONITOR_________________________
   class monitor;
     mailbox #(transaction) mon2scb;
       virtual fifo_if vif;
       transaction t1;
     
     function new(mailbox #(transaction) mon2scb,
                    virtual fifo_if vif);
         this.mon2scb=mon2scb;
         this.vif=vif;
       endfunction
     
     task run ();
       wait(vif.reset==0);
       forever begin
         t1=new();
         @(vif.cb2);
//          @(negedge vif.clk);
       t1.w_data=vif.w_data;
       t1.w_en=vif.w_en;
       t1.r_en=vif.r_en;
       t1.r_data=vif.r_data;
         t1.full=vif.full;
         t1.empty=vif.empty;
       
         $display("@%0t MON:%p",$time,t1);   
       mon2scb.put(t1);
       end
     endtask
   endclass
      
//______________________SCOREBOARD________________________
      
      class scoreboard #(ADD_WIDTH=8,DATA_WIDTH=32);
       mailbox #(transaction) mon2scb;
        transaction t1;
        logic [DATA_WIDTH-1:0] exp_mem[$];//for ref.
        logic [DATA_WIDTH-1:0] exp_read;
        int match;
        int mismatch;
        
        
        function new(mailbox #(transaction) mon2scb);
          this.mon2scb=mon2scb;
        endfunction
        
        task run();
          forever begin
            mon2scb.get(t1);
            $display ("@%0t SB:packet %p\n",$time,t1);
            
           if (t1.w_en && !t1.full)
              exp_mem.push_back(t1.w_data);
          else if (t1.r_en && !t1.empty) begin
              exp_read=exp_mem.pop_front();
                if(exp_read==t1.r_data) begin
                  $display ("SB:MATCHED");
                match++;end
                else begin
                  $display ("SB:MIS-MATCH");
                mismatch++; end
            end
          end
        endtask
          
          function void print();
            $display ("TOTAL PASS=%0d TOTAL FAIL=%0d",match,mismatch);
            endfunction
          
      endclass
        
//________________environment________________________
      
      class environment;
        virtual fifo_if vif;
        mailbox #(transaction) gen2drv;
        mailbox #(transaction) mon2scb;
        generator g1;
        driver d1;
        monitor m1;
        scoreboard sb1;
        
        function new(virtual fifo_if vif);
          this.vif = vif;
          gen2drv=new();
          mon2scb=new();
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
//______________PROGRAM TEST BLOCK____________________
      
      program automatic test(fifo_if p_if);
        environment e1;
        
        initial begin
          e1=new(p_if);
            
          e1.run();

            end
            
            final begin
              e1.sb1.print();
            end
            endprogram
//__________________TOP MODULE______________________
            
            module top;
              
              bit clk;
              bit reset;
              
              fifo_if p_if(clk,reset);
              test t1 (p_if);
              fifo f1 (p_if);
              
              initial begin
                forever #(`time_period/2) clk=~clk;
              end
              
              initial begin
                reset = 1;
                @(posedge clk);
                 reset=0;
              end
              
              initial begin
                #`finish $finish;
              end
              
             initial begin
                $dumpfile("dump.vcd");
                $dumpvars;
              end
            endmodule
            
//__________________CODE ENDS HERE___________________       