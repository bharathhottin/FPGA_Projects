module gw_gao(
    \state[2] ,
    \state[1] ,
    \state[0] ,
    \num[7] ,
    \num[6] ,
    \num[5] ,
    \num[4] ,
    \num[3] ,
    \num[2] ,
    \num[1] ,
    \num[0] ,
    \no_bits[2] ,
    \no_bits[1] ,
    \no_bits[0] ,
    tx,
    debounced_trigger,
    indicator,
    clk,
    tms_pad_i,
    tck_pad_i,
    tdi_pad_i,
    tdo_pad_o
);

input \state[2] ;
input \state[1] ;
input \state[0] ;
input \num[7] ;
input \num[6] ;
input \num[5] ;
input \num[4] ;
input \num[3] ;
input \num[2] ;
input \num[1] ;
input \num[0] ;
input \no_bits[2] ;
input \no_bits[1] ;
input \no_bits[0] ;
input tx;
input debounced_trigger;
input indicator;
input clk;
input tms_pad_i;
input tck_pad_i;
input tdi_pad_i;
output tdo_pad_o;

wire \state[2] ;
wire \state[1] ;
wire \state[0] ;
wire \num[7] ;
wire \num[6] ;
wire \num[5] ;
wire \num[4] ;
wire \num[3] ;
wire \num[2] ;
wire \num[1] ;
wire \num[0] ;
wire \no_bits[2] ;
wire \no_bits[1] ;
wire \no_bits[0] ;
wire tx;
wire debounced_trigger;
wire indicator;
wire clk;
wire tms_pad_i;
wire tck_pad_i;
wire tdi_pad_i;
wire tdo_pad_o;
wire tms_i_c;
wire tck_i_c;
wire tdi_i_c;
wire tdo_o_c;
wire [9:0] control0;
wire gao_jtag_tck;
wire gao_jtag_reset;
wire run_test_idle_er1;
wire run_test_idle_er2;
wire shift_dr_capture_dr;
wire update_dr;
wire pause_dr;
wire enable_er1;
wire enable_er2;
wire gao_jtag_tdi;
wire tdo_er1;

IBUF tms_ibuf (
    .I(tms_pad_i),
    .O(tms_i_c)
);

IBUF tck_ibuf (
    .I(tck_pad_i),
    .O(tck_i_c)
);

IBUF tdi_ibuf (
    .I(tdi_pad_i),
    .O(tdi_i_c)
);

OBUF tdo_obuf (
    .I(tdo_o_c),
    .O(tdo_pad_o)
);

GW_JTAG  u_gw_jtag(
    .tms_pad_i(tms_i_c),
    .tck_pad_i(tck_i_c),
    .tdi_pad_i(tdi_i_c),
    .tdo_pad_o(tdo_o_c),
    .tck_o(gao_jtag_tck),
    .test_logic_reset_o(gao_jtag_reset),
    .run_test_idle_er1_o(run_test_idle_er1),
    .run_test_idle_er2_o(run_test_idle_er2),
    .shift_dr_capture_dr_o(shift_dr_capture_dr),
    .update_dr_o(update_dr),
    .pause_dr_o(pause_dr),
    .enable_er1_o(enable_er1),
    .enable_er2_o(enable_er2),
    .tdi_o(gao_jtag_tdi),
    .tdo_er1_i(tdo_er1),
    .tdo_er2_i(1'b0)
);

gw_con_top  u_icon_top(
    .tck_i(gao_jtag_tck),
    .tdi_i(gao_jtag_tdi),
    .tdo_o(tdo_er1),
    .rst_i(gao_jtag_reset),
    .control0(control0[9:0]),
    .enable_i(enable_er1),
    .shift_dr_capture_dr_i(shift_dr_capture_dr),
    .update_dr_i(update_dr)
);

ao_top_0  u_la0_top(
    .control(control0[9:0]),
    .trig0_i(debounced_trigger),
    .data_i({\state[2] ,\state[1] ,\state[0] ,\num[7] ,\num[6] ,\num[5] ,\num[4] ,\num[3] ,\num[2] ,\num[1] ,\num[0] ,\no_bits[2] ,\no_bits[1] ,\no_bits[0] ,tx,debounced_trigger,indicator}),
    .clk_i(clk)
);

endmodule
