// Matrix Multiplication Accelerator (MMA)
// EEE4120F (HPES) 2020 YODA Project
// Clock division modules
// Authors: Jonah Swain [SWNJON003]
`timescale 1ns / 1ps

module ClockDivider #(
    // === PARAMETERS ===
    parameter reg_width = 16            // Divisor register width
) (
    // === INPUTS & OUTPUTS ===
    input clk,                          // Module clock
    input [reg_width-1:0] divisor,      // Clock divisor
    output div_clk                      // Output divided clock
);

// === REGISTERS & WIRES ===
reg [reg_width-1:0] cnt = 0;            // Counter
assign div_clk = (cnt < (divisor - 1)/2) ? 1'b1 : 1'b0; // div_clk combinational assignment

// === BODY/CLOCK DOMAIN ===
always @(posedge clk) begin
    cnt <= (cnt < divisor - 1) ? cnt + 1 : 0; // Increment cnt until divisor - 1, then reset
end

endmodule


module FixedClockDivider #(
    // === PARAMETERS ===
    parameter divisor = 100000          // Divisor (factor to divide clock by)
) (
    // === INPUTS & OUTPUTS ===
    input clk,                          // Module clock
    output div_clk                      // Output divided clock
);

// === LOCAL PARAMETERS ===
localparam cnt_width = $clog2(divisor); // Counter register width

// === REGISTERS & WIRES ===
reg [cnt_width-1:0] cnt = 0;            // Counter register
assign div_clk = (cnt < (divisor - 1)/2) ? 1'b1 : 1'b0; // div_clk combinational assignment

// === BODY/CLOCK DOMAIN ===
always @(posedge clk) begin
    cnt <= (cnt < divisor - 1) ? cnt + 1 : 0; // Increment cnt until divisor - 1, then reset
end

endmodule