module top
  (
    input clk,
    output [5:0] led
  );

  localparam [23:0] WAIT_TIME = 24'd13500000;   // 0.5 s per step
  reg [2:0]  ledCounter   = 3'd0;                // 3 bits: enough for 4
  reg [23:0] clockCounter = 24'd0;

  always @(posedge clk)
  begin
    if (clockCounter == WAIT_TIME)
    begin
      clockCounter <= 24'd0;
      if (ledCounter == 3'd4)
        ledCounter <= 3'd0;                   
      else
        ledCounter <= ledCounter + 3'd1;
    end
    else
      clockCounter <= clockCounter + 24'd1;
  end

  assign led = {3'b111, ~ledCounter};
endmodule