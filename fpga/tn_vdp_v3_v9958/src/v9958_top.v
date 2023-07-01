`define GW_IDE

module v9958_top(
    input   clk,
    input   clk_50,
    input   clk_125,
    input   clk_63,

    input   s1,

    input   reset_n,
    input   [1:0] mode,
    input   csw_n,
    input   csr_n,

    output  int_n,
    output  gromclk,
    output  cpuclk,
    inout   [7:0] cd,

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

    reg rst_n = 0;
    always @(posedge clk) begin
        rst_n <= ~s1;
    end

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
    wire clk_3_w;
    wire clk_135_lock_w;

    wire clk_sdram_w;
    wire clk_sdramp_w;
    wire clk_sdram_lock_w;

    logic [9:0] cy;
    logic [9:0] cx;

    BUFG clk_bufg_inst(
    .O(clk_w),
    .I(clk)
    );

    BUFG clk_50_bufg_inst(
    .O(clk_50_w),
    .I(clk_50)
    );

    BUFG clk_63_bufg_inst(
    .O(clk_63_w),
    .I(clk_63)
    );

    BUFG clk_125_bufg_inst(
    .O(clk_125_w),
    .I(clk_125)
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

    CLK_81P clk_sdramp_inst (
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
    reg [7:0] SdSeq = 7'b0;

    reg    [7:0] VrmDbo_r;
    wire   [7:0] VrmDbo_w;
    assign VrmDbo_w = VrmDbo_r;

    reg    VrmWre_r = 1'b0;
    wire   VrmWre_w;
    reg    VrmRde_r = 1'b0;
    wire   VrmRde_w;
    assign VrmWre_w = VrmWre_r;
    assign VrmRde_w = VrmRde_r;

    reg    refresh_r = 1'b0;
    wire   refresh_w;
    assign refresh_w = refresh_r;

    always @(posedge clk_sdramp_w or negedge reset_n_w) begin
        if (~reset_n_w) begin
            SdSeq = 7'd0;
            refresh_r <= 1'b0;
            VrmWre_r <= 1'b0;
            VrmRde_r <= 1'b0;
        end else begin 

            refresh_r <= 1'b0;
            VrmWre_r <= 1'b0;
            VrmRde_r = 1'b0;

            if (SdSeq == 7'd0 && VideoDLClk && VideoDHClk  && ~ram_busy) 
            begin
                VrmWre_r <= ~WeVdp_n;
                VrmRde_r <= ~ReVdp_n;
                VrmDbo_r <= VrmDbo;
                SdSeq = 7'd1;
            end
            else if (SdSeq == 7'd1 && ~ram_busy) 
            begin
                SdSeq = 7'd2;
            end
            else if (SdSeq == 7'd2 && ~ram_busy) 
            begin
                refresh_r <= 1'b1;
                SdSeq = 7'd3;
            end
            else if (SdSeq == 7'd3 && ~ram_busy) 
            begin
                SdSeq = 7'd0;
            end
        end
    end

      wire [19:0] ram_total_written;
      memory_controller #(.FREQ(67_500_000) )
       vram(.clk(clk_sdramp_w), 
            .clk_sdram(clk_sdram_w), 
            .resetn(reset_n_w),
            .read(VrmRde_w), 
            .write(VrmWre_w),
            .refresh(refresh_w),
            .addr({ 5'b0 , VdpAdr[15:0] } ),
            .din({ VrmDbo_w, VrmDbo_w }),
            .wdm({ ~VdpAdr[16], VdpAdr[16] }),
            .dout(VrmDbi),
            .busy(ram_busy), 
            .fail(ram_fail), 
            .total_written(ram_total_written),

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
    reg csrn_27_r;
    reg cswn_27_r;
	wire	[7:0]	CpuDbi;
 
    reg [1:0] csr_sync_r;
    reg [1:0] csw_sync_r;
    wire csr_next;
    wire csw_next;
    reg csrn_sdram_r;
    reg cswn_sdram_r;
    wire cswn_w;
    wire csrn_w;

 
    assign cd = csr_n == 0 ? CpuDbi : 8'bzzzzzzzz;

    assign VDP_ID  =  5'b00010; // V9958
    assign OFFSET_Y =  6'd16; //6'b0010011;
    assign scanlin = ~scanlin_n;


    always @(posedge clk_sdram_w or negedge reset_n_w) begin
        if(reset_n_w == 0) begin
            csr_sync_r = 2'b11;
            csrn_sdram_r = 1'b1;

            csw_sync_r = 2'b11;
            cswn_sdram_r = 1'b1;

        end
        else begin

            csr_sync_r = { csr_sync_r[0], csr_n };
            csrn_sdram_r = csr_next;

            csw_sync_r = { csw_sync_r[0], csw_n };
            cswn_sdram_r = csw_next;

        end
    end

    assign csr_next = (csr_sync_r == 2'b00) ? 1'b0 : (csr_sync_r == 2'b11 ? 1'b1 : csr_next);
    assign csrn_w = csrn_sdram_r;

    assign csw_next = (csw_sync_r == 2'b00) ? 1'b0 : (csw_sync_r == 2'b11 ? 1'b1 : csw_next);
    assign cswn_w = cswn_sdram_r;


	reg			    CpuReq;
	reg 			CpuWrt;
	reg   	[15:0]	CpuAdr;
    reg     [7:0]   CpuDbo;

     always @(posedge clk_w or negedge reset_n_w) begin
        if(reset_n_w == 0) begin
            io_state_r = 1'b0;
            csrn_27_r = 1'b1;
            cswn_27_r = 1'b1;

            CpuDbo = 1'b0;
            CpuAdr = 15'b0;
            CpuWrt = 1'b0;
            CpuReq = 1'b0;
        end
        else begin

            if (!io_state_r) begin
                csrn_27_r = csrn_w;
                cswn_27_r = cswn_w;

                CpuAdr = { 14'b0, { mode[1], mode[0] }};
                CpuDbo = cd; 
                CpuReq = (csrn_w ^ cswn_w);
                CpuWrt = ~cswn_w;

                cs_latch = { csrn_w, cswn_w };
                io_state_r = 1'b1;

            end else begin
                 csrn_27_r = 1'b1;
                 cswn_27_r = 1'b1;

                 CpuWrt = 1'b0;
                 CpuReq = 1'b0;

                 if (cs_latch != { csrn_w, cswn_w }) begin
                    io_state_r = 1'b0;
                 end

            end

        end
    end

    wire vdp_pal_mode;
    wire hdmi_reset;
    VDP u_v9958 (
		.CLK21M				( clk_w         						),
		.RESET				( reset_w        					),
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
        .HDMI_RESET         ( hdmi_reset                        ),
        .PAL_MODE           ( vdp_pal_mode                      ),
        .SPMAXSPR           ( ~maxspr_n                         )
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

    assign gromclk = gromclk_ena_n ? cpuclk_w: gromclk_w; 
    assign cpuclk = cpuclk_ena_n ? 1'bz : cpuclk_w;
//////////

    reg ff_pal_mode;
    wire pal_mode;

    always_ff@(posedge clk_w) 
    begin
        if (hdmi_reset)
            ff_pal_mode <= vdp_pal_mode;
    end
    assign pal_mode = vdp_pal_mode;

    localparam CLKFRQ = 27000;
    localparam AUDIO_RATE=44100;
    localparam AUDIO_BIT_WIDTH = 16;
    localparam AUDIO_CLK_DELAY = CLKFRQ * 1000 / AUDIO_RATE / 2;
    localparam NUM_CHANNELS = 3;
    logic [$clog2(AUDIO_CLK_DELAY)-1:0] audio_divider;
    logic clk_audio;
    logic clk_audio_w;

    always_ff@(posedge clk) 
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

    reg [15:0] sample; 
    wire [15:0] sample_w;

    reg [15:0] audio_sample_word [1:0], audio_sample_word0 [1:0];
    always @(posedge clk_w) begin       // crossing clock domain
        audio_sample_word0[0] <= sample_w;
        audio_sample_word[0] <= audio_sample_word0[0];
        audio_sample_word0[1] <= sample_w;
        audio_sample_word[1] <= audio_sample_word0[1];
    end

    logic [9:0] cy_ntsc;
    logic [9:0] cx_ntsc;
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
            .START_Y(525-50), //(525-49),
            .NUM_CHANNELS(NUM_CHANNELS)
            )

    hdmi_ntsc ( .clk_pixel_x5(clk_135_w), 
          .clk_pixel(clk_w), 
          .clk_audio(clk_audio_w),
          .rgb({dvi_r, dvi_g, dvi_b}), 
          .reset( hdmi_reset | reset_w ),
          .audio_sample_word(audio_sample_word),
          .cx(cx_ntsc), 
          .cy(cy_ntsc),
          .tmds_internal(tmds_ntsc)
        );

    logic [9:0] cy_pal;
    logic [9:0] cx_pal;
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
            .START_Y(625-55), //(147),
            .NUM_CHANNELS(NUM_CHANNELS)
            )

    hdmi_pal ( .clk_pixel_x5(clk_135_w), 
          .clk_pixel(clk_w), 
          .clk_audio(clk_audio_w),
          .rgb({dvi_r, dvi_g, dvi_b}), 
          .reset( hdmi_reset | reset_w ),
          .audio_sample_word(audio_sample_word),
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

    // ADC
    wire w_SCK_enable;
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
//	.SCK(adc_clk), 	           // SPI clock
    .SCK_ENA(w_SCK_enable),
	.o_DATA(audio_sample),      // 12 bit word (for other modules)
    .CS(adc_cs),                 // Chip Select
	.DATA_VALID(sample_valid)          // is high when there is a full 12 bit word. 
	); 

    always @(posedge clk_125_w) begin     
        if (sample_valid)
            sample <= { 2'b0, audio_sample[11:3], 5'b0 };
    end
    assign sample_w = sample;


    localparam SCKCLK_DELAY = 68;
    logic [$clog2(SCKCLK_DELAY)-1:0] SCK_divider;
    logic clk_SCK;
    always_ff@(posedge clk_125_w) 
    begin
        if (SCK_divider != SCKCLK_DELAY - 1) 
            SCK_divider++;
        else begin 
            clk_SCK <= ~clk_SCK; 
            SCK_divider <= 0; 
        end
    end
    wire clk_SCK_w;
    wire w_SCK_enable;
    BUFG clk_sck_bufg_inst(
    .O(clk_SCK_w),
    .I(clk_SCK)
    );

	assign adc_clk = clk_SCK_w & w_SCK_enable;

    ////
    //assign led[1:0] = { cpuclk_w, gromclk_w };

endmodule



