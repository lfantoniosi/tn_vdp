//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.11 Education
//Created Time: 2023-06-21 01:16:09
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}] -add
create_clock -name clk_50 -period 20 -waveform {0 10} [get_ports {clk_50}] -add
create_clock -name clk_125 -period 8 -waveform {0 4} [get_ports {clk_125}]
//create_clock -name clk_63 -period 15.873 -waveform {0 7.936} [get_ports {clk_63}]

create_generated_clock -name clk_135 -source [get_ports {clk}] -master_clock clk -divide_by 1 -multiply_by 5 -add [get_nets {clk_135}]
//create_generated_clock -name clk_135p -source [get_ports {clk}] -master_clock clk -divide_by 1 -multiply_by 5 -duty_cycle 50 -phase 180 -add [get_nets {clk_135p}]
//create_generated_clock -name clk_sdram -source [get_nets {clk_135}] -master_clock clk_135 -divide_by 2 -multiply_by 1 -add [get_nets {clk_sdram}]
//create_generated_clock -name clk_sdramp -source [get_nets {clk_135p}] -master_clock clk_135p -divide_by 2 -multiply_by 1 -add [get_nets {clk_sdramp}]

//create_generated_clock -name clk_315 -source [get_ports {clk_63}] -master_clock clk_63 -divide_by 1 -multiply_by 5 -add [get_nets {clk_315}]
//create_generated_clock -name clk_315p -source [get_ports {clk_63}] -master_clock clk_63 -divide_by 1 -multiply_by 5 -duty_cycle 50 -phase 180 -add [get_nets {clk_315p}]
//create_generated_clock -name clk_sdram -source [get_nets {clk_315}] -master_clock clk_315 -divide_by 4 -multiply_by 1 -add [get_nets {clk_sdram}]
//create_generated_clock -name clk_sdramp -source [get_nets {clk_315p}] -master_clock clk_315p -divide_by 4 -multiply_by 1 -add [get_nets {clk_sdramp}]

create_generated_clock -name clk_audio -source [get_ports {clk}] -master_clock clk -divide_by 612 -multiply_by 1 -add [get_nets {clk_audio}]

create_generated_clock -name clk_sdramp -source [get_ports {clk}] -master_clock clk -divide_by 1 -multiply_by 3 -duty_cycle 50 -phase 180 -add [get_nets {clk_sdramp}]
create_generated_clock -name clk_sdram -source [get_ports {clk}] -master_clock clk -divide_by 1 -multiply_by 3 -add [get_nets {clk_sdram}]

create_generated_clock -name clk_cpu -source [get_ports {clk_50}] -master_clock clk_50 -divide_by 14 -multiply_by 1 -add [get_nets {clk_cpu}]
create_generated_clock -name clk_grom -source [get_ports {clk_50}] -master_clock clk_50 -divide_by 112 -multiply_by 1 -add [get_nets {clk_grom}]

create_generated_clock -name clk_SCK -source [get_ports {clk_125}] -master_clock clk_125 -divide_by 138 -multiply_by 1 -add [get_nets {clk_SCK}]
