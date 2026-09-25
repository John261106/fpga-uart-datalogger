`timescale 1ns / 1ps

module uart_rx (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx_pin,        // Async physical serial input pin
    input  wire       tick_rx_16x,   // 16x oversampling tick
    output reg  [7:0] rx_data,       // Received 8-bit byte
    output reg        rx_done        // Pulse high for 1 clock cycle on completion
);

    // State definitions
    localparam STATE_IDLE  = 2'b00;
    localparam STATE_START = 2'b01;
    localparam STATE_DATA  = 2'b10;
    localparam STATE_STOP  = 2'b11;

    reg [1:0] state;
    reg [3:0] sample_count; // Counts 0 to 15 (16x oversampling)
    reg [2:0] bit_count;    // Counts 0 to 7 (8 data bits)
    reg [7:0] shift_reg;

    // 2-Stage Flip-Flop Input Synchronizer for Metastability Prevention
    reg sync_0, sync_1;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync_0 <= 1'b1;
            sync_1 <= 1'b1;
        end else begin
            sync_0 <= rx_pin;
            sync_1 <= sync_0;
        end
    end

    // UART RX State Machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= STATE_IDLE;
            sample_count <= 0;
            bit_count    <= 0;
            shift_reg    <= 8'h00;
            rx_data      <= 8'h00;
            rx_done      <= 1'b0;
        end else begin
            rx_done <= 1'b0; // Default pulse low

            case (state)
                STATE_IDLE: begin
                    sample_count <= 0;
                    bit_count    <= 0;
                    // Detect Start Bit (Falling Edge: High to Low)
                    if (~sync_1) begin
                        state <= STATE_START;
                    end
                end

                STATE_START: begin
                    if (tick_rx_16x) begin
                        // Wait until the middle of the Start Bit (sample count 7)
                        if (sample_count == 7) begin
                            if (~sync_1) begin // Verify Start Bit is still LOW
                                sample_count <= 0;
                                state        <= STATE_DATA;
                            end else begin
                                state        <= STATE_IDLE; // False start glitch
                            end
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end

                STATE_DATA: begin
                    if (tick_rx_16x) begin
                        if (sample_count == 15) begin
                            sample_count <= 0;
                            shift_reg    <= {sync_1, shift_reg[7:1]}; // LSB First

                            if (bit_count == 7) begin
                                state <= STATE_STOP;
                            end else begin
                                bit_count <= bit_count + 1'b1;
                            end
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end

                STATE_STOP: begin
                    if (tick_rx_16x) begin
                        if (sample_count == 15) begin
                            state   <= STATE_IDLE;
                            rx_data <= shift_reg;
                            rx_done <= 1'b1; // Output byte ready
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule