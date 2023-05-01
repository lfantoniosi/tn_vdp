//--
//-- F18A
//--   A pin-compatible enhanced replacement for the TMS9918A VDP family.
//--   https://dnotq.io
//--

//-- Released under the 3-Clause BSD License:
//--
//-- Copyright 2011-2018 Matthew Hagerty (matthew <at> dnotq <dot> io)
//--
//-- Redistribution and use in source and binary forms, with or without
//-- modification, are permitted provided that the following conditions are met:
//--
//-- 1. Redistributions of source code must retain the above copyright notice,
//-- this list of conditions and the following disclaimer.
//--
//-- 2. Redistributions in binary form must reproduce the above copyright
//-- notice, this list of conditions and the following disclaimer in the
//-- documentation and/or other materials provided with the distribution.
//--
//-- 3. Neither the name of the copyright holder nor the names of its
//-- contributors may be used to endorse or promote products derived from this
//-- software without specific prior written permission.
//--
//-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//-- POSSIBILITY OF SUCH DAMAGE.

//-- Version history.  See README.md for details.
//--
//--   V1.9 Dec 31, 2018

//-- Top module to set up the F18A top for use as in a Tang Nano 9K dev board

module top(
    // fpga signals
    input   clk,
    input   rst_n,
    
    // TMS9118A signals
    input   reset_n,
    input   mode,
    input   csw_n,
    input   csr_n,
    output  int_n,
    output   gromclk,
    output   cpuclk,
    inout   [0:7] cd,

    // user inputs
    input   maxspr_n,       // usr1
    input   scnlin_n,       // usr2
    input   gromclk_n,      // usr3
    input   cpuclk_n,       // usr4

    // flash spi ports
    output  spi_cs,
    output  spi_mosi,
    input   spi_miso,
    output  spi_clk,

    // VGA ports
    output  hsync,
    output  vsync,
    output  [3:0] red,
    output  [3:0] grn,
    output  [3:0] blu,

    // hdmi ports
    output  tmds_clk_p,
    output  tmds_clk_n,
    output  [2:0] tmds_d_p,
    output  [2:0] tmds_d_n
);

// clocks
wire clk_w;
wire clk_100_w;
wire clk_100_lock_w;
wire clk_25_w;
wire clk_125_w;
wire clk_125_lock_w;
wire hdmi_rst_n_w;
wire clk_50_w;

// hdmi
wire rgb_vs_w;
wire rgb_hs_w;
wire rgb_de_w;
wire [7:0] rgb_r_w;
wire [7:0] rgb_g_w;
wire [7:0] rgb_b_w;


    BUFG clk_bufg_inst(
    .O(clk_w),
    .I(clk)
    );

    CLK_100 clk_100_inst(
        .clkout(clk_100_w), 
        .lock(clk_100_lock_w),
        .reset(~rst_n), 
        .clkin(clk_w) 
    );

    CLKDIV clk_50_inst (
        .CLKOUT(clk_50_w), 
        .HCLKIN(clk_100_w), 
        .RESETN(clk_100_lock_w),
        .CALIB(1'b1)
    );
    defparam clk_50_inst.DIV_MODE = "2";
    defparam clk_50_inst.GSREN = "false"; 

    CLKDIV clk_25_inst (
        .CLKOUT(clk_25_w),
        .HCLKIN(clk_100_w), 
        .RESETN(clk_100_lock_w),
        .CALIB(1'b1)
    );
    defparam clk_25_inst.DIV_MODE = "4";
    defparam clk_25_inst.GSREN = "false"; 

    CLK_125 clk_125_inst(
        .clkout(clk_125_w), //output clkout
        .lock(clk_125_lock_w), //output lock
        .reset(~clk_100_lock_w), //input reset
        .clkin(clk_25_w) //input clkin
    );

assign hdmi_rst_n_w = rst_n & clk_125_lock_w & reset_n;

	DVI_TX dvi_tx_inst(
		.I_rst_n(hdmi_rst_n_w), //input I_rst_n
		.I_serial_clk(clk_125_w), //input I_serial_clk
		.I_rgb_clk(clk_25_w), //input I_rgb_clk
		.I_rgb_vs(rgb_vs_w), //input I_rgb_vs
		.I_rgb_hs(rgb_hs_w), //input I_rgb_hs
		.I_rgb_de(rgb_de_w), //input I_rgb_de
		.I_rgb_r(rgb_r_w), //input [7:0] I_rgb_r
		.I_rgb_g(rgb_g_w), //input [7:0] I_rgb_g
		.I_rgb_b(rgb_b_w), //input [7:0] I_rgb_b
		.O_tmds_clk_p(tmds_clk_p), //output O_tmds_clk_p
		.O_tmds_clk_n(tmds_clk_n), //output O_tmds_clk_n
		.O_tmds_data_p(tmds_d_p), //output [2:0] O_tmds_data_p
		.O_tmds_data_n(tmds_d_n) //output [2:0] O_tmds_data_n
	);

wire blank_w;
wire  hs_w;
wire  vs_w;
wire [3:0] r_w;
wire [3:0] g_w;
wire [3:0] b_w;

assign rgb_r_w = {r_w, 4'b0};
assign rgb_g_w = {g_w, 4'b0};
assign rgb_b_w = {b_w, 4'b0};
assign rgb_hs_w = hs_w;
assign rgb_vs_w = vs_w;
assign rgb_de_w = ~blank_w; 

assign red = r_w;
assign grn = g_w;
assign blu = b_w;

assign hsync = hs_w;
assign vsync = vs_w;

f18a_top f18a_top_inst(
    .clk_100m0_s(clk_50_w),
    .clk_25m0_s(clk_25_w),
    .reset_n_net(hdmi_rst_n_w),
    .mode_net(mode),
    .csw_n_net(csw_n),
    .csr_n_net(csr_n),
    .int_n_net(int_n),
    .clk_grom_net(gromclk),
    .clk_cpu_net(cpuclk),
    .cd_net(cd),
    .hsync_net(hs_w),
    .vsync_net(vs_w),
    .red_net(r_w),
    .grn_net(g_w),
    .blu_net(b_w),
    .blank_net(blank_w),
    .usr1_net(maxspr_n),
    .usr2_net(scnlin_n),
    .usr3_net(gromclk_n),
    .usr4_net(cpuclk_n),
    .spi_cs_net(spi_cs),
    .spi_mosi_net(spi_mosi),
    .spi_miso_net(spi_miso),
    .spi_clk_net(spi_clk)
    );


endmodule
