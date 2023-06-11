module ram16k(
    input clk,
    input we,
    input [0:13] addr,
    input [0:13] addr2,
    input [0:7] din,
    output [0:7] dout,
    output [0:7] dout2
);

    reg [7:0] mem_r[0:16383];
    reg [7:0] dout_r;
    reg [7:0] dout2_r;

initial begin
    $readmemh("../res/bootscreen.bin.hex", mem_r);
end

    always @(posedge clk) begin
    
        dout_r <= mem_r[addr];
        dout2_r <= mem_r[addr2];
        if (we == 1) begin
            mem_r[addr] <= din;
        end

    end

    assign dout = dout_r;
    assign dout2 = dout2_r;

endmodule