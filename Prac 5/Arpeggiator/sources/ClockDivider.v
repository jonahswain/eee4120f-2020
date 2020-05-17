// EEE4120F (HPES)
// Clock division module
// Author(s): Jonah Swain [SWNJON003]

module ClockDivider #(parameter reg_width=16) (input clk, input [reg_width-1:0] divisor, output reg clkd);

    reg [reg_width-1:0] cnt = 0; // Counter

    always @(posedge clk) begin
        cnt <= (cnt >= divisor-1)? 0:cnt+1; // Increment or overflow counter
        clkd <= (cnt > divisor/2)? 1'b0:1'b1; // Set output clock depending on counter
    end
endmodule

module FixedClockDivider #(parameter divisor=100000) (input clk, output reg divclk);
    localparam cnt_width = $clog2(divisor); // Counter register width
    localparam cnt_max = divisor - 2; // Counter maximum value
    localparam cnt_halfmax = cnt_max/2; // Counter halfway

    reg [cnt_width-1:0]cnt = 0; // Counter

    always @(posedge clk)
    begin
        cnt <= (cnt > cnt_max)? 0:cnt+1;
        divclk <= (cnt < cnt_halfmax)? 1'b0:1'b1;
    end
endmodule