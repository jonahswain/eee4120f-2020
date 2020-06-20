// Matrix Multiplication Accelerator (MMA)
// EEE4120F (HPES) 2020 YODA Project
// MMA Top Level Module (TLM)
// Authors: Jonah Swain [SWNJON003]
`timescale 1ns / 1ps

module MMA (
    // === INPUTS & OUTPUTS ===
    input CLK100MHZ,                            // Main clock (100MHz)
    input UART_TXD_IN,                          // UART RX
    output UART_TXD,                            // UART TX
    output CA, CB, CC, CD, CE, CF, CG, DP,      // 7-segment display cathodes
    output [7:0] AN                             // 7-segment display anodes
);

// === IMPORTANT NOTES ===
// Note on "scratch" registers and calling conventions:
//      There are 6 32-bit general purpose scratch registers (scratch[5:0])
//      scratch[0] primary: caller to callee argument    secondary: callee to caller return
//      scratch[1] primary: callee to caller return    secondary: caller to callee argument
//      scratch[2:3] top level state threads registers - should be preserved by callee states
//      scratch[4:5] general purpose scratch registers for all states - not guaranteed to be preserved by callee
// 
// TODOs:
//      Implement timer/counter to measure multiplication time
//      Implement state/error LEDs
//      Implement counter result on 7-seg displays

// === LOCAL PARAMETERS ===
localparam MAX_SIZE = 128*128; // Maximum size of a matrix
localparam UART_TIMEOUT = 500000; // Maximum time to wait for a UART byte

localparam [7:0]            // UART commands
    UART_RX_A = 8'h01,      // Incoming matrix A
    UART_RX_B = 8'h02,      // Incoming matrix B
    UART_MULTIPLY = 8'h03,  // Perform multiplication
    UART_TX_R = 8'h04,      // Return result
    UART_DONE = 8'h05,      // Multiplication complete
    UART_ACK = 8'h06,       // Acknowledge transmission
    UART_ERR = 8'hAA;       // Assert error

localparam [7:0]                            // MMA States
    ST_RESET = 8'h00,                       // Reset
    ST_IDLE = 8'h01,                        // Idle
    ST_WAIT = 8'h02,                        // Wait
    ST_ERROR = 8'h0F,                       // Error
    ST_RXA = 8'h10,                         // Receive matrix A - initialisation
    ST_RXA_DIM1 = 8'h11,                    // Receive matrix A - dimension 1
    ST_RXA_DIM2 = 8'h12,                    // Receive matrix A - dimension 2
    ST_RXA_DATA = 8'h13,                    // Receive matrix A - data (values)
    ST_RXA_COMPLETE = 8'h14,                // Receive matrix A - complete
    ST_RXB = 8'h20,                         // Receive matrix B - initialisation
    ST_RXB_DIM1 = 8'h21,                    // Receive matrix B - dimension 1
    ST_RXB_DIM2 = 8'h22,                    // Receive matrix B - dimension 1
    ST_RXB_DATA = 8'h23,                    // Receive matrix B - dimension 1
    ST_RXB_COMPLETE = 8'h24,                // Receive matrix B - complete
    ST_MUL = 8'h30,                         // Multiply matrices - initialisation
    ST_MUL_LOADDIMS = 8'h31,                // Multiply matrices - load dimensions
    ST_MUL_VERIFYDIMS = 8'h32,              // Multiply matrices - verify dimensions
    ST_MUL_EL_START = 8'h33,                // Multiply element - initialisation
    ST_MUL_EL_FETCH = 8'h34,                // Multiply element - fetch values
    ST_MUL_EL_FPSET = 8'h35,                // Multiply element - load into FPU
    ST_MUL_EL_FPWAIT = 8'h36,               // Multiply element - wait for FPU
    ST_MUL_EL_FPGET = 8'h37,                // Multiply element - get FPU result
    ST_MUL_EL_WRITE = 8'h38,                // Multiply element - write back result
    ST_MUL_TXCOMPLETE = 8'h39,              // Multiply matrices - transmit completion message
    ST_MUL_COMPLETE = 8'h3A,                // Multiply matrices - complete
    ST_TXR = 8'h40,                         // Transmit result - initialisation
    ST_TXR_DIM1 = 8'h41,                    // Transmit result - dimension 1
    ST_TXR_DIM2 = 8'h42,                    // Transmit result - dimension 2
    ST_TXR_DATA = 8'h43,                    // Transmit result - data (values)
    ST_TXR_COMPLETE = 8'h44,                // Transmit result - complete
    ST_UART_GET4 = 8'h50,                   // UART receive 4 bytes - initialisation
    ST_UART_GET4_RX = 8'h51,                // UART receive 4 bytes - receive data
    ST_UART_PUT4 = 8'h52,                   // UART transmit 4 bytes - initialisation
    ST_UART_PUT4_TX = 8'h53,                // UART transmit 4 bytes - transmit data
    ST_UART_RX_WAIT = 8'h5A,                // UART wait for receive
    ST_UART_RX_TIMEOUT = 8'h5B,             // UART timed-out while waiting
    ST_UART_TX_WAIT = 8'h5C,                // UART wait for transmit
    ST_BRAM_A_WEA = 8'h60,                  // BRAM A assert wea for a cycle
    ST_BRAM_A_WEA_LOW = 8'h61,              // BRAM A deassert wea
    ST_BRAM_B_WEA = 8'h62,                  // BRAM B assert wea for a cycle
    ST_BRAM_B_WEA_LOW = 8'h63,              // BRAM B deassert wea
    ST_BRAM_R_WEA = 8'h64,                  // BRAM R assert wea for a cycle
    ST_BRAM_R_WEA_LOW = 8'h65;              // BRAM R deassert wea


// === REGISTERS & WIRES ===
reg [7:0] state = ST_RESET;                 // Current state
reg [7:0] return_state = ST_RESET;          // State to return to (from generic state)

reg [31:0] scratch[5:0];                    // General purpose scratch registers

reg [15:0] a_m = 0;                         // Matrix A dimension 1
reg [15:0] a_n = 0;                         // Matrix A dimension 2
reg [15:0] a_i = 0;                         // Matrix A dimension 1 position
reg [15:0] a_j = 0;                         // Matrix A dimension 2 position
reg [31:0] a_v = 0;                         // Matrix A element value
reg [15:0] b_m = 0;                         // Matrix B dimension 1
reg [15:0] b_n = 0;                         // Matrix B dimension 2
reg [15:0] b_i = 0;                         // Matrix B dimension 1 position
reg [15:0] b_j = 0;                         // Matrix B dimension 2 position
reg [31:0] b_v = 0;                         // Matrix B element value
reg [15:0] r_m = 0;                         // Matrix R dimension 1
reg [15:0] r_n = 0;                         // Matrix R dimension 2
reg [15:0] r_i = 0;                         // Matrix R dimension 1 position
reg [15:0] r_j = 0;                         // Matrix R dimension 2 position
reg [31:0] r_v = 0;                         // Matrix R element value


reg uart_reset = 0;                         // UART reset signal
reg uart_txd = 0;                           // UART transmit data
wire uart_rxd;                              // UART received data
reg uart_tx_begin = 0;                      // UART begin transmit signal
wire uart_rx_ready;                         // UART received data ready signal
wire uart_rx_busy;                          // UART busy receiving signal
wire uart_rx_error;                         // UART error receiving signal
wire uart_tx_busy;                          // UART busy transmitting signal

reg bram_a_ena = 0;                         // BRAM A read enable signal
reg bram_a_wea = 0;                         // BRAM A write enable signal
reg [16:0] bram_a_addr = 0;                 // BRAM A address
reg [31:0] bram_a_din = 0;                  // BRAM A data in
wire [31:0] bram_a_dout;                    // BRAM A data out

reg bram_b_ena = 0;                         // BRAM B read enable signal
reg bram_b_wea = 0;                         // BRAM B write enable signal
reg [16:0] bram_b_addr = 0;                 // BRAM B address
reg [31:0] bram_b_din = 0;                  // BRAM B data in
wire [31:0] bram_b_dout;                    // BRAM B data out

reg bram_r_ena = 0;                         // BRAM R read enable signal
reg bram_r_wea = 0;                         // BRAM R write enable signal
reg [16:0] bram_r_addr = 0;                 // BRAM R address
reg [31:0] bram_r_din = 0;                  // BRAM R data in
wire [31:0] bram_r_dout;                    // BRAM R data out

reg [31:0] fpu_in_a = 0;                    // FP multiplier/accumulator input A
reg [31:0] fpu_in_b = 0;                    // FP multiplier/accumulator input B
reg [31:0] fpu_in_c = 0;                    // FP multiplier/accumulator input C
reg fpu_valid_a = 0;                        // FP multiplier/accumulator input A valid signal
reg fpu_valid_b = 0;                        // FP multiplier/accumulator input B valid signal
reg fpu_valid_c = 0;                        // FP multiplier/accumulator input C valid signal
wire fpu_r;                                 // FP multiplier/accumulator result
wire fpu_valid_r;                           // FP multiplier/accumulator result valid signal

reg counter_en = 0;                         // Counter enable
reg counter_reset = 0;                      // Counter reset
wire [31:0] counter_value;                  // Counter value (clock cycles)

reg sevenseg_reset = 0;                     // 7 segment display driver reset

// === MODULES ===
UART #(.baud_rate(9600)) mod_uart (CLK100MHZ, uart_reset, UART_TXD_IN, UART_TXD, uart_txd, uart_tx_begin, uart_rxd, uart_rx_ready, uart_tx_busy, uart_rx_busy, uart_rx_error); // UART module
BRAM mod_bram_a (CLK100MHZ, bram_a_ena, bram_a_wea, bram_a_addr, bram_a_din, bram_a_dout); // BRAM module A
BRAM mod_bram_b (CLK100MHZ, bram_b_ena, bram_b_wea, bram_b_addr, bram_b_din, bram_b_dout); // BRAM module B
BRAM mod_bram_r (CLK100MHZ, bram_r_ena, bram_r_wea, bram_r_addr, bram_r_din, bram_r_dout); // BRAM module R
FP_MAC mod_fpu (CLK100MHZ, fpu_valid_a, fpu_in_a, fpu_valid_b, fpu_in_b, fpu_valid_c, fpu_in_c, fpu_valid_r, fpu_r); // FP_MAC module (floating point multiplier/accumulator)
Counter mod_cntr (CLK100MHZ, counter_reset, counter_en, counter_value); // Counter module (counts clock cycles)
SevenSegmentDriver mod_7seg (CLK100MHZ, sevenseg_reset, counter_value, AN[7:0], {CA, CB, CC, CD, CE, CF, CG, DP}); // 7 segment display driver module

// === BODY/CLOCK DOMAIN ===
always @(posedge CLK100MHZ) begin

    // === STATE MACHINE ===
    case (state)
        ST_RESET: begin // Reset
            state <= ST_IDLE; // Change state to IDLE

            // Reset all registers to default values
            scratch[0] <= 0;
            scratch[1] <= 0;
            scratch[2] <= 0;
            scratch[3] <= 0;
            scratch[4] <= 0;
            scratch[5] <= 0;
            a_m <= 0;
            a_n <= 0;
            a_i <= 0;
            a_j <= 0;
            a_v <= 0;
            b_m <= 0;
            b_n <= 0;
            b_i <= 0;
            b_j <= 0;
            b_v <= 0;
            r_m <= 0;
            r_n <= 0;
            r_i <= 0;
            r_j <= 0;
            r_v <= 0;
            uart_reset <= 0;
            uart_txd <= 0;
            uart_tx_begin <= 0;
            bram_a_ena <= 1;
            bram_a_wea <= 0;
            bram_a_addr <= 0;
            bram_a_din <= 0;
            bram_b_ena <= 1;
            bram_b_wea <= 0;
            bram_b_addr <= 0;
            bram_b_din <= 0;
            bram_r_ena <= 1;
            bram_r_wea <= 0;
            bram_r_addr <= 0;
            bram_r_din <= 0;
            fpu_in_a <= 0;
            fpu_in_b <= 0;
            fpu_in_c <= 0;
            fpu_valid_a <= 0;
            fpu_valid_b <= 0;
            fpu_valid_c <= 0;
            counter_en <= 0;
            counter_reset <= 0;
            sevenseg_reset <= 0;
        end

        ST_IDLE: begin // Idle
            // Detect rising edge on uart_rx_ready (wait for new command)
            scratch[4][0] <= uart_rx_ready;
            if (uart_rx_ready && (scratch[4][0] == 1'b0)) begin
                // Rising edge detected - new data available
                case (uart_rxd) // Choose next state depending on received command
                    UART_RX_A: state <= ST_RXA; // Change state to RXA
                    UART_RX_B: state <= ST_RXB; // Change state to RXB
                    UART_MULTIPLY: state <= ST_MUL; // Change state to MUL
                    UART_TX_R: state <= ST_TXR; // Change state to TXR
                endcase
            end
        end

        ST_WAIT: begin // Wait
            if (scratch[0]) begin
                scratch[0] <= scratch[0] - 1; // Decrement scratch[0] until zero
            end else begin
                state <= return_state; // Return to previous state
            end 
        end

        ST_ERROR: begin // Error
            if (~uart_tx_begin) begin // Check if uart_tx_begin not asserted
                if (~uart_tx_busy) begin // Check if UART not busy transmitting
                    uart_txd <= UART_ERR; // Set uart_txd to UART_ERR
                    uart_tx_begin <= 1'b1; // Assert uart_tx_begin (start transmission)
                end
            end else begin
                uart_tx_begin <= 1'b0; // Deassert uart_tx_begin
                return_state <= ST_IDLE; // Set return state to IDLE
                state <= ST_UART_TX_WAIT; // Change state to UART_TX_WAIT (wait while transmitting)
            end
            // TODO: add LEDs
            // TODO: add error codes (maybe)
        end

        ST_RXA: begin // Retrieve matrix A - initialisation
            scratch[2] <= 2; // Set scratch[2] to 2
            scratch[3] <= 0; // Clear scrach[3]
            return_state <= ST_RXA_DIM1; // Set return state to RXA_DIM1
            state <= ST_UART_GET4; // Set state to UART_GET4 (gets 4 bytes from UART)
        end

        ST_RXA_DIM1: begin // Receive matrix A - dimension 1
            bram_a_addr <= 0; // Set BRAM A address to 0
            bram_a_din <= scratch[1]; // Set BRAM A data in to scratch[1] (bytes received from UART)
            a_m <= scratch[1]; // Set matrix A M dimension to scratch[1] (bytes received from UART)
            scratch[0] <= ST_RXA_DIM2; // Set argument to RXA_DIM2
            return_state <= ST_UART_GET4; // Set return state to UART_GET4 (gets 4 bytes from UART)
            state <= ST_BRAM_A_WEA; // Change state to BRAM_A_WEA (write to BRAM A)
        end

        ST_RXA_DIM2: begin // Receive matrix A - dimension 2
            bram_a_addr <= 1; // Set BRAM A address to 1
            bram_a_din <= scratch[1]; // Set BRAM A data in to scratch[1] (bytes received from UART)
            a_n <= scratch[1]; // Set matrix A N dimension to scratch[1] (bytes received from UART)
            scratch[0] <= ST_RXA_DATA; // Set argument to RXA_DATA
            return_state <= ST_UART_GET4; // Set return state to UART_GET4 (gets 4 bytes from UART)
            state <= ST_BRAM_A_WEA; // Change state to BRAM_A_WEA (write to BRAM A)
        end

        ST_RXA_DATA: begin // Receive matrix A - data (values)
            if (scratch[2] <= a_n*a_m+1) begin // Get data until all received
                bram_a_addr <= scratch[2]; // Set BRAM A address to scratch[2] (current address)
                scratch[2] <= scratch[2] + 1; // Increment scratch[2]
                bram_a_din <= scratch[1]; // Set BRAM A data in to scratch[1] (bytes received from UART)
                scratch[0] <= ST_RXA_DATA; // Set argument to RXA_DATA
                return_state <= ST_UART_GET4; // Set return state to UART_GET4 (gets 4 bytes from UART)
                state <= ST_BRAM_A_WEA; // Change state to BRAM_A_WEA (write to BRAM A)
            end else begin // All data received
                uart_txd <= UART_ACK; // Set uart_txd to ACK
                uart_tx_begin <= 1'b1; // Assert uart_tx_begin (start transmit)
                state <= ST_RXA_COMPLETE; // Change state to RXA_COMPLETE
            end
        end

        ST_RXA_COMPLETE: begin // Receive matrix A - complete
            scratch[2] <= 0; // Clear scratch[2]
            scratch[3] <= 0; // Clear scratch[3]
            scratch[4] <= 0; // Clear scratch[4]
            scratch[5] <= 0; // Clear scratch[5]
            uart_tx_begin <= 1'b0; // Deassert uart_tx_begin
            state <= ST_IDLE; // Change state to IDLE
        end

        ST_RXB: begin // Retrieve matrix B - initialisation
            scratch[2] <= 2; // Set scratch[2] to 2
            scratch[3] <= 0; // Clear scrach[3]
            return_state <= ST_RXB_DIM1; // Set return state to RXB_DIM1
            state <= ST_UART_GET4; // Set state to UART_GET4 (gets 4 bytes from UART)
        end

        ST_RXB_DIM1: begin // Receive matrix B - dimension 1
            bram_b_addr <= 0; // Set BRAM B address to 0
            bram_b_din <= scratch[1]; // Set BRAM B data in to scratch[1] (bytes received from UART)
            b_m <= scratch[1]; // Set matrix B M dimension to scratch[1] (bytes received from UART)
            scratch[0] <= ST_RXB_DIM2; // Set argument to RXB_DIM2
            return_state <= ST_UART_GET4; // Set return state to UART_GET4 (gets 4 bytes from UART)
            state <= ST_BRAM_B_WEA; // Change state to BRAM_B_WEA (write to BRAM B)
        end

        ST_RXB_DIM2: begin // Receive matrix B - dimension 2
            bram_b_addr <= 1; // Set BRAM B address to 1
            bram_b_din <= scratch[1]; // Set BRAM B data in to scratch[1] (bytes received from UART)
            b_n <= scratch[1]; // Set matrix B N dimension to scratch[1] (bytes received from UART)
            scratch[0] <= ST_RXB_DATA; // Set argument to RXB_DATA
            return_state <= ST_UART_GET4; // Set return state to UART_GET4 (gets 4 bytes from UART)
            state <= ST_BRAM_B_WEA; // Change state to BRAM_B_WEA (write to BRAM B)
        end

        ST_RXB_DATA: begin // Receive matrix B - data (values)
            if (scratch[2] <= b_n*b_m+1) begin // Get data until all received
                bram_b_addr <= scratch[2]; // Set BRAM B address to scratch[2] (current address)
                scratch[2] <= scratch[2] + 1; // Increment scratch[2]
                bram_b_din <= scratch[1]; // Set BRAM B data in to scratch[1] (bytes received from UART)
                scratch[0] <= ST_RXB_DATA; // Set argument to RXB_DATA
                return_state <= ST_UART_GET4; // Set return state to UART_GET4 (gets 4 bytes from UART)
                state <= ST_BRAM_B_WEA; // Change state to BRAM_B_WEA (write to BRAM B)
            end else begin // All data received
                uart_txd <= UART_ACK; // Set uart_txd to ACK
                uart_tx_begin <= 1'b1; // Assert uart_tx_begin (start transmit)
                state <= ST_RXB_COMPLETE; // Change state to RXB_COMPLETE
            end
        end

        ST_RXB_COMPLETE: begin // Receive matrix B - complete
            scratch[2] <= 0; // Clear scratch[2]
            scratch[3] <= 0; // Clear scratch[3]
            scratch[4] <= 0; // Clear scratch[4]
            scratch[5] <= 0; // Clear scratch[5]
            uart_tx_begin <= 1'b0; // Deassert uart_tx_begin
            state <= ST_IDLE; // Change state to IDLE
        end

        ST_MUL: begin // Multiply matrices - initialisation
            scratch[2] <= 0; // Clear scratch[2]
            scratch[3] <= 0; // Clear scratch[3]
            scratch[4] <= 0; // Clear scratch[4]
            scratch[5] <= 0; // Clear scratch[5]
            a_i <= 0; // Clear a_i
            a_j <= 0; // Clear a_j
            b_i <= 0; // Clear b_i
            b_j <= 0; // Clear b_j
            r_i <= 0; // Clear r_i
            r_j <= 0; // Clear r_j
            counter_reset <= 1'b1; // Reset counter
            state <= ST_MUL_VERIFYDIMS; // Change state to MUL_VERIFYDIMS
        end

        ST_MUL_VERIFYDIMS: begin // Multiply matrices - verify dimensions
            counter_reset <= 1'b0; // Deassert counter_reset
            if (a_n == b_m) begin // Check if dimensions are compatible
                counter_en <= 1'b1; // Enable counter
                r_m <= a_m; // Set matrix R M dimension to matrix A N dimension
                r_n <= b_n; // Set matrix R N dimension to matrix B M dimension
                if (!scratch[3][0]) begin
                    bram_r_addr <= 0; // Set BRAM R address to 0
                    bram_r_din <= a_m; // Set BRAM R data in to m dimension
                    scratch[3][0] <= 1'b1; // Assert scratch[3][0]
                    return_state <= ST_MUL_VERIFYDIMS; // Set return state to MUL_VERIFYDIMS
                    state <= ST_BRAM_R_WEA; // Change state to BRAM_R_WEA (write to BRAM R)
                end else begin
                    bram_r_addr <= 1; // Set BRAM R address to 1
                    bram_r_din <= b_n; // Set BRAM R data in to n dimension
                    scratch[3][0] <= 1'b0; // Deassert scratch[3][0]
                    return_state <= ST_MUL_EL_START; // Set return state to MUL_EL_START
                    state <= ST_BRAM_R_WEA; // Change state to BRAM_R_WEA (write to BRAM R)
                end
            end else begin // Dimensions not compatible
                scratch[0] <= 1; // Set argument to 1 (error 1)
                state <= ST_ERROR; // Set state to error
            end
        end

        ST_MUL_EL_START: begin // Multiply element - initialisation
            if (r_i < r_m) begin // Iterate through rows
                a_i <= r_i; // set A row to R row
                if (r_j < r_n) begin // Iterate through columns
                    if (a_j < a_n) begin // Iterate through elements
                        bram_a_addr <= a_i*a_n + a_j + 2; // Set BRAM A address
                        bram_b_addr <= b_i*b_n + b_j + 2; // Set BRAM B address
                        state <= ST_MUL_EL_FETCH; // Change state to MUL_EL_FETCH (fetch, MAC)
                        a_j <= a_j + 1; // Increment a_j
                        b_i <= b_i + 1; // Increment b_i
                    end else begin
                        state <= ST_MUL_EL_WRITE; // Change state to MUL_EL_WRITE (write result element to BRAM)
                        a_j <= 0; // Reset a_j
                        b_i <= 0; // Reset b_i
                        r_j <= r_j + 1; // Increment r_j
                        b_j <= b_j + 1; // Increment b_j
                    end
                end else begin
                    r_j <= 0; // Reset r_j
                    b_j <= 0; // Reset b_j
                    r_i <= r_i + 1; // Increment r_i
                    a_i <= a_i + 1; // Increment a_i
                end
            end else begin
                state <= ST_MUL_TXCOMPLETE; // Change state to MUL_TXCOMPLETE
                r_i <= 0; // Reset r_i
                a_i <= 0; // Reset a_i
            end
        end

        ST_MUL_EL_FETCH: begin // Multiply element - fetch values
            a_v <= bram_a_dout; // Get a_v
            b_v <= bram_b_dout; // Get b_v
            state <= ST_MUL_EL_FPSET; // Change state to MUL_EL_FPSET
        end

        ST_MUL_EL_FPSET: begin // Multiply element - load into FPU
            fpu_in_a <= a_v; // Set FPU input A to a_v
            fpu_in_b <= b_v; // Set FPU input B to b_v
            fpu_in_c <= r_v; // Set FPU input C to r_v
            fpu_valid_a <= 1'b1; // Assert FPU input A valid
            fpu_valid_b <= 1'b1; // Assert FPU input B valid
            fpu_valid_c <= 1'b1; // Assert FPU input C valid
            state <= ST_MUL_EL_FPWAIT; // Change state to MUL_EL_FPWAIT
        end

        ST_MUL_EL_FPWAIT: begin // Multiply element - wait for FPU
            scratch[0] <= 19; // Set argument to 19
            return_state <= ST_MUL_EL_FPGET; // Set return state to MUL_EL_FPGET
            state <= ST_WAIT; // Change state to WAIT (wait for 19 cycles for FPU)
        end

        ST_MUL_EL_FPGET: begin // Multiply element - get FPU result
            r_v <= fpu_r; // Save fpu_r into r_v
            state <= ST_MUL_EL_START; // Change state to MUL_EL_START
        end

        ST_MUL_EL_WRITE: begin // Multiply element - write back result
            bram_r_addr <= r_i*r_n + r_j + 2; // Set BRAM R address
            bram_r_din <= r_v; // Set BRAM R data in to r_v
            r_v <= 0; // Reset r_v
            return_state <= ST_MUL_EL_START; // Set return state to MUL_EL_START
            state <= ST_BRAM_R_WEA; // Change state to BRAM_R_WEA (write to BRAM)
        end

        ST_MUL_TXCOMPLETE: begin // Multiply matrices - transmit completion message
            if (!uart_tx_busy) begin // Check if UART not busy
                uart_txd <= UART_DONE; // Set uart_txd to UART_DONE
                uart_tx_begin <= 1'b1; // Assert uart_tx_begin (start TX)
                state <= ST_MUL_COMPLETE; // Change state to MUL_COMPLETE
            end // Do nothing (wait) if UART busy
        end

        ST_MUL_COMPLETE: begin // Multiply matrices - complete
            uart_tx_begin <= 1'b0; // Deassert uart_tx_begin
            counter_en <= 1'b0; // Disable counter
            // Reset registers
            scratch[2] <= 0;
            scratch[3] <= 0;
            a_i <= 0;
            a_j <= 0;
            a_v <= 0;
            b_i <= 0;
            b_j <= 0;
            b_v <= 0;
            r_i <= 0;
            r_j <= 0;
            r_v <= 0;
            state <= ST_IDLE; // Change state to IDLE
        end

        ST_TXR: begin // Transmit result - initialisation
            scratch[2] <= 2; // Set scratch[2] to 2
            scratch[3] <= 0; // Clear scratch[3]
            scratch[4] <= 0; // Clear scratch[4]
            scratch[5] <= 0; // Clear scratch[5]
            state <= ST_TXR_DIM1; // Change state to TXR_DIM1
        end

        ST_TXR_DIM1: begin // Transmit result - dimension 1
            scratch[0] <= r_m; // Set argument to matrix R dimension M
            return_state <= ST_TXR_DIM2; // Set return state to TXR_DIM2
            state <= ST_UART_PUT4; // Change state to UART_PUT4 (send 4 bytes over UART)
        end

        ST_TXR_DIM2: begin // Transmit result - dimension 2
            scratch[0] <= r_n; // Set argument to matrix R dimension N
            return_state <= ST_TXR_DATA; // Set return state to TXR_DATA
            bram_r_addr <= scratch[2]; // Set BRAM R address to next data address
            state <= ST_UART_PUT4; // Change state to UART_PUT4 (send 4 bytes over UART)
        end

        ST_TXR_DATA: begin // Transmit result - data (values)
            if (scratch[2] < r_m*r_n + 1) begin // Iterate through data until all sent
                scratch[0] <= bram_r_dout; // Set argument to BRAM R data out (current value)
                scratch[2] <= scratch[2] + 1; // Increment scratch[2]
                bram_r_addr <= scratch[2] + 1; // Set BRAM R address to next data address
                return_state <= ST_TXR_DATA; // Set return state to TXR_DATA (this)
                state <= ST_UART_PUT4; // Change state to UART_PUT4 (send 4 bytes over UART)
            end else begin // Last data to send
                scratch[0] <= bram_r_dout; // Set argument to BRAM R data out (current value)
                return_state <= ST_TXR_COMPLETE; // Set return state to TXR_COMPLETE
                state <= ST_UART_PUT4; // Change state to UART_PUT4 (send 4 bytes over UART)
            end
        end

        ST_TXR_COMPLETE: begin // Transmit result - complete
            scratch[2] <= 0; // Clear scratch[2]
            scratch[3] <= 0; // Clear scratch[3]
            scratch[4] <= 0; // Clear scratch[4]
            scratch[5] <= 0; // Clear scratch[5]
            state <= ST_IDLE; // Change state to IDLE
        end

        ST_UART_GET4: begin // UART receive 4 bytes - initialisation
            scratch[4][7:0] <= return_state; // Save return state
            scratch[4][9:8] <= 0; // Set byte count to 0
            scratch[1] <= 0; // Clear return register
            return_state <= ST_UART_GET4_RX; // Change return state to UART_GET4_RX
            scratch[0] <= UART_TIMEOUT; // Set timeout delay
            state <= ST_UART_RX_WAIT; // Change state to UART_RX_WAIT
        end

        ST_UART_GET4_RX: begin // UART receive 4 bytes - receive data
            case (scratch[4][9:8])
                2'b00: begin
                    scratch[1][31:24] <= uart_rxd; // Save received byte
                    scratch[4][9:8] <= 2'b01; // Increment byte count
                    return_state <= ST_UART_GET4_RX; // Change return state to UART_GET4_RX
                    scratch[0] <= UART_TIMEOUT; // Set timeout delay
                    state <= ST_UART_RX_WAIT; // Change state to UART_RX_WAIT
                end
                2'b01: begin
                    scratch[1][23:16] <= uart_rxd; // Save received byte
                    scratch[4][9:8] <= 2'b10; // Increment byte count
                    return_state <= ST_UART_GET4_RX; // Change return state to UART_GET4_RX
                    scratch[0] <= UART_TIMEOUT; // Set timeout delay
                    state <= ST_UART_RX_WAIT; // Change state to UART_RX_WAIT
                end
                2'b10: begin
                    scratch[1][15:8] <= uart_rxd; // Save received byte
                    scratch[4][9:8] <= 2'b11; // Increment byte count
                    return_state <= ST_UART_GET4_RX; // Change return state to UART_GET4_RX
                    scratch[0] <= UART_TIMEOUT; // Set timeout delay
                    state <= ST_UART_RX_WAIT; // Change state to UART_RX_WAIT
                end
                2'b11: begin
                    scratch[1][7:0] <= uart_rxd; // Save received byte
                    scratch[4][9:8] <= 2'b00; // Reset byte count
                    return_state <= scratch[4][7:0]; // Restore return_state
                    state <= scratch[4][7:0]; // Return to caller state
                end
            endcase
        end

        ST_UART_PUT4: begin // UART transmit 4 bytes - initialisation
            scratch[4][7:0] <= return_state; // Save return state
            scratch[4][9:8] <= 0; // Set byte count to 0
            state <= ST_UART_PUT4_TX; // Change state to UART_PUT4_TX
        end

        ST_UART_PUT4_TX: begin // UART transmit 4 bytes - transmit data
            if (uart_tx_begin) begin // Check if uart_tx_begin is asserted
                if (scratch[4][9:8]) begin // Check if bytes still to be transmitted
                    uart_tx_begin <= 1'b0; // Deassert uart_tx_begin
                    return_state <= ST_UART_PUT4_TX; // Set return state to UART_PUT4_TX (this)
                    state <= ST_UART_TX_WAIT; // Set state to UART_TX_WAIT (wait for TX to complete)
                end else begin // All bytes transmitted
                    uart_tx_begin <= 1'b0; // Deassert uart_tx_begin
                    return_state <= scratch[4][7:0]; // Restore return state
                    state <= ST_UART_TX_WAIT; // Set state to UART_TX_WAIT (wait for TX to complete)
                end
            end else begin // uart_tx_begin not asserted
                case (scratch[4][9:8])
                    2'b00: begin
                        uart_txd <= scratch[0][31:24]; // Set uart_txd to data byte
                        uart_tx_begin <= 1'b1; // Assert uart_tx_begin (start transmission)
                        scratch[4][9:8] <= 2'b01; // Increment byte count
                    end
                    2'b01: begin
                        uart_txd <= scratch[0][23:16]; // Set uart_txd to data byte
                        uart_tx_begin <= 1'b1; // Assert uart_tx_begin (start transmission)
                        scratch[4][9:8] <= 2'b10; // Increment byte count
                    end
                    2'b10: begin
                        uart_txd <= scratch[0][15:8]; // Set uart_txd to data byte
                        uart_tx_begin <= 1'b1; // Assert uart_tx_begin (start transmission)
                        scratch[4][9:8] <= 2'b11; // Increment byte count
                    end
                    2'b11: begin
                        uart_txd <= scratch[0][7:0]; // Set uart_txd to data byte
                        uart_tx_begin <= 1'b1; // Assert uart_tx_begin (start transmission)
                        scratch[4][9:8] <= 2'b00; // Reset byte count
                    end
                endcase
            end
        end

        ST_UART_RX_WAIT: begin // UART wait for receive
            if (scratch[0]) begin
                scratch[0] <= scratch[0] - 1; // Decrement scratch[0] until 0
                scratch[5][31] <= ~uart_rx_ready; // Store previous uart_rx_ready state
                if (uart_rx_ready && scratch[5][31]) begin // Detect uart_rx_ready rising edge
                    state <= return_state; // Return to previous state
                end
            end else begin
                state <= ST_UART_RX_TIMEOUT; // Change state to timeout on timeout
            end
        end

        ST_UART_RX_TIMEOUT: begin // UART timed-out while waiting
            state <= ST_ERROR; // Change state to ERROR
            // TODO
        end

        ST_UART_TX_WAIT: begin // UART wait for transmit
            if (~uart_tx_busy) begin // Check if UART not busy transmitting
                state <= return_state; // Return
            end
        end

        ST_BRAM_A_WEA: begin // BRAM A assert wea for a cycle
            bram_a_wea <= 1'b1; // Assert wea
            state <= ST_BRAM_A_WEA_LOW; // Change state to BRAM_A_WEA_LOW
        end

        ST_BRAM_A_WEA_LOW: begin // BRAM A deassert wea
            bram_a_wea <= 1'b0; // Deassert wea
            return_state <= scratch[0][7:0]; // Set return state
            state <= return_state; // Return
        end

        ST_BRAM_B_WEA: begin // BRAM B assert wea for a cycle
            bram_b_wea <= 1'b1; // Assert wea
            state <= ST_BRAM_B_WEA_LOW; // Change state to BRAM_B_WEA_LOW
        end

        ST_BRAM_B_WEA_LOW: begin // BRAM B deassert wea
            bram_b_wea <= 1'b0; // Deassert wea
            return_state <= scratch[0][7:0]; // Set return state
            state <= return_state; // Return
        end

        ST_BRAM_R_WEA: begin // BRAM R assert wea for a cycle
            bram_r_wea <= 1'b1; // Assert wea
            state <= ST_BRAM_R_WEA_LOW; // Change state to BRAM_R_WEA_LOW
        end

        ST_BRAM_R_WEA_LOW: begin // BRAM R deassert wea
            bram_r_wea <= 1'b0; // Deassert wea
            return_state <= scratch[0][7:0]; // Set return state
            state <= return_state; // Return
        end

    endcase
    
end

endmodule