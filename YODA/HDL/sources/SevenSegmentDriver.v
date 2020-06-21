// Matrix Multiplication Accelerator (MMA)
// EEE4120F (HPES) 2020 YODA Project
// 7 segment display driver (for 8 7 seg displays on Nexys A7)
// Authors: Jonah Swain [SWNJON003]
`timescale 1ns / 1ps

module SevenSegmentDriver (
    // === INPUTS & OUTPUTS ===
    input clk,                          // Module clock
    input reset,                        // Reset (resets counter to 0)
    input [31:0] hex,                   // Value to display
    output [7:0] segment_drivers,       // Segment anode drivers
    output [7:0] segments               // Segments
);

// === LOCAL PARAMETERS ===
localparam [6:0] OFF = 7'b0000000;      // All off segment state

// === REGISTERS & WIRES ===
wire [7:0] _segments; // Segments
reg [7:0] _segment_drivers; // Segment drivers
assign _segments[0] = 1'b0; // Decimal point always off
wire [6:0] ss1, ss2, ss3, ss4, ss5, ss6, ss7, ss8; // 7 segment encoder outputs
wire slow_clk; // Slow clock (1kHz)

assign _segments[7:1] = // Segments combinational assignment
    (reset) ? OFF :
    (_segment_drivers == 8'h01) ? ss1 :
    (_segment_drivers == 8'h02) ? ss2 :
    (_segment_drivers == 8'h04) ? ss3 :
    (_segment_drivers == 8'h08) ? ss4 :
    (_segment_drivers == 8'h10) ? ss5 :
    (_segment_drivers == 8'h20) ? ss6 :
    (_segment_drivers == 8'h40) ? ss7 :
    (_segment_drivers == 8'h80) ? ss8 :
    OFF;

assign segments = ~_segments; // Segment outputs active low
assign segment_drivers = ~_segment_drivers; // Segment driver outputs active low

// === MODULES ===
// Hexadecimal to 7 segment converters
HexTo7Seg mod_h2ss1 (hex[3:0], ss1);
HexTo7Seg mod_h2ss2 (hex[7:4], ss2);
HexTo7Seg mod_h2ss3 (hex[11:8], ss3);
HexTo7Seg mod_h2ss4 (hex[15:12], ss4);
HexTo7Seg mod_h2ss5 (hex[19:16], ss5);
HexTo7Seg mod_h2ss6 (hex[23:20], ss6);
HexTo7Seg mod_h2ss7 (hex[27:24], ss7);
HexTo7Seg mod_h2ss8 (hex[31:28], ss8);

FixedClockDivider #(.divisor(100000)) mod_clkdiv (clk, slow_clk); // Clock divider module to generate slow_clk

// === BODY/CLOCK DOMAIN ===
always @(posedge slow_clk) begin
    if (reset) begin // Check reset condition
        _segment_drivers <= 8'h01; // Set _segment_drivers default value
    end else begin // No reset
        if (!_segment_drivers) begin // Check if _segment_drivers is uninitialized
            _segment_drivers <= 8'h01; // Set _segment_drivers default value
        end else begin // Standard operation
            _segment_drivers <= {_segment_drivers[6:0], _segment_drivers[7]}; // Rotate segment_drivers
        end
    end
end

endmodule