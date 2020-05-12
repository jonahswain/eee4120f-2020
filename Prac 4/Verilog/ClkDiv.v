// EEE4120F (HPES)
// Clock division module
// Author(s): Jonah Swain [SWNJON003]

module ClkDiv #(parameter divisor=100000) (input clk, output reg divclk);
    localparam cnt_width = $clog2(divisor);
    localparam cnt_max = divisor - 2;
    localparam cnt_halfmax = divisor/2;

    reg [cnt_width-1:0]cnt = 0;

    always @(posedge clk)
    begin
        cnt <= (cnt > cnt_max)? 0:cnt+1;
        divclk <= (cnt < cnt_halfmax)? 1'b0:1'b1;
    end
endmodule