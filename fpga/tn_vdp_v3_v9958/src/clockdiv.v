module CLOCK_DIV
#(
parameter real CLK_SRC = 135,
parameter real CLK_DIV = 3.6
)
(
    input clk_src,
    output clk_div
);

localparam int CLK_1DIV = $floor(CLK_SRC / CLK_DIV / 2.0 + 1.0);
localparam int CLK_2DIV = $floor(CLK_SRC / CLK_DIV + 1.0);
localparam int CLK_SKEW = $floor(CLK_SRC / (CLK_DIV - (CLK_SRC / CLK_2DIV)) + 1.0) / CLK_2DIV;
localparam int CLK_3DIV = CLK_SKEW > 0 ? CLK_SKEW : -CLK_SKEW;

logic [$clog2(CLK_3DIV)-1:0] sdiv = 0;
logic [$clog2(CLK_2DIV)-1:0] fdiv = 0;
logic clkd;
logic skewpos = 0;

always_ff@(posedge clk_src)
begin
    if (CLK_SKEW > 0) begin
        if (skewpos)
            if (fdiv != CLK_1DIV-1 && fdiv != CLK_2DIV-1) 
                fdiv++;
            else begin 
                clkd <= ~clkd; 
                fdiv = (fdiv == CLK_2DIV-1) ? 0 : fdiv + 1;
            end
    end

    if (fdiv != CLK_1DIV-1 && fdiv != CLK_2DIV-1) 
        fdiv++;
    else begin 
        clkd <= ~clkd; 
        fdiv = (fdiv == CLK_2DIV-1) ? 0 : fdiv + 1;
    end
end

assign clk_div = clkd;

always_ff@(posedge clk_src)
begin
    if (CLK_SKEW > 0) begin
        if (sdiv != CLK_3DIV-1) begin
            sdiv++;
            skewpos = 0;
        end else begin 
            skewpos = 1;
            sdiv = 0;
        end
    end
end

endmodule
