// EEE4120F (HPES)
// Quarter sine wave expander
// Author(s): Jonah Swain [SWNJON003]

module SineExpander (input clk, input [7:0] addr, output reg [10:0] dout);

    reg [5:0] addra;
    wire [1:0] phase = addr[7:6];
    
    wire dina = 0;
    wire wea = 0;
    wire ena = 1;
    wire [10:0] douta;
    BRAM_quartsine bram (clk, ena, wea, addra, dina, douta);

    always @(posedge clk) begin
        case (phase)
            2'b00: begin
                addra <= addr[5:0];
                dout <= douta;
            end
            2'b01: begin
                addra <= 63 - addr[5:0];
                dout <= douta;
            end
            2'b10: begin
                addra <= addr[5:0];
                dout <= 2047 - douta;
            end
            2'b11: begin
                addra <= 63 - addr[5:0];
                dout <= 2047 - douta;
            end
        endcase
    end

endmodule