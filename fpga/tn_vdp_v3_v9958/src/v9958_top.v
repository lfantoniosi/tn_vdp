`define GW_IDE

module v9958_top(
    input   clk,
    input   clk_50,
    input   clk_125,
 //   input   clk_111,

    input   s1,

    input   reset_n,
    input   [1:0] mode,
    input   csw_n,
    input   csr_n,

    output  int_n,
    output  gromclk,
    output  cpuclk,
    inout   [7:0] cd,
//    inout   [0:7] cd,

    output  adc_clk,
    output  adc_cs,
    output  adc_mosi,
    input   adc_miso,

    //output  [1:0]   led,

    input   maxspr_n,
    input   scanlin_n,
    input   gromclk_ena_n,
    input   cpuclk_ena_n,

    output            tmds_clk_p,
    output            tmds_clk_n,
    output     [2:0]  tmds_data_p,
    output     [2:0]  tmds_data_n,

    // SDRAM
    output O_sdram_clk,
    output O_sdram_cke,
    output O_sdram_cs_n,            // chip select
    output O_sdram_cas_n,           // columns address select
    output O_sdram_ras_n,           // row address select
    output O_sdram_wen_n,           // write enable
    inout [31:0] IO_sdram_dq,       // 32 bit bidirectional data bus
    output [10:0] O_sdram_addr,     // 11 bit multiplexed address bus
    output [1:0] O_sdram_ba,        // two banks
    output [3:0] O_sdram_dqm       // 32/4


    );


// VDP signals
	wire			VdpReq;
	wire	[7:0]	VdpDbi;
	wire			VideoSC;
	wire			VideoDLClk;
	wire			VideoDHClk;
	wire			WeVdp_n;
    wire            ReVdp_n;
	wire	[16:0]	VdpAdr;
	wire	[7:0]	VrmDbo;
	wire	[15:0]	VrmDbi;
	wire			pVdpInt_n;
	wire	[4:0]	VDP_ID;
	wire	[6:0]	OFFSET_Y;
    wire            blank_o;

    wire            r9palmode;

	// Video signals
	wire	[5:0]	VideoR;								// RGB Red
	wire	[5:0]	VideoG;								// RGB Green
	wire	[5:0]	VideoB;								// RGB Blue
	wire			VideoHS_n;							// Horizontal Sync
	wire			VideoVS_n;							// Vertical Sync
	wire			VideoCS_n;							// Composite Sync

    wire            scanlin;
    wire            reset_n_w;


    wire clk_bufg;

    wire clk_135_w;
    wire clk_135_lock_w;

    wire clk_sdram_w;
    wire clk_sdramp_w;
    wire clk_sdram_lock_w;

    logic [9:0] cy;
    logic [9:0] cx;

    wire clk_w;
    BUFG clk_bufg_inst(
    .O(clk_w),
    .I(clk)
    );

    wire clk_50_w;
    BUFG clk_50_bufg_inst(
    .O(clk_50_w),
    .I(clk_50)
    );
    wire clk_125_w;
    BUFG clk_125_bufg_inst(
    .O(clk_125_w),
    .I(clk_125)
    );

    reg s1_n = 0;
    always @(posedge clk_w) s1_n <= ~s1;

    BUFG rst_bufg_inst(
    .O(rst_n),
    .I(s1_n)
    );

    CLK_135 clk_135_inst(
        .clkout(clk_135), //output clkout
        .lock(clk_135_lock_w), //output lock
        .reset(~rst_n), //input reset
        .clkin(clk) //input clkin
    );

    BUFG clk_135_bufg_inst(
    .O(clk_135_w),
    .I(clk_135)
    );

    wire rst_n_w;
    assign rst_n_w = rst_n & clk_135_lock_w & clk_sdram_lock_w; 

    CLK_108P clk_sdramp_inst (
        .clkout(clk_sdram), //output clkout
        .lock(clk_sdram_lock_w), //output lock
        .clkoutp(clk_sdramp), //output clkoutp
        .reset(~rst_n), //input reset
        .clkin(clk) //input clkin
    );

    BUFG clk_sdram_bufg_inst(
    .O(clk_sdram_w),
    .I(clk_sdram)
    );
    BUFG clk_sdramp_bufg_inst(
    .O(clk_sdramp_w),
    .I(clk_sdramp)
    );

    wire reset_w;
    assign reset_n_w = rst_n_w & reset_n;
    assign reset_w = ~reset_n_w;

    wire ram_busy, ram_fail;

      wire [19:0] ram_total_written;
      wire ram_enabled;
      memory_controller #(.FREQ(108_000_000) )
       vram(.clk(clk_sdramp_w), 
            .clk_sdram(clk_sdram_w), 
            .resetn(reset_n_w),
            .read(WeVdp_n & VideoDLClk & VideoDHClk & ~ram_busy), 
            .write(~WeVdp_n & VideoDLClk & VideoDHClk & ~ram_busy),
            .refresh(~VideoDLClk & ~VideoDHClk & ~ram_busy),
            .addr({ 5'b0 , VdpAdr[15:0] } ),
            .din({ VrmDbo, VrmDbo }),
            .wdm({ ~VdpAdr[16], VdpAdr[16] }),
            .dout(VrmDbi),
            .busy(ram_busy), 
            .fail(ram_fail), 
            .total_written(ram_total_written),
            .enabled(ram_enabled),

            .SDRAM_DQ(IO_sdram_dq), .SDRAM_A(O_sdram_addr), .SDRAM_BA(O_sdram_ba), .SDRAM_nCS(O_sdram_cs_n),
            .SDRAM_nWE(O_sdram_wen_n), .SDRAM_nRAS(O_sdram_ras_n), .SDRAM_nCAS(O_sdram_cas_n), 
            .SDRAM_CLK(O_sdram_clk), .SDRAM_CKE(O_sdram_cke), .SDRAM_DQM(O_sdram_dqm)
    );


//    wire [7:0] vdp_dbi;
//    ram64k vram64k_inst(
//      .clk(clk_w),
//      .we(~WeVdp_n & VideoDLClk),
//      .re(1'b1), //~ReVdp_n & VideoDLClk),
//      .addr(VdpAdr[15:0] ),
//      .din(VrmDbo),
//      .dout(vdp_dbi)
//    );
//    assign VrmDbi = { vdp_dbi, vdp_dbi };

	// Internal bus signals (common)

    reg io_state_r = 1'b0; 
    reg [1:0] cs_latch;
	wire	[7:0]	CpuDbi;
 
    reg [1:0] csr_sync_r;
    reg [1:0] csw_sync_r;
    wire csr_next;
    wire csw_next;
    reg csrn_sdram_r;
    reg cswn_sdram_r;

 
    assign cd = csr_n == 0 ? CpuDbi : 8'bzzzzzzzz;

    assign VDP_ID  =  5'b00010; // V9958
    assign OFFSET_Y =  6'd16; 
    assign scanlin = ~scanlin_n;

    wire cswn_w;
    PINFILTER cswn_filter (
        .clk(clk_sdram_w),
        .reset_n(reset_n_w),
        .din(csw_n),
        .dout(cswn_w)
    );

    wire csrn_w;
    PINFILTER csrn_filter (
        .clk(clk_sdram_w),
        .reset_n(reset_n_w),
        .din(csr_n),
        .dout(csrn_w)
    );

	reg			    CpuReq;
	reg 			CpuWrt;
	reg   	[15:0]	CpuAdr;
    reg     [7:0]   CpuDbo;

     always @(posedge clk_w or negedge reset_n_w) begin
        if(reset_n_w == 0) begin
            io_state_r = 1'b0;

            CpuDbo = 1'b0;
            CpuAdr = 15'b0;
            CpuWrt = 1'b0;
            CpuReq = 1'b0;
        end
        else begin

            if (!io_state_r) begin

                CpuAdr = { 14'b0, { mode[1], mode[0] }};
                CpuDbo = cd; 
                CpuReq = (csrn_w ^ cswn_w);
                CpuWrt = ~cswn_w;

                cs_latch = { csrn_w, cswn_w };
                io_state_r = 1'b1;

            end else begin

                 CpuWrt = 1'b0;
                 CpuReq = 1'b0;

                 if (cs_latch != { csrn_w, cswn_w }) begin
                    io_state_r = 1'b0;
                 end

            end

        end
    end

    wire pal_mode;
    wire vdp_hdmi_reset;
    wire [10:0] vdp_cx;
    wire [10:0] vdp_cy;
    VDP u_v9958 (
		.CLK21M				( clk_w         					),
		.RESET				( reset_w | ~ram_enabled       		),
		.REQ				( CpuReq 							),
		.ACK				( 									),
		.WRT				( CpuWrt							),
		.ADR				( CpuAdr							),
		.DBI				( CpuDbi   							),
		.DBO				( CpuDbo   						    ),
		.INT_N				( pVdpInt_n							),
		.PRAMOE_N			( ReVdp_n							),
		.PRAMWE_N			( WeVdp_n							),
		.PRAMADR			( VdpAdr							),
		.PRAMDBI			( VrmDbi							),
		.PRAMDBO			( VrmDbo							),
		.VDPSPEEDMODE		( 1'b0	                            ),	// for V9958 MSX2+/tR VDP
		.RATIOMODE			( 3'b000							    ),	// for V9958 MSX2+/tR VDP
		.CENTERYJK_R25_N 	( 1'b0          					),	// for V9958 MSX2+/tR VDP
		.PVIDEOR			( VideoR							),
		.PVIDEOG			( VideoG							),
		.PVIDEOB			( VideoB							),
		.PVIDEOHS_N			( VideoHS_n							),
		.PVIDEOVS_N			( VideoVS_n							),
		.PVIDEOCS_N			( VideoCS_n							),
		.PVIDEODHCLK		( VideoDHClk						),
		.PVIDEODLCLK		( VideoDLClk						),
		.BLANK_o			( blank_o							),
		.DISPRESO			( 1'b1      				        ),  // VGA 31Khz
		.NTSC_PAL_TYPE		( 1'b1      						),
		.FORCED_V_MODE		( 1'b0      						),
		.LEGACY_VGA			( 1'b0      						),
		.VDP_ID				( VDP_ID							),
		.OFFSET_Y			( OFFSET_Y							),
        .HDMI_RESET         ( vdp_hdmi_reset                    ),
        .PAL_MODE           ( pal_mode                      ),
        .SPMAXSPR           ( ~maxspr_n                         ),  
        .CX                 ( vdp_cx                            ),
        .CY                 ( vdp_cy                            )
	);

	//--------------------------------------------------------------
	// Video output
	//--------------------------------------------------------------


    wire [7:0] dvi_r;
    wire [7:0] dvi_g;
    wire [7:0] dvi_b;

    assign dvi_r = (scanlin && cy[0]) ? { 1'b0, VideoR,   1'b0 } : {VideoR,   2'b0 };
    assign dvi_g = (scanlin && cy[0]) ? { 1'b0, VideoG,   1'b0 } : {VideoG,   2'b0 };
    assign dvi_b = (scanlin && cy[0]) ? { 1'b0, VideoB,   1'b0 } : {VideoB,   2'b0 };

    assign int_n = pVdpInt_n;

///////////

    wire clk_cpu;
    CLOCK_DIV #(
        .CLK_SRC(125.0),
        .CLK_DIV(315.0/88.0),
        .PRECISION_BITS(16)
    ) cpuclkd (
        .clk_src(clk_125_w),
        .clk_div(clk_cpu)
    );
    BUFG clk_cpuclk_bufg_inst(
    .O(cpuclk_w),
    .I(clk_cpu)
    );

//    wire clk_grom;
//    CLOCK_DIV #(
//        .CLK_SRC(125.0),
//        .CLK_DIV(3.58/8.0),
//        .PRECISION_BITS(16)
//    ) gromclkd (
//        .clk_src(clk_125_w),
//        .clk_div(clk_grom)
//    );

//    BUFG clk_gromclk_bufg_inst(
//    .O(gromclk_w),
//    .I(clk_grom)
//    );

//    assign gromclk = (gromclk_ena_n ? (cpuclk_ena_n ? cpuclk_w : 1'b1) : gromclk_w); 
    assign cpuclk = (cpuclk_ena_n ? 1'bz : cpuclk_w);
//////////

    reg ff_video_reset;

    localparam NTSC_Y = 525-40;
    localparam PAL_Y  = 625-55;
    logic [9:0] cy_ntsc;
    logic [9:0] cx_ntsc;
    logic [9:0] cy_pal;
    logic [9:0] cx_pal;

    always_ff@(posedge clk_w) 
    begin
        
        ff_video_reset <= vdp_hdmi_reset;

        if (vdp_cx == 11'd0 && vdp_cy == 11'd0) begin
            if ((pal_mode == 1'b0 && (cx_ntsc != 10'd0 || cy_ntsc != NTSC_Y)) ||
                (pal_mode == 1'b1 && (cx_pal != 10'd0 || cy_pal != PAL_Y)))
                ff_video_reset <= 1'b1;
        end
    end

    wire video_reset;
    assign video_reset = ff_video_reset;

    wire hdmi_reset;
    assign hdmi_reset = video_reset | reset_w | ~ram_enabled;

    localparam CLKFRQ = 27000;
    localparam AUDIO_RATE=44100;
    localparam AUDIO_BIT_WIDTH = 16;
    localparam NUM_CHANNELS = 3;

    wire clk_audio;
    CLOCK_DIV #(
        .CLK_SRC(27),
        .CLK_DIV(0.044100),
        .PRECISION_BITS(16)
    ) audioclkd (
        .clk_src(clk_w),
        .clk_div(clk_audio)
    );
    BUFG clk_audio_bufg_inst(
    .O(clk_audio_w),
    .I(clk_audio)
    );


    wire [15:0] sample_w;

    reg [15:0] audio_sample_word [1:0], audio_sample_word0 [1:0];
    always @(posedge clk_w) begin       // crossing clock domain
        audio_sample_word0[0] <= sample_w;
        audio_sample_word[0] <= audio_sample_word0[0];
        audio_sample_word0[1] <= sample_w;
        audio_sample_word[1] <= audio_sample_word0[1];
    end
    wire [15:0] audio_sample_word_w [1:0];
    assign audio_sample_word_w = audio_sample_word;

    logic [9:0] tmds_ntsc [NUM_CHANNELS-1:0];
    hdmi #( .VIDEO_ID_CODE(2), 
            .DVI_OUTPUT(0), 
            .VIDEO_REFRESH_RATE(59.94),
            .IT_CONTENT(1),
            .AUDIO_RATE(AUDIO_RATE), 
            .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
            .VENDOR_NAME({"Unknown", 8'd0}), // Must be 8 bytes null-padded 7-bit ASCII
            .PRODUCT_DESCRIPTION({"FPGA", 96'd0}), // Must be 16 bytes null-padded 7-bit ASCII
            .SOURCE_DEVICE_INFORMATION(8'h00), // See README.md or CTA-861-G for the list of valid codes
            .START_X(0),
            .START_Y(NTSC_Y), //(525-49),
            .NUM_CHANNELS(NUM_CHANNELS)
            )

    hdmi_ntsc ( .clk_pixel_x5(clk_135_w), 
          .clk_pixel(clk_w), 
          .clk_audio(clk_audio_w),
          .rgb({dvi_r, dvi_g, dvi_b}), 
          .reset( hdmi_reset ),
          .audio_sample_word(audio_sample_word_w),
          .cx(cx_ntsc), 
          .cy(cy_ntsc),
          .tmds_internal(tmds_ntsc)
        );

    logic [9:0] tmds_pal [NUM_CHANNELS-1:0];
    hdmi #( .VIDEO_ID_CODE(17), 
            .DVI_OUTPUT(0), 
            .VIDEO_REFRESH_RATE(50),
            .IT_CONTENT(0),
            .AUDIO_RATE(AUDIO_RATE), 
            .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
            .VENDOR_NAME({"Unknown", 8'd0}), // Must be 8 bytes null-padded 7-bit ASCII
            .PRODUCT_DESCRIPTION({"FPGA", 96'd0}), // Must be 16 bytes null-padded 7-bit ASCII
            .SOURCE_DEVICE_INFORMATION(8'h00), // See README.md or CTA-861-G for the list of valid codes
            .START_X(0), //(0),
            .START_Y(PAL_Y), //(147),
            .NUM_CHANNELS(NUM_CHANNELS)
            )

    hdmi_pal ( .clk_pixel_x5(clk_135_w), 
          .clk_pixel(clk_w), 
          .clk_audio(clk_audio_w),
          .rgb({dvi_r, dvi_g, dvi_b}), 
          .reset( hdmi_reset ),
          .audio_sample_word(audio_sample_word_w),
          .cx(cx_pal), 
          .cy(cy_pal),
          .tmds_internal(tmds_pal)
        );

    assign cx = pal_mode ? cx_pal :cx_ntsc;
    assign cy = pal_mode ? cy_pal :cy_ntsc;

    logic[2:0] tmds;
    logic [9:0] tmds_internal [NUM_CHANNELS-1:0];

    assign tmds_internal = pal_mode ? tmds_pal : tmds_ntsc;
    
    serializer #(.NUM_CHANNELS(NUM_CHANNELS), .VIDEO_RATE(0)) serializer(.clk_pixel(clk_w), .clk_pixel_x5(clk_135_w), .reset(reset_w),
    .tmds_internal(tmds_internal), .tmds(tmds) ); 

    // Gowin LVDS output buffer
    ELVDS_OBUF tmds_bufds [3:0] (
        .I({clk_w, tmds}),
        .O({tmds_clk_p, tmds_data_p}),
        .OB({tmds_clk_n, tmds_data_n})
    );

////////////////////

    // ADC
    wire sck_enable;
    wire [11:0] audio_sample;
    SPI_MCP3202 #(
	.SGL(1),        // sets ADC to single ended mode
	.ODD(0)         // sets sample input to channel 0
	)
    SPI_MCP3202 (
	.clk(clk_135_w),                 // 125  MHz 
	.EN(reset_n_w),                  // Enable the SPI core (ACTIVE HIGH)
	.MISO(adc_miso),                // data out of ADC (Dout pin)
	.MOSI(adc_mosi),               // Data into ADC (Din pin)
    .SCK_ENABLE(sck_enable),
	.o_DATA(audio_sample),      // 12 bit word (for other modules)
    .CS(adc_cs),                 // Chip Select
	.DATA_VALID(sample_valid)          // is high when there is a full 12 bit word. 
	); 

    localparam SCKCLK_SRCFRQ = 135.0;
    localparam SCKCLK_FRQ = 0.9;
    localparam integer SCKCLK_DELAY0 = $floor(SCKCLK_SRCFRQ / SCKCLK_FRQ / 2.0);
    localparam integer SCKCLK_DELAY1 = SCKCLK_DELAY0 + $floor((SCKCLK_SRCFRQ / SCKCLK_FRQ) - SCKCLK_DELAY0 + 0.5);
    logic [$clog2(SCKCLK_DELAY1)-1:0] sckclk_divider;
    logic clk_sck;


    wire clk_sck;
    CLOCK_DIV #(
        .CLK_SRC(135),
        .CLK_DIV(0.9),
        .PRECISION_BITS(16)
    ) adcclkd (
        .clk_src(clk_135_w),
        .clk_div(clk_sck)
    );
    BUFG clk_sck_bufg_inst(
    .O(sckclk_w),
    .I(clk_sck)
    );

    assign adc_clk = sckclk_w & sck_enable;
    
    reg [15:0] adc_sample;
    always @(posedge clk_135_w) begin     
        if (sample_valid)
            adc_sample <= { audio_sample[11:0], 4'b0 };
    end

    wire [31:0] adc_sample_w;
    assign adc_sample_w = { adc_sample, 16'b0 };

    reg [31:0] sample;
    LPF1 #(
        .MSBI(32)
    )
    LPF (
        .CLK21M(clk_135_w),
        .RESET(reset_w),
        .CLKENA(1'b1),
        .IDATA(adc_sample_w),
        .ODATA(sample)
    );

    assign sample_w = sample[31:16];

endmodule



