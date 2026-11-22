// Timing constraint for Sipeed Tang Nano 9K: 27 MHz onboard clock
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
