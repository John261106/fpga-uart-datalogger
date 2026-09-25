`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tx_start,      // Pulse high to begin transmission
    input  wire [7:0] tx_data,       // 8-bit byte to transmit
    output reg        tx_pin,        // Serial output line
    output reg        tx_busy,       // High while transmitting frame
    output reg        tx_done        // Pulse high for 1 clock cycle when finished
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // 868 cycles @ 100 MHz

    localparam STATE_IDLE  = 2'b00;
    localparam STATE_START = 2'b01;
    localparam STATE_DATA  = 2'b10;
    localparam STATE_STOP  = 2'b11;

    reg [1:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_count;
    reg [7:0]  shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= STATE_IDLE;
            tx_pin    <= 1'b1; // Idle line state is HIGH
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
            clk_count <= 0;
            bit_count <= 0;
            shift_reg <= 8'h00;
        end else begin
            tx_done <= 1'b0; // Default pulse low

            case (state)
                STATE_IDLE: begin
                    tx_pin    <= 1'b1;
                    tx_busy   <= 1'b0;
                    clk_count <= 0;
                    bit_count <= 0;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tx_busy   <= 1'b1;
                        state     <= STATE_START;
                    end
                end

                STATE_START: begin
                    tx_pin <= 1'b0; // Start bit is LOW
                    if (clk_count == (CLKS_PER_BIT - 1)) begin
                        clk_count <= 0;
                        state     <= STATE_DATA;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STATE_DATA: begin
                    tx_pin <= shift_reg[0]; // Drive LSB
                    if (clk_count == (CLKS_PER_BIT - 1)) begin
                        clk_count <= 0;
                        shift_reg <= shift_reg >> 1;
                        if (bit_count == 7) begin
                            state <= STATE_STOP;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STATE_STOP: begin
                    tx_pin <= 1'b1; // Stop bit is HIGH
                    if (clk_count == (CLKS_PER_BIT - 1)) begin
                        tx_done <= 1'b1;
                        state   <= STATE_IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule