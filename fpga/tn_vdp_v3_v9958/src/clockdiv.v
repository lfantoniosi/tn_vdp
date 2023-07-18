module CLOCK_DIV
#(
parameter real CLK_SRC = 135,
parameter real CLK_DIV = 3.6
)
(
    input clk_src,
    output clk_div
);

localparam int  CLK_HALF = $floor(CLK_SRC / CLK_DIV / 2.0);
localparam int  CLK_END  = $floor(CLK_SRC / CLK_DIV);
logic [$clog2(CLK_END-1):0] cdiv = 1;
logic clkd;

always_ff@(posedge clk_src)
begin
    if (cdiv != CLK_HALF-1 && cdiv != CLK_END-1) 
        cdiv++;
    else begin 
        clkd <= ~clkd; 
        cdiv = (cdiv == CLK_END-1) ? 0 : cdiv + 1;
    end
end

assign clk_div = clkd;


endmodule
