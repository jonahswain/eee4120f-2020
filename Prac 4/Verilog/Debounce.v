// EEE4120F (HPES)
// Button debounce module
// Author(s): Jonah Swain [SWNJON003]

module Debounce #(parameter delay_ms=25) (input clk, input btn, output debounce_btn);
    localparam delay_clk_div = delay_ms * 100000;

    reg state;
    reg prev_state;
    wire debounce_clk;
    assign debounce_btn = state & prev_state;

    ClkDiv #(.divisor(delay_clk_div)) ckd (clk, debounce_clk);

    always @(posedge debounce_clk)
    begin
        state <= btn;
        prev_state <= state;
    end

endmodule