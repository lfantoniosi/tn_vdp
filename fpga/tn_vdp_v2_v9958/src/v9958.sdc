//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.9 Beta-1
//Created Time: 2023-06-03 16:45:37
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}] -add
create_generated_clock -name clk_audio -source [get_ports {clk}] -master_clock clk -divide_by 61 -multiply_by 1 -add [get_nets {clk_audio_w}]
create_generated_clock -name clk_135 -source [get_ports {clk}] -master_clock clk -divide_by 1 -multiply_by 5 -add [get_nets {clk_135_w}]
create_generated_clock -name clk_67 -source [get_nets {clk_135_w}] -master_clock clk_135 -divide_by 2 -multiply_by 1 -add [get_nets {clk_67_w}]
create_generated_clock -name clk_3 -source [get_nets {clk_135_w}] -master_clock clk_135 -divide_by 38 -multiply_by 1 -add [get_nets {clk_3_w}]

