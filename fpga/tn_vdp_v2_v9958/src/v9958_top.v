`define GW_IDE

module v9958_top(
    input   clk,
    input   rst_n,

    input   reset_n,
    input   [1:0] mode,
    input   csw_n,
    input   csr_n,

    output  int_n,
    output  gromclk,
    output  cpuclk,
    inout   [0:7] cd,

    output  adc_clk,
    output  adc_cs,
    output  adc_mosi,
    input   adc_miso,

    output  [5:0]   led,

    input   maxspr_n,
    input   scanlin_n,
    input   gromclk_ena_n,
    input   cpuclk_ena_n,

    output            tmds_clk_p,
    output            tmds_clk_n,
    output     [2:0]  tmds_data_p,
    output     [2:0]  tmds_data_n

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

    wire            pal_mode;

    wire clk_w;
    wire clk_3_w;

    wire clk_135_w;
    wire clk_135_lock_w;
    wire clk_67_w;


    BUFG clk_bufg_inst(
    .O(clk_w),
    .I(clk)
    );

    CLK_135_3 clk_135_3_inst(
        .clkout(clk_135_w), 
        .lock(clk_135_lock_w), 
        .clkoutd(clk_3_w), 
        .reset(~rst_n), 
        .clkin(clk) 
    );

    CLKDIV clk_67_inst (
        .CLKOUT(clk_67_w), 
        .HCLKIN(clk_135_w), 
        .RESETN(clk_135_lock_w),
        .CALIB(1'b1)
    );
    defparam clk_67_inst.DIV_MODE = "2";
    defparam clk_67_inst.GSREN = "false"; 


    wire rst_n_w;
    assign rst_n_w = rst_n & clk_135_lock_w; 

    reg  [7:0] pwr_cnt;
    reg  pwr_on_r;

    always @(posedge clk_w or negedge rst_n_w) begin
        if(rst_n_w == 0) begin
            pwr_cnt = 7'd0;
            pwr_on_r = 1'd0;
        end
        else begin
            if (pwr_cnt == 7'd8) begin
                pwr_on_r = 1'b1;
            end else
            begin
                pwr_cnt = pwr_cnt + 7'd1;
            end
        end
    end

    wire reset_w;
    assign reset_n_w = pwr_on_r & reset_n;
    assign reset_w = ~reset_n_w;

    wire [7:0] vdp_dbi_w;

    wire    VrmReq;
    assign  VrmReq = (WeVdp_n ^ ReVdp_n) & VideoDLClk;
    wire    VrmWre;
    assign  VrmWre = (~WeVdp_n) & VideoDLClk;

    reg io_state_r = 1'b0; 
    reg [1:0] cs_latch;
    reg csrn_21_r;
    reg cswn_21_r;
    
    ram32k vram32k_inst(
      .clk(clk_w),
      .we(~WeVdp_n & VideoDLClk),
      .addr(VdpAdr[14:0]),
      .din(VrmDbo),
      .dout(vdp_dbi_w)
    );

	// Internal bus signals (common)

	wire	[7:0]	CpuDbi;
 
    reg [1:0] csr_sync_r;
    reg [1:0] csw_sync_r;
    wire csr_next;
    wire csw_next;
    reg csrn_108_r;
    reg cswn_108_r;
    wire cswn_w;
    wire csrn_w;

    assign VrmDbi = { vdp_dbi_w, vdp_dbi_w};
 
    assign cd = csw_n == 0 ? 8'bzzzzzzzz : csr_n == 0 ? CpuDbi : 8'b0;

    assign VDP_ID  =  5'b00010; // V9958
    assign OFFSET_Y =  6'b0010011;
    assign scanlin = ~scanlin_n;


    always @(posedge clk_67_w or negedge reset_n_w) begin
        if(reset_n_w == 0) begin
            csr_sync_r = 2'b11;
            csrn_108_r = 1'b1;

            csw_sync_r = 2'b11;
            cswn_108_r = 1'b1;

        end
        else begin

            csr_sync_r = { csr_sync_r[0], csr_n };
            csrn_108_r = csr_next;

            csw_sync_r = { csw_sync_r[0], csw_n };
            cswn_108_r = csw_next;

        end
    end

    assign csr_next = (csr_sync_r == 2'b00) ? 1'b0 : (csr_sync_r == 2'b11 ? 1'b1 : csr_next);
    assign csrn_w = csrn_108_r;

    assign csw_next = (csw_sync_r == 2'b00) ? 1'b0 : (csw_sync_r == 2'b11 ? 1'b1 : csw_next);
    assign cswn_w = cswn_108_r;


	reg			    CpuReq;
	reg 			CpuWrt;
	reg   	[15:0]	CpuAdr;
    reg     [7:0]   CpuDbo;

     always @(posedge clk_w or negedge reset_n_w) begin
        if(reset_n_w == 0) begin
            io_state_r = 1'b0;
            csrn_21_r = 1'b1;
            cswn_21_r = 1'b1;

            CpuDbo = 1'b0;
            CpuAdr = 15'b0;
            CpuWrt = 1'b0;
            CpuReq = 1'b0;

        end
        else begin
            if (!io_state_r) begin
                csrn_21_r = csrn_w;
                cswn_21_r = cswn_w;

                CpuAdr = { 14'b0, { mode[1], mode[0] }};
                CpuDbo = {cd[0], cd[1], cd[2], cd[3], cd[4], cd[5], cd[6], cd[7]};
                CpuReq = (csrn_w ^ cswn_w);
                CpuWrt = ~cswn_w;

                cs_latch = { csrn_w, cswn_w };
                io_state_r = 1'b1;
            end else begin
                 csrn_21_r = 1'b1;
                 cswn_21_r = 1'b1;

                 CpuWrt = 1'b0;
                 CpuReq = 1'b0;

                 if (cs_latch != { csrn_w, cswn_w }) begin
                    io_state_r = 1'b0;
                 end
            end


        end
    end

    VDP u_v9958 (
		.CLK21M				( clk_w   							),
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
		.VDPSPEEDMODE		( 1'b1	                            ),	// for V9958 MSX2+/tR VDP
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
        .SPMAXSPR           ( ~maxspr_n                         ),
        .PAL_MODE           ( pal_mode                          )
	);


	//--------------------------------------------------------------
	// Video output
	//--------------------------------------------------------------

    logic [9:0] cy;
    logic [9:0] cx;

    wire [7:0] dvi_r;
    wire [7:0] dvi_g;
    wire [7:0] dvi_b;

    assign dvi_r = (scanlin && cy[0]) ? { 1'b0, VideoR, 1'b0 } : {VideoR, 2'b0 };
    assign dvi_g = (scanlin && cy[0]) ? { 1'b0, VideoG,  1'b0 } : {VideoG,  2'b0 };
    assign dvi_b = (scanlin && cy[0]) ? { 1'b0, VideoB,   1'b0 } : {VideoB,   2'b0 };

    reg [2:0] gromtick;

    always @(posedge clk_3_w) begin
        if (pwr_on_r == 0) begin
            gromtick = 3'b0;
        end 
        else begin
            gromtick = gromtick + 3'b1;
        end
    end
    
    wire cpuclk_w;
    assign cpuclk_w = clk_3_w & pwr_on_r;
    wire gromclk_w;
    assign gromclk_w = ~gromtick[2] & pwr_on_r;

    assign gromclk = gromclk_ena_n ? cpuclk_w: gromclk_w; 
    assign cpuclk = cpuclk_ena_n ? 1'bz : cpuclk_w;
    assign int_n = pVdpInt_n;

////////////

    logic v_reset_w;
    reg ff_pal_mode;
    
    always_ff@(posedge clk_w) 
    begin
        if (ff_pal_mode != pal_mode) begin
            v_reset_w <= 1'b1;
            ff_pal_mode <= pal_mode;
        end else
            v_reset_w <= 1'b0;
    end

    localparam CLKFRQ = 27000;
    localparam AUDIO_RATE=44100;
    localparam AUDIO_BIT_WIDTH = 16;
    localparam AUDIO_CLK_DELAY = CLKFRQ * 1000 / AUDIO_RATE / 2;
    localparam NUM_CHANNELS = 3;
    logic [$clog2(AUDIO_CLK_DELAY)-1:0] audio_divider;
    logic clk_audio_w;

    always_ff@(posedge clk_w) 
    begin
        if (audio_divider != AUDIO_CLK_DELAY - 1) 
            audio_divider++;
        else begin 
            clk_audio_w <= ~clk_audio_w; 
            audio_divider <= 0; 
        end
    end

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
            .START_Y(525-49), //(525-49),
            .NUM_CHANNELS(NUM_CHANNELS)
            )

    hdmi_ntsc ( .clk_pixel_x5(clk_135_w), 
          .clk_pixel(clk_w), 
          .clk_audio(clk_audio_w),
          .rgb({dvi_r, dvi_g, dvi_b}), 
          .reset( reset_w | v_reset_w ),
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
            .IT_CONTENT(1),
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
          .reset( reset_w | v_reset_w ),
          .audio_sample_word(audio_sample_word),
          .cx(cx_pal), 
          .cy(cy_pal),
          .tmds_internal(tmds_pal)
        );

    assign cx = pal_mode ? cx_pal : cx_ntsc;
    assign cy = pal_mode ? cy_pal : cy_ntsc;

    logic[2:0] tmds;
    logic [9:0] tmds_internal [NUM_CHANNELS-1:0];

    assign tmds_internal = pal_mode ? tmds_pal : tmds_ntsc;
    
    serializer #(.NUM_CHANNELS(NUM_CHANNELS), .VIDEO_RATE(0)) serializer(.clk_pixel(clk_w), .clk_pixel_x5(clk_135_w), .reset(reset_w), .tmds_internal(tmds_internal), .tmds(tmds) ); 

    // Gowin LVDS output buffer
    ELVDS_OBUF tmds_bufds [3:0] (
        .I({clk_w, tmds}),
        .O({tmds_clk_p, tmds_data_p}),
        .OB({tmds_clk_n, tmds_data_n})
    );

    reg [11:0] audio_sample;

    SPI_MCP3202 #(
	.SGL(1),        // sets ADC to single ended mode
	.ODD(0)         // sets sample input to channel 0
	)
    SPI_MCP3202 (
	.clk(clk_135_w),                 // 125  MHz 
	.EN(reset_n_w),                  // Enable the SPI core (ACTIVE HIGH)
	.MISO(adc_miso),                // data out of ADC (Dout pin)
	.MOSI(adc_mosi),               // Data into ADC (Din pin)
	.SCK(adc_clk), 	           // SPI clock
	.o_DATA(audio_sample),      // 12 bit word (for other modules)
    .CS(adc_cs),                 // Chip Select
	.DATA_VALID(sample_valid)          // is high when there is a full 12 bit word. 
	); 

    always @(posedge clk_67_w) begin     
        if (sample_valid)
            sample <= { 2'b0, audio_sample[11:2], 4'b0 };
    end

    assign sample_w = sample;

    assign led[5:0] = ~sample[14:9];


endmodule

