module top
  (
    input clk,
    output [5:0] led
  );

  localparam [23:0] WAIT_TIME = 24'd13500000;   
  reg [3:0]  ledCounter   = 4'd0;                
  reg [23:0] clockCounter = 24'd0;

  always @(posedge clk)
  begin
    if (clockCounter == WAIT_TIME)
    begin
      clockCounter <= 24'd0;
      if (ledCounter == 4'd8)
        ledCounter <= 4'd0;                   
      else
        ledCounter <= ledCounter + 4'd1;
    end
    else
      clockCounter <= clockCounter + 24'd1;
  end


  assign led = {2'b11, ~ledCounter};
endmodule