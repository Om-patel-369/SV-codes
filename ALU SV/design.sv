// Code your design here

//typedef enum {ADD,SUB,MUL,DIV} op_sel;
module ALU(my_if alu_if);
   
  always @(alu_if.cb) begin
    @(negedge alu_if.clk);
   
    $display ("DUT @%0t: val1 =%0d val2=%0d modesel=%0d",$time,alu_if.val1,alu_if.val2,alu_if.modsel);
  
    
//     if (alu_if.reset) begin
//       alu_if.res1=0;
//       alu_if.res2=0; end
//     else begin
    case (alu_if.modsel)
      
      0: alu_if.res1 = alu_if.val1+alu_if.val2;
      1: alu_if.res1 = alu_if.val1-alu_if.val2;
      2: alu_if.res2 = alu_if.val1*alu_if.val2;
      3:begin
        if (alu_if.val1==0 || alu_if.val2==0)
          $error ("INVALID INPUTS : 0 in division");
        else
          alu_if.res2 = alu_if.val1/alu_if.val2;end
        default:$display ("INVALID MOD");
      
    endcase
        $display ("DUT @%0t: RES1=%0d RES2=%0d",$time,alu_if.res1,alu_if.res2);
  end
endmodule
        
      
      
    