module ram32k(
    input clk,
    input we,
    input [14:0] addr,
    input [7:0] din,
    output [7:0] dout
);

    reg [7:0] mem_r[0:32767];
    reg [7:0] dout_r;

initial begin
    $readmemh("../res/bootscreen.bin.hex", mem_r);
end

    always @(posedge clk) begin
    
        dout_r <= mem_r[addr];

        if (we == 1) begin
            mem_r[addr] <= din;
        end

    end

    assign dout = dout_r;

endmodule