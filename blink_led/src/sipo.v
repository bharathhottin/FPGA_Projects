module sipo_sr #(parameter WIDTH=16)
   (
    input wire 		     clk,
    input wire 		     reset,
    input wire 		     s_in,
    output reg [(WIDTH-1):0] p_out
   );

   always @(posedge clk)
     if (reset)
       p_out = 'b0;
     else
       p_out <= {s_in, p_out[(WIDTH-1):1]};

endmodule // sipo_sr