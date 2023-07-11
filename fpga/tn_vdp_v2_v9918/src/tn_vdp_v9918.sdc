//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.10 
//Created Time: 2023-04-15 12:31:55
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}] -add

create_generated_clock -name clk_50 -source [get_ports {clk}] -master_clock clk -divide_by 7 -multiply_by 13 -add [get_nets {clk_50}]
create_generated_clock -name clk_25 -source [get_nets {clk_50}] -master_clock clk_50 -divide_by 2 -multiply_by 1 -add [get_nets {clk_25}]
create_generated_clock -name clk_125 -source [get_nets {clk_25}] -master_clock clk_25 -divide_by 1 -multiply_by 5 -add [get_nets {clk_125}]

create_generated_clock -name clk_audio -source [get_nets {clk_25}] -master_clock clk_25 -divide_by 568 -multiply_by 1 -add [get_nets {clk_audio}]

//set_clock_groups -asynchronous -group [get_clocks {clk_50}] -group [get_clocks {clk_25}]
//set_clock_groups -asynchronous -group [get_clocks {clk_25}] -group [get_clocks {clk_audio}]

create_generated_clock -name clk_cpu -source [get_nets {clk_50}] -master_clock clk_50 -divide_by 14 -multiply_by 1 -add [get_nets {clk_cpu}]
create_generated_clock -name clk_grom -source [get_nets {clk_50}] -master_clock clk_50 -divide_by 112 -multiply_by 1 -add [get_nets {clk_grom}]
