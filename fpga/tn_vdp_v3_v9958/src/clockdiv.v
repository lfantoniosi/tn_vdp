/////////////////////////////////////////////////////////////////////////////////////////
// Differential Clock Divider
//
// This clock divider provides a fine grained clock division achieving much better 
// results in dividing source clocks.
//
// It works by integrating the difference (clock skew) over the time and skipping
// cycles everytime the difference is over 1 cycle to keep up with the target clock.
//
// For example: integer dividing 125Mhz by 3.579545 gives us 34 wich provides a clock
// of 3.676470588 Mhz or 2.71% off !
//
// By using this differential clock divider on the same values you can achieve 3.58Mhz
// wich corresponds to 0.01% off !!!!
// 
// Don't forget to add a BUFG to the output clk for a higher fanout of the signal
//
// Author: Felipe Antoniosi
// Date: 2023/07/01
//
/////////////////////////////////////////////////////////////////////////////////////////


module CLOCK_DIV
#(
parameter real CLK_SRC = 125,
parameter real CLK_DIV = 3.579545,
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
