// Code your testbench here
// or browse Examples

interface m_if(input bit clk,input bit reset);
  
  logic [7:0] addr;
  logic [31:0] din;
  logic [31:0] dout;
  logic        w_en;
  
  clocking tb_cb @(posedge clk);
    input dout;
    output addr,din,w_en;    
  endclocking
  
  clocking mon_cb @(negedge clk);
    input addr,din,dout,w_en;
  endclocking
  
  clocking dut_cb @(posedge clk);
    input addr,din,w_en;
    output dout;
  endclocking

  
  modport TB (clocking mon_cb,clocking tb_cb,input clk,input reset);
    modport DUT (clocking dut_cb,input clk,input reset);
  
endinterface

class transaction;
  
  rand bit [7:0] addr;
  rand bit [31:0] data;
  rand bit        w_en;
  bit [31:0] d_out;
  
  constraint data_c {
    data inside {[0:100]};
    w_en == 1;
  }
  
  function new();
  endfunction
  
  
endclass

class generator;
  
  transaction tr,tr_copy;
  mailbox#(transaction) gen2drv;
  
  function new(input mailbox #(transaction) gen2drv);
    this.gen2drv = gen2drv;  
  endfunction
  
  
  task run(input int rep);
    
    repeat (rep)begin
      
      tr = new();
      assert(tr.randomize());
      tr_copy = new tr;
      gen2drv.put(tr_copy);
      
      $display($time," GEN  - tx sent is %p",tr);
      
    end
  endtask
endclass
      
//________________________________________________________________________________________________
      
class callback;

  virtual function void pre_drive_cb();
    $display (" pre-Working CB");
  endfunction
  
  virtual function void post_drive_cb();
    $display ("post-Working CB");
  endfunction
  
endclass
   //______________________________________________________________________________________________
    
class driver;
  mailbox #(transaction) gen2drv;
  virtual m_if.TB vif;
  transaction tr; 
  callback cb;
  
  function new(input mailbox #(transaction) gen2drv,virtual m_if.TB vif);
    this.gen2drv = gen2drv;
    this.vif = vif;
    cb =new();
  endfunction
  
  task run ();
    
    forever begin
    
    gen2drv.get(tr);
      $display($time,"DRV - got tx in driver");
      
      cb.pre_drive_cb(); //callback hook
    
      @(vif.tb_cb);
    vif.tb_cb.addr <= tr.addr;
    vif.tb_cb.din <= tr.data;
    vif.tb_cb.w_en <= tr.w_en;
      
      $display($time,"DRV - driven on interface");
      
      cb.post_drive_cb(); //callback hook
      
    end
  endtask
endclass
  
  class monitor;
    
  mailbox #(transaction) mon2sb;
  virtual m_if.TB vif;
  transaction tr,tr_copy;
  
    function new(input mailbox #(transaction) mon2sb,virtual m_if.TB vif);
    this.mon2sb = mon2sb;
    this.vif = vif;
  endfunction
  
  task run ();
    
    forever begin
      
      @(negedge vif.clk);
      
      tr= new ();
      
      tr.data  =  vif.mon_cb.din;
      tr.d_out = vif.mon_cb.dout;
      tr.addr = vif.mon_cb.addr;
      tr.w_en = vif.mon_cb.w_en;
            
      $display ($time," MON - rec tx is %p",tr);
      tr_copy = new tr;      
      mon2sb.put(tr_copy);      
      //@(posedge vif.clk);
      
    end
  endtask
  endclass
  
  class scoreboard;
    
    mailbox #(transaction) mon2sb;
    transaction tr;
    int pass = 0;
    int fail = 0;
    
    function new(input mailbox #(transaction) mon2sb);
      this.mon2sb = mon2sb;
    endfunction
    
    task run();
      
      bit [31:0] ref_mem [256];
      bit [31:0] ref_read;
      
      forever begin
      
      mon2sb.get(tr);
      $display($time,"SB - got tx in sb");
      
      // in golden ref model

        
        if(tr.w_en)
        ref_mem[tr.addr] = tr.data;
        
        else begin
          ref_read = ref_mem[tr.addr];
          if (ref_read ==tr.d_out) begin
          $display($time,"SB - read matched");
            pass++;end
        else begin
        $display($time,"SB - read mismatched");
          fail++;end
        
        end   
      end
    endtask
    
    function void p_f_count();
      $display(" read pass =%0d read fail =%0d",pass,fail);
    endfunction
    
  endclass
  
  class environment;
    
    mailbox #(transaction) gen2drv,mon2sb;
    virtual m_if.TB vif;
    driver drv;
    monitor mon;
    scoreboard sb;
    generator gen;
    
    function new(input virtual m_if.TB vif);
     this.vif = vif;
      gen2drv = new();
      mon2sb = new();
      gen = new(gen2drv);
      drv = new(gen2drv,vif);
      mon = new(mon2sb,vif);
      sb = new(mon2sb);
    endfunction
    
    task run();
      
      fork
        gen.run(10);
        drv.run();
        mon.run();
        sb.run();
      join
    endtask
    
  endclass
  
program tb(m_if.TB vif);
    
    environment env;
    
    initial begin
      
      env = new(vif);
      
      env.run();
    end
      
      final begin
        
        env.sb.p_f_count();
      end 
   
    
  endprogram
  
  module top;
    
    bit clk;
    bit reset;
    m_if p_if(clk,reset);
    ram dut(p_if.DUT);
    tb tbb (p_if.TB);
    
    initial begin
      clk = 0;
      forever #5 clk = ~clk;
    end
    
    initial begin
      #120 $finish;
    end
    
    initial begin
      $dumpfile("dump.vcd");
      $dumpvars(0,top); 
    end
  endmodule
      
      
