//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.10 
//Created Time: 2023-04-11 23:58:29
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}] -add
create_generated_clock -name clk_108 -source [get_ports {clk}] -master_clock clk -divide_by 1 -multiply_by 4 -add [get_nets {clk_108_w}]
create_generated_clock -name clk_3 -source [get_nets {clk_108_w}] -master_clock clk_108 -divide_by 30 -multiply_by 1 -add [get_nets {clk_3_w}]
//create_generated_clock -name clk_21 -source [get_nets {clk_108_w}] -master_clock clk_108 -divide_by 5 -multiply_by 1 -add [get_nets {clk_21_w}]

create_generated_clock -name clk_126 -source [get_ports {clk}] -master_clock clk -divide_by 3 -multiply_by 14 -add [get_nets {clk_126_w}]
create_generated_clock -name clk_25 -source [get_nets {clk_126_w}] -master_clock clk_126 -divide_by 5 -multiply_by 1 -add [get_nets {clk_25_w}]
//create_generated_clock -name clk_audio -source [get_nets {clk_25_w}] -master_clock clk_25 -divide_by 525 -multiply_by 1 -add [get_nets {clk_audio_w}]
create_generated_clock -name clk_audio -source [get_nets {clk_25_w}] -master_clock clk_25 -divide_by 571 -multiply_by 1 -add [get_nets {clk_audio_w}]

//set_clock_groups -asynchronous -group [get_clocks {clk_21}] -group [get_clocks {clk_25}]
set_clock_groups -asynchronous -group [get_clocks {clk_25}] -group [get_clocks {clk_audio}]