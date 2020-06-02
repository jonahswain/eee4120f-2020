`timescale 1ns / 1ps

// EEE4120F (HPES)
// Top level module
// Author(s): Jonah Swain [SWNJON003]

module WallClock(
	// Inputs
	input CLK100MHZ,
	input BTNL, BTNR,
	input [7:0] SW,

	// Outputs
	output wire [5:0] LED,
	output wire CA, CB, CC, CD, CE, CF, CG, DP,
	output wire [7:0] AN
);

	parameter sec_div = 5; // Clock division to get seconds

	// Constant registers
	reg __ZERO = 1'b0;
	reg __ONE = 1'b1;

	// CLK100MHZ counter
	localparam cnt_width = $clog2(sec_div);
    localparam cnt_max = sec_div - 2;
	reg [cnt_width-1:0] cnt = 0;

	// 7-segment display wiring
	wire [7:0] SevenSegment;
	assign {DP, CG, CF, CE, CD, CC, CB, CA} = SevenSegment;
	wire [3:0] SegmentDrivers;
	assign AN[3:0] = SegmentDrivers;
	assign AN[7:4] = __ZERO;

	// PWM module
	wire _PWM;
	PWM #(.resolution_bits(8)) PWM_1 (CLK100MHZ, SW, _PWM);

	// Buttons
	wire _BTN_H;
	wire _BTN_M;
	reg _BTN_H_P;
	reg _BTN_M_P;
	Debounce #(.delay_ms(30)) BTN_H (CLK100MHZ, BTNL, _BTN_H);
	Debounce #(.delay_ms(30)) BTN_M (CLK100MHZ, BTNR, _BTN_M);

	// Reset delay module
	reg startup_set;
	reg startup;
	wire _RST;
	Delay_Reset RST (CLK100MHZ, startup, _RST);

	// Time storage registers
	reg [5:0] sec;
	reg [3:0] hr_u;
	reg [3:0] hr_l;
	reg [3:0] min_u;
	reg [3:0] min_l;

	// LEDs
	assign LED = sec;

	// 7-segment display
	SS_Driver SSDisp (CLK100MHZ, _RST, _PWM, hr_u, hr_l, min_u, min_l, SegmentDrivers, SevenSegment);

	// == MAIN LOGIC ==
	always @(posedge CLK100MHZ) begin
		// Start reset delay
		if (~startup_set) begin
			startup_set <= 1'b1;
			startup <= 1'b1;
		end else begin
			startup <= 1'b0;
		end

		if (_RST) begin
			// Reset time on reset
			cnt <= 0;
			sec <= 0;
			min_l <= 0;
			min_u <= 0;
			hr_l <= 0;
			hr_u <= 0;
		end else begin

			cnt <= cnt + 1;
			if (cnt > cnt_max) begin // Counter overflow
				cnt <= 0;

				sec <= sec + 1; // Increment seconds

				if (sec >= 59) begin // Overflow sec, increment min_l
					sec <= 0;
					min_l <= min_l + 1;

					if (min_l >= 9) begin // Overflow min_l, increment min_u
						min_l <= 0;
						min_u <= min_u + 1;

						if (min_u >= 5) begin // Overflow min_u, increment hr_l
							min_u <= 0;
							hr_l <= hr_l + 1;

							if (hr_l >= 9) begin // Overflow hr_l, increment hr_u
								hr_l <= 0;
								hr_u <= hr_u + 1;
							end

							if (hr_u >= 2) begin
								if (hr_l >= 3) begin // Overflow hours
									hr_u <= 0;
									hr_l <= 0;
								end
							end
						end
					end
				end
			end

			if (_BTN_M & ~_BTN_M_P) begin // Minutes button
				min_l <= min_l + 1;

				if (min_l >= 9) begin // Overflow min_l, increment min_u
					min_l <= 0;
					min_u <= min_u + 1;

					if (min_u >= 5) begin // Overflow min_u
						min_u <= 0;
					end
				end
			end

			if (_BTN_H & ~_BTN_H_P) begin // Hours button
				hr_l <= hr_l + 1;

				if (hr_l >= 9) begin // Overflow hr_l, increment hr_u
					hr_l <= 0;
					hr_u <= hr_u + 1;
				end

				if (hr_u >= 2) begin
					if (hr_l >= 3) begin // Overflow hours
						hr_u <= 0;
						hr_l <= 0;
					end
				end
			end

			_BTN_H_P <= _BTN_H;
			_BTN_M_P <= _BTN_M;
		end

	end

endmodule  
