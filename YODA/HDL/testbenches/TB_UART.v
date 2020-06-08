// Matrix Multiplication Accelerator (MMA)
// EEE4120F (HPES) 2020 YODA Project
// UART test bench
// Authors: Jonah Swain [SWNJON003]

module TB_UART ();

// === LOCAL PARAMETERS ===


// === REGISTERS & WIRES ===
reg CLK;

reg reset = 0;
wire trx;
reg [7:0] txd;
wire [7:0] rxd;
reg tx_begin;
wire rx_ready;
wire rx_busy;
wire rx_error;
wire tx_busy;

// === MODULES ===
UART uart (CLK, reset, trx, trx, txd, tx_begin, rxd, rx_ready, tx_busy, rx_busy, rx_error);

// === SETUP ===
initial begin
    CLK <= 0;

    reset <= 0;
    uart.rx_data <= 0;

    txd <= 8'hea; // Fill tx data
    tx_begin <= 1'b1; // Assert tx_begin
end

always begin
    #5 CLK <= ~CLK; // Generate clock
end

endmodule