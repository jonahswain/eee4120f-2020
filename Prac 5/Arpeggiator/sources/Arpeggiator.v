// EEE4120F (HPES)
// Arpeggiator (TLM)
// Author(s): Jonah Swain [SWNJON003]

module Arpeggiator (
// Inputs
input CLK100MHZ,
input BTNC,
input [7:0] SW,
// Outputs
output AUD_SD,
output AUD_PWM,
output [2:0] LED
);

// BRAM
wire ena = 1'b1; // Read enable always on
wire wea = 1'b0; // Write enable always off
reg [7:0] addra = 0; // Read data address
wire [10:0] dina = 0; // Write data blank
wire [10:0] douta; // Read data wire
BRAM_fullsine BRAM1 (CLK100MHZ, ena, wea, addra, dina, douta); // BRAM IP module instantiation

// PWM Audio
assign AUD_SD = 1'b1; // Audio PWM amplifier always on
PWM #(.resolution_bits(11)) audioPWM (CLK100MHZ, douta, AUD_PWM); // PWM module instantiation

// Clock divider for PWM value changing
reg [11:0] sine_clk_div = 1;
wire sin_clk;
ClockDivider #(.reg_width(12)) sineClock (CLK100MHZ, sine_clk_div, sin_clk); // Clock divider module instantiation

// Arpeggiator button
wire btn_arpeg;
Debounce #(.delay_ms(30)) arpeggiatorButton (CLK100MHZ, BTNC, btn_arpeg); // Button debounce module instantiation

// Mode/state variables
reg arpeggiatorMode = 0;
reg [1:0] note;
reg [25:0] note_cnt;
reg [11:0] freq_base = 1;
assign LED[2] = arpeggiatorMode;
assign LED[1:0] = note;

always @(posedge CLK100MHZ) begin // CLK100MHZ clock domain
    freq_base <= 746 + SW[7:0]; // Get base frequency

    if (~arpeggiatorMode) begin // Base frequency mode
        sine_clk_div <= freq_base;
        note <= 0;
        note_cnt <= 0;

    end else begin // Arpeggiator mode
        note_cnt <= (note_cnt >= 50000000)? 0:note_cnt+1;
        note <= (note_cnt >= 50000000)? note+1:note;

        case (note)
        0: begin // Base note
            sine_clk_div <= freq_base;
        end
        1: begin // 1.25x
            sine_clk_div <= freq_base*4/5;
        end
        2: begin // 1.5x
            sine_clk_div <= freq_base*2/3;
        end
        3: begin // 2x
            sine_clk_div <= freq_base*2;
        end
        endcase;

    end
end

always @(posedge sin_clk) begin // sin_clk clock domain (change PWM value)
    addra <= addra + 1; // Increment BRAM address
end

always @(posedge btn_arpeg) begin // Arpeggiator button clock domain (toggle arpeggiator mode)
    arpeggiatorMode <= ~arpeggiatorMode;
end

endmodule