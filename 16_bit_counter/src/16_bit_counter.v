module top
  (
    input clk,
    output [5:0] led
  );

  localparam [23:0] WAIT_TIME = 24'd13500000;   // 0.5 s per step
  reg [4:0]  ledCounter   = 5'd0;                // 5 bits: enough for 16
  reg [23:0] clockCounter = 24'd0;

  always @(posedge clk)
  begin
    if (clockCounter == WAIT_TIME)
    begin
      clockCounter <= 24'd0;
      if (ledCounter == 5'd16)
        ledCounter <= 5'd0;                     // after 16, go back to 0
      else
        ledCounter <= ledCounter + 5'd1;
    end
    else
      clockCounter <= clockCounter + 24'd1;
  end

  // LEDs are active-low: ~ makes lit = 1. Unused LEDs held off (1).
  assign led = {1'b1, ~ledCounter};
endmodule