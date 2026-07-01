// Code your design here

//add interface

module ram(m_if.DUT itf);
  
  logic [31:0] mem [256];
  
  always @(posedge itf.clk or posedge itf.reset) begin
    if(itf.reset)
      itf.dut_cb.dout <= 0;
    
      else begin
        
        if(itf.dut_cb.w_en)begin
          mem[itf.dut_cb.addr]=itf.dut_cb.din;
        end
        else
          itf.dut_cb.dout <= mem[itf.dut_cb.addr];
      end
  end
endmodule
    
          
        