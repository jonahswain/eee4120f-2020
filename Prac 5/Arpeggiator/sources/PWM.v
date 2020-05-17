// EEE4120F (HPES)
// PWM module
// Author(s): Jonah Swain [SWNJON003]

module PWM #(parameter resolution_bits=8) (input clk, input [resolution_bits-1:0] pwm_in, output reg pwm_out);
    reg [resolution_bits-1:0] cntr = 0;
    reg [resolution_bits-1:0] pwmr = 0;

    always @(posedge clk) begin
        pwmr <= pwm_in;
        cntr <= cntr + 1;
        pwm_out <= (pwmr > cntr)? 1'b1:1'b0;
    end
endmodule