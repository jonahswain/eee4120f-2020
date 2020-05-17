// EEE4120F (HPES)
// Edge detector module
// Author(s): Jonah Swain [SWNJON003]

module RisingEdgeDetector (input clk, input detect, input reset, output reg out);

    reg input_state;
    reg prev_input_state;

    always @(posedge clk) begin
        input_state <= detect;
        prev_input_state <= input_state;

        if (input_state & ~prev_input_state) begin
            out <= 1'b1;
        end

        if (reset) begin
            out <= 1'b0;
        end
    end

endmodule