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
`define GW_IDE

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
    output  flash_clk,
    output  flash_cs,
    output  flash_mosi,
    input   flash_miso,

    output  adc_clk,
    output  adc_cs,
    output  adc_mosi,
    input   adc_miso,

    output  [5:0]   led,

    // hdmi ports
    output  tmds_clk_p,
    output  tmds_clk_n,
    output  [2:0] tmds_d_p,
    output  [2:0] tmds_d_n
);

wire hdmi_rst_n_w;

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

    CLK_50_25 clk_50_25 (
        .clkout(clk_50), //output clkout
        .lock(clk_50_lock_w), //output lock
        .clkoutd(clk_25), //output clkoutd
        .reset(~rst_n), //input reset
        .clkin(clk) //input clkin
    );

    CLK_125 clk_125_inst(
        .clkout(clk_125), //output clkout
        .lock(clk_125_lock_w), //output lock
        .reset(~clk_50_lock_w), //input reset
        .clkin(clk_25) //input clkin
    );

    BUFG clk_50_bufg_inst(
    .O(clk_50_w),
    .I(clk_50)
    );

    BUFG clk_25_bufg_inst(
    .O(clk_25_w),
    .I(clk_25)
    );

    BUFG clk_125_bufg_inst(
    .O(clk_125_w),
    .I(clk_125)
    );

wire rst_n_w;
assign rst_n_w = rst_n & clk_50_lock_w & clk_125_lock_w;

assign reset_n_w = rst_n_w & reset_n;

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

wire [0:7] cd_out_s;

wire [9:0] vdp_cx;
wire [9:0] vdp_cy;


   f18a_core f18a_core_inst (
      .clk_100m0_i(clk_50_w),
      .clk_25m0_i(clk_25_w),
      .reset_n_i(reset_n_w),
      .mode_i(mode),
      .csw_n_i(csw_n),
      .csr_n_i(csr_n),
      .int_n_o(int_n),
      .cd_i(cd),
      .cd_o(cd_out_s),
      .red_o(r_w),
      .grn_o(g_w),
      .blu_o(b_w),
      .sprite_max_i(maxspr_n),
      .scanlines_i(~scnlin_n),
      .spi_clk_o(flash_clk),
      .spi_cs_o(flash_cs),
      .spi_mosi_o(flash_mosi),
      .spi_miso_i(flash_miso),
      .cx(vdp_cx),
      .cy(vdp_cy)
   );

   assign cd = csr_n ? 8'bzzzzzzzz : cd_out_s;


///////////

    localparam CPUCLK_SRCFRQ = 50.0;
    localparam CPUCLK_FRQ = 315.0/88.0;
    localparam CPUCLK_DELAY = CPUCLK_SRCFRQ / CPUCLK_FRQ / 2;
    logic [$clog2(CPUCLK_DELAY)-1:0] cpuclk_divider;
    logic clk_cpu;

    always_ff@(posedge clk_50_w) 
    begin
        if (cpuclk_divider != CPUCLK_DELAY - 1) 
            cpuclk_divider++;
        else begin 
            clk_cpu <= ~clk_cpu; 
            cpuclk_divider <= 0; 
        end
    end
    BUFG clk_cpuclk_bufg_inst(
    .O(cpuclk_w),
    .I(clk_cpu)
    );


    localparam GROMCLK_SRCFRQ = 50.0;
    localparam GROMCLK_FRQ = 315.0/88.0 / 8.0;
    localparam GROMCLK_DELAY = GROMCLK_SRCFRQ / GROMCLK_FRQ / 2;
    logic [$clog2(GROMCLK_DELAY)-1:0] gromclk_divider;
    logic clk_grom;

    always_ff@(posedge clk_50_w) 
    begin
        if (gromclk_divider != GROMCLK_DELAY - 1) 
            gromclk_divider++;
        else begin 
            clk_grom <= ~clk_grom;
            gromclk_divider <= 0; 
        end
    end
    BUFG clk_gromclk_bufg_inst(
    .O(gromclk_w),
    .I(clk_grom)
    );

    assign gromclk = (gromclk_n ? cpuclk_w: gromclk_w); 
    assign cpuclk = (cpuclk_n ? 1'bz : cpuclk_w);
//////////


    localparam CLKFRQ = 25071;
    localparam AUDIO_RATE=44100;
    localparam AUDIO_BIT_WIDTH = 16;
    localparam AUDIO_CLK_DELAY = CLKFRQ * 1000 / AUDIO_RATE / 2;
    logic [$clog2(AUDIO_CLK_DELAY)-1:0] audio_divider;
    logic clk_audio;

    always_ff@(posedge clk_25_w) 
    begin
        if (audio_divider != AUDIO_CLK_DELAY - 1) 
            audio_divider++;
        else begin 
            clk_audio <= ~clk_audio; 
            audio_divider <= 0; 
        end
    end
    BUFG clk_clock_bufg_inst(
    .O(clk_audio_w),
    .I(clk_audio)
    );

    ////
    logic[2:0] tmds;
    wire [9:0] cy, frameHeight;
    wire [9:0] cx, frameWidth;
    
    logic hdmi_reset = 1'b0;
    always @(posedge clk_25_w) begin
        hdmi_reset <= 1'b0;
        if (vdp_cx == 9'b0 && vdp_cy == 9'b0) begin
            if (vdp_cx != cx || vdp_cy != cy) 
                hdmi_reset <= 1'b1;
        end
    end

    reg [15:0] sample; 
    reg [15:0] audio_sample_word [1:0], audio_sample_word0 [1:0];
    always @(posedge clk_25_w) begin       // crossing clock domain
        audio_sample_word0[0] <= sample;
        audio_sample_word[0] <= audio_sample_word0[0];
        audio_sample_word0[1] <= sample;
        audio_sample_word[1] <= audio_sample_word0[1];
    end

    hdmi #( .VIDEO_ID_CODE(1), 
            .DVI_OUTPUT(0), 
            .VIDEO_REFRESH_RATE(59.94),
            .IT_CONTENT(1),
            .AUDIO_RATE(AUDIO_RATE), 
            .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
            .VENDOR_NAME({"Unknown", 8'd0}), // Must be 8 bytes null-padded 7-bit ASCII
            .PRODUCT_DESCRIPTION({"FPGA", 96'd0}), // Must be 16 bytes null-padded 7-bit ASCII
            .SOURCE_DEVICE_INFORMATION(8'h00), // See README.md or CTA-861-G for the list of valid codes
            .START_X(0),
            .START_Y(0) )

    hdmi ( .clk_pixel_x5(clk_125_w), 
          .clk_pixel(clk_25_w), 
          .clk_audio(clk_audio_w),
          .rgb({rgb_r_w, rgb_g_w, rgb_b_w}), 
          .reset( ~reset_n_w | hdmi_reset ),
          .audio_sample_word(audio_sample_word),
          .tmds(tmds), 
          .tmds_clock(tmdsClk), 
          .cx(cx), 
          .cy(cy),
          .frame_width( frameWidth ),
          .frame_height( frameHeight ) );

    // Gowin LVDS output buffer
    ELVDS_OBUF tmds_bufds [3:0] (
        .I({clk_25_w, tmds}),
        .O({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n})
    );

    reg [11:0] audio_sample;

    SPI_MCP3202 #(
	.SGL(1),        // sets ADC to single ended mode
	.ODD(0)         // sets sample input to channel 0
	)
    SPI_MCP3202 (
	.clk(clk_125_w),                 // 125  MHz 
	.EN(reset_n_w),                  // Enable the SPI core (ACTIVE HIGH)
	.MISO(adc_miso),                // data out of ADC (Dout pin)
	.MOSI(adc_mosi),               // Data into ADC (Din pin)
	.SCK(adc_clk), 	           // SPI clock
	.o_DATA(audio_sample),      // 12 bit word (for other modules)
    .CS(adc_cs),                 // Chip Select
	.DATA_VALID(sample_valid)          // is high when there is a full 12 bit word. 
	); 

    always @(posedge clk_25_w) begin     
        if (sample_valid)
            sample <= { 4'b0, audio_sample[11:3], 3'b0 };
    end


    assign led[5:0] = ~sample[12:7];

endmodule
