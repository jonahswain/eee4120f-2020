// Matrix Multiplication Accelerator (MMA)
// EEE4120F (HPES) 2020 YODA Project
// MMA Top Level Module (TLM)
// Authors: Jonah Swain [SWNJON003]
`timescale 1ns / 1ps

module UART #(
    // === PARAMETERS ===
    clk_freq = 100000000,       // Module clock frequency (default 100MHz)
    baud_rate = 9600,           // BAUD rate (default 9600)
    oversampling = 8            // Number of samples per bit (default 8)
) (
    // === INPUTS & OUTPUTS ===
    input clk,                  // Module clock
    input reset,                // Module reset
    input uart_rx,              // UART RX (receive) line
    output reg uart_tx,         // UART TX (transmit) line
    input [7:0] tx_data,        // Data to transmit
    input tx_begin,             // Begin transmission
    output reg [7:0] rx_data,   // Received data
    output reg rx_ready,        // Received data ready
    output wire tx_busy,         // Transmit in progress
    output wire rx_busy,         // Receive in progress
    output reg rx_error         // Error receiving
);

// === LOCAL PARAMETERS ===
localparam baud_time = clk_freq/baud_rate; // Number of clock cycles for single bit
localparam sample_time = baud_time/(oversampling + 2); // Number of clock cycles per sample (plus padding)

localparam [2:0] // RX states
    RXST_IDLE = 3'd0,
    RXST_START_BIT = 3'd1,
    RXST_SAMPLE_BITS = 3'd2,
    RXST_STOP_BIT = 3'd3,
    RXST_PROC_BITS = 3'd4,
    RXST_ERROR = 3'd5,
    RXST_COMPLETE = 3'd6;

localparam [2:0] // TX states
    TXST_IDLE = 3'd0,
    TXST_START_BIT = 3'd1,
    TXST_SEND_BITS = 3'd2,
    TXST_STOP_BIT = 3'd3,
    TXST_COMPLETE = 3'd4,
    TXST_WAIT = 3'd5;

// === REGISTERS & WIRES ===
reg [2:0] rx_state = RXST_IDLE; // Current RX state
reg [2:0] rx_bit = 0; // Current RX bit
reg [$clog2(oversampling+1)-1:0] bit_samples [7:0]; // RX bit samples
reg [$clog2(oversampling)-1:0] bit_sample_number = 0; // RX bit sample number
reg [$clog2(baud_time):0] rx_cnt = 0; // RX counter (guaranteed wide enough for 2 bit times)

reg tx_state = TXST_IDLE; // Current TX state
reg [7:0] tx_data_shadow = 0; // TX data shadow register
reg [2:0] tx_bit = 0; // Current TX bit
reg [$clog2(baud_time):0] tx_cnt = 0; // TX counter (guaranteed wide enough for 2 bit times)

assign rx_busy = (rx_state != RXST_IDLE); // RX busy unless IDLE
assign tx_busy = (tx_state != TXST_IDLE) && (tx_state != TXST_WAIT); // TX busy unless IDLE or WAIT

// === BODY/CLOCK DOMAIN ===
always @(posedge clk) begin
    if (reset) begin
        // === RESET ===
        rx_state <= RXST_IDLE; // Set RX state to IDLE
        rx_bit <= 0; // Reset rx_bit
        // Reset bit_samples
        bit_samples[0] <= 0;
        bit_samples[1] <= 0;
        bit_samples[2] <= 0;
        bit_samples[3] <= 0;
        bit_samples[4] <= 0;
        bit_samples[5] <= 0;
        bit_samples[6] <= 0;
        bit_samples[7] <= 0;
        bit_sample_number <= 0; // Reset bit_sample_number
        rx_cnt <= 0; // Reset rx_cnt
        tx_state <= TXST_IDLE; // Set TX state to IDLE
        tx_data_shadow <= 0; // Reset tx_data_shadow
        tx_bit <= 0; // Reset tx_bit
        tx_cnt <= 0; // Reset tx_cnt
        rx_data <= 0; // Reset rx_data
        rx_ready <= 0; // Reset rx_ready
        rx_error <= 0; // Reset rx_error
        uart_tx <= 1'b1; // Set TX high (idle)

    end else begin // Normal operation
        // === COUNTERS ===
        if (rx_cnt) rx_cnt <= rx_cnt - 1; // Decrement rx_cnt
        if (tx_cnt) tx_cnt <= tx_cnt - 1; // Decrement tx_cnt

        // === RX ===
        case (rx_state)
            RXST_IDLE: begin // Idle
                if (!uart_rx) begin
                    // RX low indicates start of transmission
                    rx_state <= RXST_START_BIT; // Change state to START_BIT
                    // Reset bit_samples
                    bit_samples[0] <= 0;
                    bit_samples[1] <= 0;
                    bit_samples[2] <= 0;
                    bit_samples[3] <= 0;
                    bit_samples[4] <= 0;
                    bit_samples[5] <= 0;
                    bit_samples[6] <= 0;
                    bit_samples[7] <= 0;
                    rx_cnt <= baud_time/2; // Set counter for 1/2 baud delay
                end
            end

            RXST_START_BIT: begin // Start bit
                if (!rx_cnt) begin // Wait for delay
                    if (!uart_rx) begin
                        // Ensure RX is still low (start bit)
                        rx_state <= RXST_SAMPLE_BITS; // Change state to SAMPLE_BITS
                        rx_cnt <= baud_time/2 + sample_time; // Set counter for 1/2 baud + 1 sample delay
                    end else begin
                        // RX is high - invalid transmission
                        rx_state <= RXST_ERROR; // Change state to ERROR
                        rx_cnt <= baud_time*2; // Set counter for 2 baud delay
                    end
                end
            end

            RXST_SAMPLE_BITS: begin // Sample bits
                if (!rx_cnt) begin // Wait for delay
                    bit_samples[tx_bit] <= (uart_rx)? bit_samples[tx_bit]+1:bit_samples[tx_bit]; // Count high samples
                    if (bit_sample_number >= oversampling) begin // Check if all bit samples have been taken
                        // All bit samples taken
                        bit_sample_number <= 0; // Reset bit sample number
                        if (rx_bit == 7) begin
                            // Change state if all bits sampled
                            rx_bit <= 0; // Reset bit number
                            rx_state <= RXST_STOP_BIT; // Change to STOP_BIT
                            rx_cnt <= baud_time/2 + sample_time; // Set counter for 1/2 baud + 1 sample delay
                        end else begin
                            // Move to next bit
                            rx_bit <= rx_bit + 1; // Increment bit number
                            rx_cnt <= sample_time*2; // Set counter for 2 sample time delay
                        end
                    end else begin
                        // Not all bit samples taken
                        bit_sample_number <= bit_sample_number + 1; // Increment bit sample number
                        rx_cnt <= sample_time; // Set counter for 1 sample time delay
                    end
                end
            end

            RXST_STOP_BIT: begin // Stop bit
                if (!rx_cnt) begin // Wait for delay
                    if (uart_rx) begin
                        // Stop bit high - valid transmission
                        rx_state <= RXST_PROC_BITS; // Change state to PROC_BITS
                    end else begin
                        // Stop bit low - invalid transmission
                        rx_state <= RXST_ERROR; // Change state to ERROR
                        rx_cnt <= baud_time*2; // Set counter for 2 baud delay
                    end
                end
            end

            RXST_PROC_BITS: begin // Process bits
                rx_ready <= 1'b0; // Reset rx_ready
                rx_data <= {(bit_samples[rx_bit] > oversampling/2)? 1'b1:1'b0, rx_data[7:1]}; // Process a bit
                if (rx_bit < 7) begin // Check if all bits are processed
                    rx_bit <= rx_bit + 1; // Increment current bit number
                end else begin
                    rx_bit <= 0; // Reset current bit number
                    rx_state <= RXST_COMPLETE; // Change state to COMPLETE
                end
            end

            RXST_ERROR: begin // Error
                rx_ready <= 1'b0; // Reset rx_ready
                rx_error <= (rx_cnt)? 1'b1:1'b0; // Assert rx_error for delay duration
                rx_state <= (rx_cnt)? RXST_ERROR:RXST_IDLE; // Change state to IDLE after delay
            end

            RXST_COMPLETE: begin // Complete
                rx_ready <= 1'b1; // Set rx_ready
                rx_state <= RXST_IDLE; // Change state to IDLE
            end
        endcase

        // === TX ===
        case (tx_state)
        TXST_IDLE: begin // Idle
            uart_tx <= 1'b1; // Set TX high (idle)
            if (tx_begin) begin
                // Start transmit process if tx_begin is set
                tx_data_shadow <= tx_data; // Copy data into shadow register
                tx_state <= TXST_START_BIT; // Change state to START_BIT
                tx_bit <= 0; // Reset TX bit number
            end
        end

        TXST_START_BIT: begin // Start bit
            // Send start bit
            uart_tx <= 1'b0; // Set TX low (start bit)
            tx_cnt <= baud_time; // Set counter for 1 baud delay
            tx_state <= TXST_SEND_BITS; // Change state to SEND_BITS
        end

        TXST_SEND_BITS: begin // Send bits
            if (!tx_cnt) begin // Wait for delay
                uart_tx <= tx_data_shadow[0]; // Set TX to current bit
                tx_data_shadow <= {1'b0, tx_data_shadow[7:1]}; // Shift for next bit
                tx_cnt <= baud_time; // Set counter for 1 baud delay
                if (tx_bit < 7) begin
                    // More data bits to send
                    tx_bit <= tx_bit+1; // Increment tx_bit
                end else begin
                    // No more data bits to send
                    tx_bit <= 0; // Reset tx_bit
                    tx_state <= TXST_STOP_BIT; // Change state to STOP_BIT
                end
            end
        end

        TXST_STOP_BIT: begin // Stop bit
            if (!tx_cnt) begin // Wait for delay
                uart_tx <= 1'b1; // Set TX high (stop bit/idle)
                tx_cnt <= 2*baud_time; // Set counter for 2 baud delay (2 stop bits)
            end
        end

        TXST_COMPLETE: begin // Complete
            if (!tx_cnt) begin // Wait for delay
                tx_state <= TXST_WAIT; // Change state to WAIT
            end
        end

        TXST_WAIT: begin // Wait
            tx_state <= (tx_begin)? TXST_WAIT:TXST_IDLE; // Change state to IDLE if begin is de-asserted (avoid re-transmit)
        end

        endcase
    
    end

end


endmodule