module ram64k(
    input clk,
    input we,
    input re,
    input [15:0] addr,
    input [7:0] din,
    output [7:0] dout
);

    reg [7:0] mem_r[0:65535];
    reg [7:0] dout_r;

//initial begin
//    $readmemh("../res/bootscreen.bin.hex", mem_r);
//    $readmemh("../res/hexscreen.bin.hex", mem_r);
//end

    always @(posedge clk) begin
    
        if (re == 1)
            dout_r <= mem_r[addr];

        if (we == 1) 
            mem_r[addr] <= din;

    end

    assign dout = dout_r;

endmodule