//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.10 
//Created Time: 2023-04-15 12:31:55
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}] -add

create_generated_clock -name clk_100 -source [get_ports {clk}] -master_clock clk -divide_by 7 -multiply_by 26 -add [get_nets {clk_100_w}]
create_generated_clock -name clk_50 -source [get_nets {clk_100_w}] -master_clock clk_100 -divide_by 2 -multiply_by 1 -add [get_nets {clk_50_w}]
create_generated_clock -name clk_25 -source [get_nets {clk_100_w}] -master_clock clk_100 -divide_by 4 -multiply_by 1 -add [get_nets {clk_25_w}]
create_generated_clock -name clk_125 -source [get_nets {clk_25_w}] -master_clock clk_25 -divide_by 1 -multiply_by 5 -add [get_nets {clk_125_w}]
