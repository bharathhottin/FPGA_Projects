module UartTransmitter(
    input      clk, rst,
    input      trig_inv,
    output reg tx
    );

    // FSM states
    parameter idle      = 3'b000;
    parameter start_bit = 3'b001;
    parameter data_bits = 3'b010;
    parameter stop_bit  = 3'b011;
    parameter cleanup   = 3'b100;

    // Baud generation
    parameter clk_speed  = 27000000, baud_rate = 115200; // FPGA clk speed and UART baud
    parameter clk_cycles = clk_speed/baud_rate;

    reg  indicator;
    wire trig = ~trig_inv;

    // trigger edge-detect / debounce (fires one pulse on rising edge of trig)
    reg prev_state;
    reg debounced_trigger;
    always @(posedge clk) begin
        if (trig & (~prev_state))
            debounced_trigger <= 1'b1;
        else
            debounced_trigger <= 1'b0;
        prev_state <= trig;
    end

    // ---------- Message to transmit: "My name is Bharath \n" ----------
    parameter MSG_LEN = 20;   // 19 printable chars (incl. trailing space) + newline

    // index -> ASCII byte for each character of the message
    function [7:0] msg_char;
        input [4:0] idx;
        begin
            case (idx)
                5'd0 : msg_char = "M";
                5'd1 : msg_char = "y";
                5'd2 : msg_char = " ";
                5'd3 : msg_char = "n";
                5'd4 : msg_char = "a";
                5'd5 : msg_char = "m";
                5'd6 : msg_char = "e";
                5'd7 : msg_char = " ";
                5'd8 : msg_char = "i";
                5'd9 : msg_char = "s";
                5'd10: msg_char = " ";
                5'd11: msg_char = "B";
                5'd12: msg_char = "h";
                5'd13: msg_char = "a";
                5'd14: msg_char = "r";
                5'd15: msg_char = "a";
                5'd16: msg_char = "t";
                5'd17: msg_char = "h";
                5'd18: msg_char = " ";
                5'd19: msg_char = 8'h0A;             // '\n'  (line feed)
                default: msg_char = 8'h0A;
            endcase
        end
    endfunction

    reg [4:0] char_idx;         // which character of the message is being sent
    reg [7:0] tx_byte;          // the ASCII byte currently being shifted out

    always @(*) begin
        tx_byte = msg_char(char_idx);
    end

    // variable declarations
    reg [2:0]  state   = 0;
    reg [25:0] clk_ctr = 0;
    reg [2:0]  no_bits = 0;

    // State machine
    always @(posedge clk, negedge rst) begin
        if (rst == 0) begin
            state     <= idle;
            clk_ctr   <= 0;
            no_bits   <= 0;
            tx        <= 1'b1;
            indicator <= 0;
            char_idx  <= 5'd0;
        end
        else begin
        case (state)
        // IDLE STATE
        idle: begin
            indicator <= 1'b0;
            clk_ctr   <= 0;
            tx        <= 1'b1;
            if (debounced_trigger == 1'b1) begin
                state    <= start_bit;
                char_idx <= 5'd0;          // start a fresh message from the first char
            end
            else
                state <= idle;
        end
        // START BIT STATE
        start_bit: begin
            if (clk_ctr <= (clk_cycles-1)) begin
                tx      <= 1'b0;
                clk_ctr <= clk_ctr+1;
                state   <= start_bit;
            end
            else begin
                clk_ctr <= 0;
                state   <= data_bits;
            end
        end
        // DATA BITS STATE (send ASCII byte, LSB first)
        data_bits: begin
            tx <= tx_byte[no_bits];
            if (clk_ctr == clk_cycles-1) begin
                clk_ctr <= 0;
                if (no_bits < 7) begin
                    no_bits <= no_bits+1;
                    state   <= data_bits;
                end
                else begin
                    state   <= stop_bit;
                    no_bits <= 0;
                    clk_ctr <= 0;
                end
            end
            else begin
                clk_ctr <= clk_ctr+1;
                state   <= data_bits;
            end
        end
        // STOP BIT STATE
        stop_bit: begin
            if (clk_ctr < clk_cycles-1) begin
                clk_ctr <= clk_ctr+1;
                state   <= stop_bit;
                tx      <= 1'b1;
            end
            else begin
                clk_ctr <= 0;
                tx      <= 1'b1;
                if (char_idx < MSG_LEN-1) begin
                    char_idx <= char_idx + 1'b1;  // more characters to send -> next char
                    state    <= start_bit;
                end
                else begin
                    indicator <= 1'b1;            // whole message sent -> frame complete
                    state     <= cleanup;
                end
            end
        end
        // CLEANUP STATE
        cleanup: begin
            indicator <= 1'b0;
            state     <= idle;
            no_bits   <= 0;
            clk_ctr   <= 0;
            tx        <= 1'b1;
            char_idx  <= 5'd0;
        end
        default: state <= idle;
        endcase
        end
    end

endmodule