//======================================================================
//  UartQnA - interactive question / answer over the serial monitor
//
//  Asks three questions, reads a free-text answer for each, echoes each
//  answer back, then prints a summary.
//
//  ROBUST LINE ENDING: an answer is finished when EITHER
//     - you press Enter (CR or LF is received), OR
//     - typing pauses for ~IDLE_TICKS clocks.
//  This makes it work with the Arduino Serial Monitor no matter which
//  "line ending" option is selected (including "No Line Ending"), since
//  that monitor sends the whole line in one burst and then goes quiet.
//
//  Ports:
//    clk       - 27 MHz clock
//    rst       - active-LOW reset (button S1)
//    trig_inv  - button S2, active-LOW (optional start/restart)
//    rx        - UART receive  (Tang Nano 9K: pin 18)
//    tx        - UART transmit (Tang Nano 9K: pin 17)
//======================================================================
module UartQnA #(
    parameter CLKS_PER_BIT = 234,        // 27_000_000 / 115200
    parameter BUFSZ        = 96,         // total answer storage (bytes)
    parameter MAXANS       = 31,         // max chars per single answer
    parameter IDLE_TICKS   = 5000000     // ~185 ms pause = end of line
)(
    input  clk,
    input  rst,
    input  trig_inv,
    input  rx,
    output tx
);
    reg        tx_send;
    reg  [7:0] tx_data;
    wire       tx_busy;
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) TX (
        .clk(clk), .rst_n(rst), .send(tx_send), .data(tx_data),
        .tx(tx), .busy(tx_busy)
    );
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) RX (
        .clk(clk), .rst_n(rst), .rx(rx),
        .data(rx_data), .valid(rx_valid)
    );

    // button S2 rising-edge detector
    wire trig = ~trig_inv;
    reg  prev_trig, btn_pulse;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin prev_trig <= 1'b0; btn_pulse <= 1'b0; end
        else begin btn_pulse <= trig & ~prev_trig; prev_trig <= trig; end
    end

    // fixed text (CR=\015 LF=\012)
    localparam [30*8-1:0] M0 = "\015\012-- Answer the questions --\015\012";
    localparam [21*8-1:0] M1 = "\015\012What is your name? ";
    localparam [29*8-1:0] M2 = "\015\012What is your college name? ";
    localparam [21*8-1:0] M3 = "\015\012Where do you live? ";
    localparam [35*8-1:0] M4 = "\015\012\015\012----- Summary -----\015\012Name    : ";
    localparam [12*8-1:0] M5 = "\015\012College : ";
    localparam [12*8-1:0] M6 = "\015\012City    : ";
    localparam [44*8-1:0] M7 = "\015\012\015\012Thank you! Press a key to start again.\015\012";

    reg [359:0] cur_msg;
    reg [6:0]   cur_len;
    reg [2:0]   msg_id;
    always @(*) begin
        case (msg_id)
            3'd0:    begin cur_msg = M0; cur_len = 7'd30; end
            3'd1:    begin cur_msg = M1; cur_len = 7'd21; end
            3'd2:    begin cur_msg = M2; cur_len = 7'd29; end
            3'd3:    begin cur_msg = M3; cur_len = 7'd21; end
            3'd4:    begin cur_msg = M4; cur_len = 7'd35; end
            3'd5:    begin cur_msg = M5; cur_len = 7'd12; end
            3'd6:    begin cur_msg = M6; cur_len = 7'd12; end
            default: begin cur_msg = M7; cur_len = 7'd44; end
        endcase
    end

    // answer storage
    reg [7:0]  mem [0:BUFSZ-1];
    reg [6:0]  ans_start [0:2];
    reg [6:0]  ans_len   [0:2];
    reg [6:0]  write_ptr;
    reg [5:0]  curlen;
    reg [24:0] idle_cnt;

    // current byte to send (fixed text or a stored answer)
    reg        src;                    // 0 = fixed text, 1 = stored answer
    reg  [1:0] sel;
    reg  [6:0] ptr;
    wire [7:0] rom_char  = cur_msg[8*(cur_len-1-ptr) +: 8];
    wire [6:0] mem_addr  = ans_start[sel] + ptr;
    wire [7:0] mem_char  = mem[mem_addr];
    wire [7:0] send_char = src ? mem_char    : rom_char;
    wire [6:0] send_len  = src ? ans_len[sel] : cur_len;

    localparam ST_WAIT_START = 4'd0,
               ST_INTRO      = 4'd1,
               ST_Q          = 4'd2,
               ST_READINIT   = 4'd3,
               ST_READ       = 4'd4,
               ST_LINEDONE   = 4'd5,   // echo the answer just typed
               ST_AFTER      = 4'd6,   // next question or summary
               ST_SUM_LABEL  = 4'd7,
               ST_SUM_VALUE  = 4'd8,
               ST_SUM_NEXT   = 4'd9,
               ST_CLOSE      = 4'd10,
               ST_SEND       = 4'd11,
               ST_SEND_ACK   = 4'd12,
               ST_SEND_WAIT  = 4'd13;

    reg [3:0] state, ret_state;
    reg [1:0] q_num, sum_i;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state     <= ST_WAIT_START;
            ret_state <= ST_INTRO;
            msg_id    <= 3'd0;
            ptr       <= 7'd0;
            q_num     <= 2'd0;
            sum_i     <= 2'd0;
            src       <= 1'b0;
            sel       <= 2'd0;
            write_ptr <= 7'd0;
            curlen    <= 6'd0;
            idle_cnt  <= 25'd0;
            tx_send   <= 1'b0;
            tx_data   <= 8'd0;
        end else begin
            tx_send <= 1'b0;
            case (state)

            ST_WAIT_START: begin
                if (btn_pulse || rx_valid) begin
                    q_num     <= 2'd0;
                    write_ptr <= 7'd0;
                    state     <= ST_INTRO;
                end
            end

            ST_INTRO: begin
                msg_id <= 3'd0; src <= 1'b0; ptr <= 7'd0;
                ret_state <= ST_Q; state <= ST_SEND;
            end

            ST_Q: begin
                case (q_num)
                    2'd0:    msg_id <= 3'd1;
                    2'd1:    msg_id <= 3'd2;
                    default: msg_id <= 3'd3;
                endcase
                src <= 1'b0; ptr <= 7'd0;
                ret_state <= ST_READINIT; state <= ST_SEND;
            end

            ST_READINIT: begin
                ans_start[q_num] <= write_ptr;
                curlen   <= 6'd0;
                idle_cnt <= 25'd0;
                state    <= ST_READ;
            end

            // end the line on Enter (CR/LF) OR a pause in typing
            ST_READ: begin
                if (rx_valid) begin
                    idle_cnt <= 25'd0;
                    if (rx_data == 8'h0D || rx_data == 8'h0A) begin
                        ans_len[q_num] <= curlen;
                        state <= ST_LINEDONE;
                    end
                    else if (rx_data >= 8'h20 && rx_data <= 8'h7E
                             && curlen < MAXANS && write_ptr < BUFSZ-1) begin
                        mem[write_ptr] <= rx_data;
                        write_ptr <= write_ptr + 1'b1;
                        curlen    <= curlen + 1'b1;
                    end
                end
                else if (curlen != 6'd0 && idle_cnt >= IDLE_TICKS-1) begin
                    ans_len[q_num] <= curlen;    // typing paused -> line done
                    state <= ST_LINEDONE;
                end
                else if (curlen != 6'd0) begin
                    idle_cnt <= idle_cnt + 1'b1;
                end
            end

            // echo the answer that was just typed
            ST_LINEDONE: begin
                src <= 1'b1; sel <= q_num; ptr <= 7'd0;
                ret_state <= ST_AFTER; state <= ST_SEND;
            end

            ST_AFTER: begin
                if (q_num == 2'd2) begin sum_i <= 2'd0; state <= ST_SUM_LABEL; end
                else begin q_num <= q_num + 1'b1; state <= ST_Q; end
            end

            ST_SUM_LABEL: begin
                case (sum_i)
                    2'd0:    msg_id <= 3'd4;
                    2'd1:    msg_id <= 3'd5;
                    default: msg_id <= 3'd6;
                endcase
                src <= 1'b0; ptr <= 7'd0;
                ret_state <= ST_SUM_VALUE; state <= ST_SEND;
            end
            ST_SUM_VALUE: begin
                src <= 1'b1; sel <= sum_i; ptr <= 7'd0;
                ret_state <= ST_SUM_NEXT; state <= ST_SEND;
            end
            ST_SUM_NEXT: begin
                if (sum_i == 2'd2) state <= ST_CLOSE;
                else begin sum_i <= sum_i + 1'b1; state <= ST_SUM_LABEL; end
            end

            ST_CLOSE: begin
                msg_id <= 3'd7; src <= 1'b0; ptr <= 7'd0;
                ret_state <= ST_WAIT_START; state <= ST_SEND;
            end

            // shared string sender
            ST_SEND: begin
                if (send_len == 0) state <= ret_state;
                else begin tx_data <= send_char; tx_send <= 1'b1; state <= ST_SEND_ACK; end
            end
            ST_SEND_ACK: begin
                if (tx_busy) state <= ST_SEND_WAIT;
            end
            ST_SEND_WAIT: begin
                if (!tx_busy) begin
                    if (ptr == send_len-1) state <= ret_state;
                    else begin ptr <= ptr + 1'b1; state <= ST_SEND; end
                end
            end

            default: state <= ST_WAIT_START;
            endcase
        end
    end

endmodule


//======================================================================
//  UART transmitter (8N1, LSB first)
//======================================================================
module uart_tx #(parameter CLKS_PER_BIT = 234)(
    input clk, input rst_n, input send, input [7:0] data,
    output reg tx, output reg busy
);
    localparam S_IDLE=2'd0, S_START=2'd1, S_DATA=2'd2, S_STOP=2'd3;
    reg [1:0] state; reg [15:0] cnt; reg [2:0] bit_idx; reg [7:0] shreg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin state<=S_IDLE; tx<=1'b1; busy<=1'b0; cnt<=0; bit_idx<=0; shreg<=0;
        end else begin
            case (state)
            S_IDLE: begin tx<=1'b1; busy<=1'b0; cnt<=0; bit_idx<=0;
                if (send) begin shreg<=data; busy<=1'b1; state<=S_START; end end
            S_START: begin tx<=1'b0; busy<=1'b1;
                if (cnt==CLKS_PER_BIT-1) begin cnt<=0; state<=S_DATA; end else cnt<=cnt+1'b1; end
            S_DATA: begin tx<=shreg[bit_idx];
                if (cnt==CLKS_PER_BIT-1) begin cnt<=0;
                    if (bit_idx==3'd7) begin bit_idx<=0; state<=S_STOP; end else bit_idx<=bit_idx+1'b1;
                end else cnt<=cnt+1'b1; end
            S_STOP: begin tx<=1'b1;
                if (cnt==CLKS_PER_BIT-1) begin cnt<=0; busy<=1'b0; state<=S_IDLE; end else cnt<=cnt+1'b1; end
            endcase
        end
    end
endmodule


//======================================================================
//  UART receiver (8N1, LSB first).  Starts only on a HIGH->LOW edge,
//  so a floating / stuck-low line will NOT flood it with 0x00 bytes.
//======================================================================
module uart_rx #(parameter CLKS_PER_BIT = 234)(
    input clk, input rst_n, input rx,
    output reg [7:0] data, output reg valid
);
    localparam S_IDLE=2'd0, S_START=2'd1, S_DATA=2'd2, S_STOP=2'd3;
    reg [1:0] state; reg [15:0] cnt; reg [2:0] bit_idx; reg [7:0] shreg;
    reg rx_d1, rx_d2, rx_d3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=S_IDLE; cnt<=0; bit_idx<=0; valid<=1'b0; data<=0; shreg<=0;
            rx_d1<=1'b1; rx_d2<=1'b1; rx_d3<=1'b1;
        end else begin
            rx_d1<=rx; rx_d2<=rx_d1; rx_d3<=rx_d2;
            valid<=1'b0;
            case (state)
            S_IDLE: begin cnt<=0; bit_idx<=0;
                if (rx_d3==1'b1 && rx_d2==1'b0) state<=S_START; end
            S_START: begin
                if (cnt==(CLKS_PER_BIT-1)/2) begin
                    if (rx_d2==1'b0) begin cnt<=0; state<=S_DATA; end else state<=S_IDLE;
                end else cnt<=cnt+1'b1; end
            S_DATA: begin
                if (cnt==CLKS_PER_BIT-1) begin cnt<=0; shreg[bit_idx]<=rx_d2;
                    if (bit_idx==3'd7) begin bit_idx<=0; state<=S_STOP; end else bit_idx<=bit_idx+1'b1;
                end else cnt<=cnt+1'b1; end
            S_STOP: begin
                if (cnt==CLKS_PER_BIT-1) begin cnt<=0; data<=shreg; valid<=1'b1; state<=S_IDLE;
                end else cnt<=cnt+1'b1; end
            endcase
        end
    end
endmodule