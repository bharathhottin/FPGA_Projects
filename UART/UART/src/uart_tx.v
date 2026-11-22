module UartTransmitter( input clk, rst, input trig_inv, output reg tx
    );
    parameter idle = 3'b000;
    parameter start_bit = 3'b001;
    parameter data_bits = 3'b010;
    parameter stop_bit = 3'b011;
    parameter cleanup = 3'b100;
    // Setting baud rates and counters
    parameter clk_speed = 27000000, baud_rate = 115200; //Fpga clk speed and uart parameter
    parameter clk_cycles = clk_speed/baud_rate;
    reg indicator;
// prbs num generator
reg [7:0]num;
reg [7:0]lfsr;
wire trig = ~trig_inv;

    //trigger debounce
    reg prev_state;
    reg debounced_trigger;
    always@(posedge clk) begin
    if(trig&(~prev_state))
    debounced_trigger <= 1'b1;
    else
    debounced_trigger <= 1'b0;
    prev_state <= trig;
    end

    // nibble -> ASCII hex character ('0'-'9','A'-'F')
    function [7:0] hex_char;
        input [3:0] nib;
        begin
            if (nib < 4'd10)
                hex_char = 8'h30 + {4'b0000, nib};        // '0'..'9'
            else
                hex_char = 8'h41 + {4'b0000, (nib - 4'd10)}; // 'A'..'F'
        end
    endfunction

    // which of the 3 ASCII bytes we are sending: 0=high nibble, 1=low nibble, 2=newline
    reg [1:0] char_idx;
    reg [7:0] tx_byte;          // the ASCII byte currently being shifted out

    // pick the ASCII byte for the current char_idx
    always @(*) begin
        case (char_idx)
            2'd0:    tx_byte = hex_char(num[7:4]);   // high nibble as hex
            2'd1:    tx_byte = hex_char(num[3:0]);   // low nibble as hex
            default: tx_byte = 8'h0A;                // '\n'
        endcase
    end

    //variable declerations
    reg [2:0]state = 0;
    reg [25:0]clk_ctr = 0;
    reg [2:0]no_bits = 0;
    //State machine
    always@(posedge clk, negedge rst) begin
    if(rst==0) begin
        state <= idle;
        clk_ctr <= 0;
        no_bits <= 0;
        tx <= 1'b1;
        indicator <= 0;
        num<=0;
        lfsr <= 8'b10111000;
        char_idx <= 2'd0;
    end
    else begin
    case(state)
    // IDLE STATE
    idle: begin
        indicator <= 1'b0;
        clk_ctr <= 0;
        tx <= 1'b1;
        if(debounced_trigger==1'b1) begin
            state<=start_bit;
            num <= lfsr;
            lfsr <= {lfsr[0]^lfsr[1],lfsr[7:1]};
            char_idx <= 2'd0;          // start a fresh "HH\n" sequence
        end
        else
        state <= idle;
        end
    //START BIT STATE
    start_bit: begin
        if(clk_ctr <= (clk_cycles-1)) begin
        tx<=1'b0;
        clk_ctr<=clk_ctr+1;
        state<=start_bit;
        end
        else begin
        clk_ctr <= 0;
        state <= data_bits;
        end
        end
        //DATA BITS STATE  (send ASCII byte, LSB first)
        data_bits: begin
        tx<=tx_byte[no_bits];
        if(clk_ctr == clk_cycles-1) begin

        clk_ctr <= 0;
        if(no_bits<7) begin
        no_bits<=no_bits+1;
        state <= data_bits;
        end
        else begin
        state <= stop_bit;
        no_bits<=0;
        clk_ctr<=0;
        end
        end
        else begin
        clk_ctr <= clk_ctr+1;
        state <= data_bits;
        end
        end
        //STOP BIT STATE
        stop_bit: begin
        if(clk_ctr < clk_cycles-1) begin
        clk_ctr<=clk_ctr+1;
        state<=stop_bit;
        tx <= 1'b1;
        end
        else begin
        clk_ctr<=0;
        tx<=1'b1;
        if(char_idx < 2'd2) begin
            char_idx <= char_idx + 1'b1;  // more ASCII bytes to send -> next char
            state <= start_bit;
        end
        else begin
            indicator <= 1'b1;            // newline sent -> frame complete
            state <= cleanup;
        end
        end
        end
        //CLEANUP STATE
        cleanup: begin
        indicator <= 1'b0;
        state <= idle;
        no_bits <= 0;
        clk_ctr <= 0;
        tx <= 1'b1;
        char_idx <= 2'd0;
        end
        default: state <= idle;
        endcase
        end
        end


endmodule
