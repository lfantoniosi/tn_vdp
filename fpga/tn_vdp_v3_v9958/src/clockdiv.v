module CLOCK_DIV
#(
parameter real CLK_SRC = 135,
parameter real CLK_DIV = 3.6,
parameter int PRECISION_BITS = 16
)
(
    input clk_src,
    output clk_div
);

localparam int  CLK_HALF = $floor(CLK_SRC / CLK_DIV / 2.0);
localparam int  CLK_END  = $floor(CLK_SRC / CLK_DIV);
localparam real CLK_SKEW = (CLK_SRC / CLK_DIV) - $floor(CLK_SRC / CLK_DIV);
localparam int  SKW_TICKS = $floor(CLK_SKEW / 2.0 / (1.0 / ($pow(2,PRECISION_BITS)-1)));

logic [$clog2(CLK_END-1):0] cdiv = 1;
logic [PRECISION_BITS:0] sdiff = 0;
logic clk_skew = 0;
logic clkd;

always_ff@(posedge clk_src)
begin
    
    if (sdiff[PRECISION_BITS-1] == 0)
        if (cdiv != CLK_HALF-1 && cdiv != CLK_END-1) 
            cdiv++;
        else begin 
            clkd <= ~clkd; 
            if (cdiv == CLK_END-1) begin
                sdiff = sdiff + SKW_TICKS;
                cdiv = 0;
            end
            else cdiv = cdiv + 1;

        end
    else sdiff[PRECISION_BITS-1] = 0;

end

assign clk_div = clkd;


endmodule
