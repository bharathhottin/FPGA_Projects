module top
  (
    input clk,
    output [5:0] led
  );

  localparam WAIT_TIME = 13500000;    // 0.5 s per step at 27 MHz
  reg [5:0]  ledCounter = 0;          // 6 bits: 0..63
  reg [23:0] clockCounter = 0;
  reg        countUp = 1;             // 1 = counting up, 0 = counting down

  always @(posedge clk)
  begin
    clockCounter <= clockCounter + 1;
    if (clockCounter == WAIT_TIME)
    begin
      clockCounter <= 0; 

      if (countUp)
      begin
        if (ledCounter == 6'd63)
        begin
          countUp    <= 0;            // reached top: turn around
          ledCounter <= ledCounter - 1;
        end
        else
          ledCounter <= ledCounter + 1;
      end
      else
      begin
        if (ledCounter == 6'd0)
        begin
          countUp    <= 1;            // reached bottom: turn around
          ledCounter <= ledCounter + 1;
        end
        else
          ledCounter <= ledCounter - 1;
      end
    end
  end

  assign led = ledCounter;
endmodule