// Matrix Multiplication Accelerator (MMA)
// EEE4120F (HPES) 2020 YODA Project
// MMA Testbench
// Authors: Jonah Swain [SWNJON003]
`timescale 1ns / 1ps

module TB_MMA();

// === LOCAL PARAMETERS ===
localparam [7:0]                            // UART commands
    UART_RX_A = 8'h01,                      // Incoming matrix A
    UART_RX_B = 8'h02,                      // Incoming matrix B
    UART_MULTIPLY = 8'h03,                  // Perform multiplication
    UART_TX_R = 8'h04,                      // Return result
    UART_DONE = 8'h05,                      // Multiplication complete
    UART_ACK = 8'h06,                       // Acknowledge transmission
    UART_ERR = 8'hAA;                       // Assert error

localparam [191:0] matrixA = {         // Matrix A
    32'h00000002, // 2d
    32'h00000002, // 2d
    32'h3f800000, // 1f
    32'h40000000, // 2f
    32'h40400000, // 3f
    32'h40800000  // 4f
};

localparam [191:0] matrixB = {         // Matrix B
    32'h00000002, // 2d
    32'h00000002, // 2d
    32'h40a00000, // 5f
    32'h40c00000, // 6f
    32'h40e00000, // 7f
    32'h41000000  // 8f
};

// === REGISTERS & WIRES ===
reg clk = 0;                                // Global clock

reg [7:0] uart_recv_data;                   // Data received from UART
reg uart_reset = 0;                         // UART reset
wire uart_rx, uart_tx;                      // UART TX, RX lines
reg [7:0] uart_txd = 0;                     // UART TX data
reg uart_tx_begin = 0;                      // UART begin TX signal
wire [7:0] uart_rxd;                        // UART RX data
wire uart_rx_ready;                         // UART RX ready signal
wire uart_tx_busy;                          // UART TX busy signal
wire uart_rx_busy;                          // UART RX busy signal
wire uart_rx_error;                         // UART RX error signal

wire ss_CA, ss_CB, ss_CC, ss_CD, ss_CE, ss_CF, ss_CG, ss_DP; // 7 segment display segments
wire [7:0] ss_AN;                           // 7 segment display anodes

// === MODULES ===
UART #(.baud_rate(9600)) mod_uart (clk, uart_reset, uart_rx, uart_tx, uart_txd, uart_tx_begin, uart_rxd, uart_rx_ready, uart_tx_busy, uart_rx_busy, uart_rx_error); // UART module
MMA mod_mma (clk, uart_tx, uart_rx, ss_CA, ss_CB, ss_CC, ss_CD, ss_CE, ss_CF, ss_CG, ss_DP, ss_AN); // MMA module

// === MODULE DEBUG WIRES ===
wire [7:0] mma_state = mod_mma.state;

// === FUNCTIONS ===
task cycle_clk;
begin
    #5 clk <= ~clk;
    #5 clk <= ~clk;
end
endtask

task uart_send_byte;
begin
    uart_tx_begin <= 1; // Assert uart_tx_begin
    cycle_clk(); // Clock
    uart_tx_begin <= 0; // Deassert uart_tx_begin
    while (uart_tx_busy) begin
        cycle_clk(); // Clock while transmitting
    end
    repeat(10) cycle_clk(); // Give MMA time to process byte
end
endtask

task uart_wait_rx;
reg rx_ready_prev;
begin
    rx_ready_prev <= uart_rx_ready;
    while ((rx_ready_prev == 1) || (uart_rx_ready == 0)) begin
        cycle_clk();
    end
end
endtask

// === SIMULATION SETUP ===
initial begin
    // Assign initial values
    clk <= 0;
    uart_reset <= 0;
    uart_txd <= 0;
    uart_tx_begin <= 0;
    
    $display("uart_rx_ready, uart_rxd");
    $monitor("%h, %h", uart_rx_ready, uart_recv_data);

    // Transmit matrix A
    uart_txd <= UART_RX_A; // Transmit UART_RX_A
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[191:184]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[183:176]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[175:168]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[167:160]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[159:152]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[151:144]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[143:136]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[135:128]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[127:120]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[119:112]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[111:104]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[103:96]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[95:88]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[87:80]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[79:72]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[71:64]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[63:56]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[55:48]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[47:40]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[39:32]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[31:24]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[23:16]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[15:8]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixA[7:0]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    
    uart_wait_rx(); // Wait for ACK

    // Transmit matrix B
    uart_txd <= UART_RX_B; // Transmit UART_RX_B
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[191:184]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[183:176]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[175:168]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[167:160]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[159:152]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[151:144]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[143:136]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[135:128]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[127:120]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[119:112]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[111:104]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[103:96]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[95:88]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[87:80]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[79:72]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[71:64]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[63:56]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[55:48]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[47:40]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[39:32]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[31:24]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[23:16]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[15:8]; // Place byte in uart_txd
    uart_send_byte(); // Send byte
    uart_txd <= matrixB[7:0]; // Place byte in uart_txd
    uart_send_byte(); // Send byte

    uart_wait_rx(); // Wait for ACK

    // Start multiplication
    uart_txd <= UART_MULTIPLY; // Transmit start command
    uart_send_byte();

    //uart_wait_rx(); // Wait for completion
    while (uart_rxd != UART_DONE) cycle_clk(); // Wait for DONE

    // Get result
    uart_txd <= UART_TX_R; // Transmit send command
    uart_send_byte();
    
    while (1) cycle_clk(); // Clock forever
end

always @(posedge uart_rx_ready) begin // Async UART receive data
    uart_recv_data <= uart_rxd;
end

// === BODY/CLOCK DOMAIN ===


endmodule