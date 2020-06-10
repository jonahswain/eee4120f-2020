// Matrix Multiplication Accelerator (MMA)
// EEE4120F (HPES) 2020 YODA Project
// Hexadecimal to 7 segment display comverter
// Authors: Jonah Swain [SWNJON003]
`timescale 1ns / 1ps

module HexTo7Seg (
    // === INPUTS & OUTPUTS ===
    input [3:0] hex,                    // Input (hexadecimal)
    output wire [6:0] sseg              // Output (input represented for 7 segment display)
);

// === LOCAL PARAMETERS ===
localparam [6:0]                        // Hexadecimal characters to 7 segment segments table
    HEX_0 = 7'b1111110,
    HEX_1 = 7'b0110000,
    HEX_2 = 7'b1101101,
    HEX_3 = 7'b1111001,
    HEX_4 = 7'b0110011,
    HEX_5 = 7'b1011011,
    HEX_6 = 7'b1011111,
    HEX_7 = 7'b1110000,
    HEX_8 = 7'b1111111,
    HEX_9 = 7'b1111011,
    HEX_A = 7'b1111101,
    HEX_B = 7'b0011111,
    HEX_C = 7'b1001110,
    HEX_D = 7'b0111101,
    HEX_E = 7'b1001111,
    HEX_F = 7'b1000111;

// === REGISTERS & WIRES ===
assign sseg = // Segment combinational assignment
    (hex == 4'h0) ? HEX_0 :
    (hex == 4'h1) ? HEX_1 :
    (hex == 4'h2) ? HEX_2 :
    (hex == 4'h3) ? HEX_3 :
    (hex == 4'h4) ? HEX_4 :
    (hex == 4'h5) ? HEX_5 :
    (hex == 4'h6) ? HEX_6 :
    (hex == 4'h7) ? HEX_7 :
    (hex == 4'h8) ? HEX_8 :
    (hex == 4'h9) ? HEX_9 :
    (hex == 4'hA) ? HEX_A :
    (hex == 4'hB) ? HEX_B :
    (hex == 4'hC) ? HEX_C :
    (hex == 4'hD) ? HEX_D :
    (hex == 4'hE) ? HEX_E :
    HEX_F;

endmodule