// Matrix Multiplication Accelerator (MMA)
// EEE4120F (HPES) 2020 YODA Project
// Counter module
// Authors: Jonah Swain [SWNJON003]
`timescale 1ns / 1ps

module Counter #(
    // === PARAMETERS ===
    parameter prescaler = 1,            // Clock prescaler (default = 1)
    parameter output_width = 32         // Count register width (default = 32)
) (
    // === INPUTS & OUTPUTS ===
    input clk,                          // Module clock
    input reset,                        // Reset (resets counter to 0)
    input en,                           // Enable counter
    output [output_width-1:0] count     // Count value
);

// === LOCAL PARAMETERS ===
localparam pcnt_width = $clog2(prescaler);

// === REGISTERS & WIRES ===
reg [pcnt_width:0] pcnt = 0;            // Prescaler counter
reg [output_width-1:0] cnt = 0;         // Count
assign count = cnt;                     // Assign output to cnt

// === BODY/CLOCK DOMAIN ===
always @(posedge clk) begin
    if (reset) begin // Reset condition
        pcnt <= 0;
        cnt <= 0;
    end else begin
        if (en) begin // Count if enabled (en asserted)
            if (pcnt < prescaler - 1) begin
                pcnt <= pcnt + 1; // Increment pcnt if pcnt < prescaler - 1
            end else begin
                pcnt <= 0; // Reset pcnt
                cnt <= cnt + 1; // Increment cnt
            end
        end
    end
end


endmodule