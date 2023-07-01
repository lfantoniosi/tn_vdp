module memory_controller
#(
    parameter int FREQ = 54_000_000
)(
    input clk,                // Main logic clock
    input clk_sdram,          // 180-degree of clk
    input resetn,
    input read,               // Set to 1 to read from RAM
    input write,              // Set to 1 to write to RAM
    input refresh,            // Set to 1 to auto-refresh RAM
    input [21:0] addr,        // Address to read / write
    input [15:0] din,          // Data to write
    input [1:0] wdm,
    output [15:0] dout,        // Last read data available 4 cycles after read is set
    output reg busy,          // 1 while an operation is in progress

    // debug interface
    output reg fail,          // timing mistake or sdram malfunction detected
    output reg [19:0] total_written,

    // Physical SDRAM interface
	inout  [31:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output [10:0] SDRAM_A,    // 13 bit multiplexed address bus
	output [1:0] SDRAM_BA,   // 4 banks
	output SDRAM_nCS,  // a single chip select
	output SDRAM_nWE,  // write enable
	output SDRAM_nRAS, // row address select
	output SDRAM_nCAS, // columns address select
	output SDRAM_CLK,
	output SDRAM_CKE,
    output [3:0] SDRAM_DQM
);

reg [22:0] MemAddr;
reg MemRD, MemWR, MemRefresh, MemInitializing;
reg [15:0] MemDin;
wire [15:0] MemDout;
reg [2:0] cycles;
reg r_read;
reg [15:0] data;
wire MemBusy, MemDataReady;

assign dout = (cycles == 3'd4 && r_read) ? MemDout : data;

// SDRAM driver
sdram #(
    .FREQ(FREQ)
) u_sdram (
    .clk(clk), .clk_sdram(clk_sdram), .resetn(resetn),
	.addr(busy ? MemAddr : {1'b0, addr}), .rd(busy ? MemRD : read), 
    .wr(busy ? MemWR : write), .refresh(busy ? MemRefresh : refresh),
	.din(busy ? MemDin : din), .wdm(wdm), .dout(MemDout), .busy(MemBusy), .data_ready(MemDataReady),

    .SDRAM_DQ(SDRAM_DQ), .SDRAM_A(SDRAM_A), .SDRAM_BA(SDRAM_BA), 
    .SDRAM_nCS(SDRAM_nCS), .SDRAM_nWE(SDRAM_nWE), .SDRAM_nRAS(SDRAM_nRAS),
    .SDRAM_nCAS(SDRAM_nCAS), .SDRAM_CLK(SDRAM_CLK), .SDRAM_CKE(SDRAM_CKE),
    .SDRAM_DQM(SDRAM_DQM)
);

always @(posedge clk) begin
    MemWR <= 1'b0; MemRD <= 1'b0; MemRefresh <= 1'b0;
    cycles <= cycles == 3'd7 ? 3'd7 : cycles + 3'd1;
    
    // Initiate read or write
    if (!busy) begin
        if (read || write || refresh) begin
            MemAddr <= {1'b0, addr};
            MemWR <= write;
            MemRD <= read;
            MemRefresh <= refresh;
            busy <= 1'b1;
            MemDin <= din;
            cycles <= 3'd1;
            r_read <= read;

            if (write) total_written <= total_written + 1;
        end 
    end else if (MemInitializing) begin
        if (~MemBusy) begin
            // initialization is done
            MemInitializing <= 1'b0;
            busy <= 1'b0;
        end
    end else begin
        // Wait for operation to finish and latch incoming data on read.
        if (cycles == 3'd4) begin
            busy <= 0;
            if (r_read) begin
                if (~MemDataReady)      // assert data ready
                    fail <= 1'b1;
                if (r_read) 
                    data <= MemDout;
                r_read <= 1'b0;
            end
        end
    end

    if (~resetn) begin
        busy <= 1'b1;
        fail <= 1'b0;
        total_written <= 0;
        MemInitializing <= 1'b1;
    end
end

endmodule
