// Code your design here

//deploy full,empty features
module ram #(DATA_WIDTH=32,ADD_WIDTH=8) (ram_if dut_if);
 
  logic [DATA_WIDTH-1:0] mem [(2**ADD_WIDTH)-1:0];
  
 always @(dut_if.cb1) begin // or negedge dut_if.clk

    if (dut_if.reset) begin
      dut_if.dout<=0;
      mem = '{default:0};
    end
    
    else begin
      @(negedge dut_if.clk);
      
      if(dut_if.w_en) begin
        mem[dut_if.add] <= dut_if.din; end
      else if (dut_if.r_en) begin
        dut_if.dout <= mem[dut_if.add]; end
        else begin
          $display ("@%0t:DUT:write & read both disabled",$time);end
    end
  end
  
endmodule
      