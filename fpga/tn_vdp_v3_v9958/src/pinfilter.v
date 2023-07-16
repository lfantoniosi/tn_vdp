module PINFILTER(
    input clk,
    input reset_n,
    input din,
    output dout
);

    reg [1:0] dpipe;
    reg d;
    wire d_com;

    always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
            d <= 1'bz;
            dpipe <= 2'bzz;
        end else begin
            dpipe[1] = dpipe[0];
            dpipe[0] = din;
            d = d_com;
        end
    end

    assign d_com = (dpipe == 2'b00) ? 1'b0 : (dpipe == 2'b11) ? 1'b1 : 1'bz;
    assign dout = d;

endmodule
