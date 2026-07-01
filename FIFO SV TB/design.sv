// Code your design here

//w/r_clock?

module fifo#(ADD_WIDTH=3,DATA_WIDTH=32)(fifo_if mif);
  
  logic [DATA_WIDTH-1:0] mem [(2**ADD_WIDTH)-1:0];
  bit [((ADD_WIDTH)-1):0] wptr; 
  bit [((ADD_WIDTH)-1):0] rptr;
  
/*  assign empty = (wptr==rptr);
  assign full = (wptr==($clog2(ADD_WIDTH));*/
  
  
  always @(mif.cb1) begin 
  
if(mif.reset) begin //will get affected b/c of negedge?
    wptr<=0;
    rptr<=0;
    mem <= '{default:0};
    mif.r_data<=0;end
     
    else begin
//       @(mif.cb1);
//       @(negedge mif.clk);
      $display("@%0t DUT:w_data=%0d w_en=%0d r_en=%0d",$time,mif.w_data,mif.w_en,mif.r_en);
      
      if(mif.w_en && !mif.full) begin 
        mem[wptr]=mif.w_data;
//         $display("w %p",mem);
        $display("w w_ptr=%0d",wptr);
        wptr++;
        
        if(wptr==rptr) begin
         mif.full=1;
          wptr--;
          $display("full WRITE DISABLED");end
          
      end
      
      else if (mif.r_en && !mif.empty) begin
        mif.r_data=mem[rptr];
        $display("@%0t DUT:r_data=%0d rptr=%0d full mem=%p",$time,mif.r_data,rptr,mem);
        
        if(wptr==rptr) begin
         mif.empty=1;
          mif.full=0;
          $display("empty read DISABLED");end
        else
      rptr++;end
      
      else
        $display("@%0t DUT ERROR: W/R Disabled",$time);
    end
  end

//   assign mif.full= (wptr+1)==rptr;
  
     /* assign empty = wptr==rptr;
                 
      assign full= (wr_ptr[ADDR_WIDTH]!=rd_ptr[ADDR_WIDTH])&&
       (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
  assign empty= (wr_ptr == rd_ptr);    */       

                 
endmodule
        
        
      
// full - empty conditions   