// Matrix Multiplication Accelerator (MMA)
// EEE4120F (HPES) 2020 YODA Project
// FP multiplier test bench
// Authors: Jonah Swain [SWNJON003]

module TB_FP_MUL ();

// === LOCAL PARAMETERS ===
localparam n_A = 32'h40000000; // 2
localparam n_B = 32'h40400000; // 3

// === REGISTERS & WIRES ===
reg CLK;
reg [31:0] cycle;
reg [31:0] A;
reg A_valid;
reg [31:0] B;
reg B_valid;
wire [31:0] R;
wire R_valid;

// === MODULES ===
FP_MUL fpm (CLK, A_valid, A, B_valid, B, R_valid, R);

// === SETUP ===
initial begin
    $display("cycle, R, R_valid");
    $monitor("%02d, %X, %b", cycle, R, R_valid);

    CLK <= 0;
    A <= n_A;
    B <= n_B;
    A_valid <= 1'b1;
    B_valid <= 1'b1;
    
    repeat (20) begin // Clock generation
    #5 CLK <= ~CLK;
    #5 CLK <= ~CLK;
    cycle <= cycle + 1;
    end
end

endmodule