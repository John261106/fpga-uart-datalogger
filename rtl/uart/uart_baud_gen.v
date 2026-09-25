`timescale 1ns / 1ps

module uart_baud_gen #(
    parameter CLK_FREQ  = 100_000_000, // 100 MHz input clock
    parameter BAUD_RATE = 115_200      // Target Baud Rate
)(
    input  wire clk,
    input  wire rst,
    output reg  tick_rx_16x            // 16x Baud oversampling tick (54 cycles)
);

    // 100,000,000 / (115,200 * 16) = 54 clock cycles
    localparam integer DIV_RX = CLK_FREQ / (BAUD_RATE * 16);

    reg [15:0] count_rx;

    // RX 16x Oversampling Baud Tick Generation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count_rx    <= 0;
            tick_rx_16x <= 1'b0;
        end else begin
            if (count_rx == (DIV_RX - 1)) begin
                count_rx    <= 0;
                tick_rx_16x <= 1'b1;
            end else begin
                count_rx    <= count_rx + 1'b1;
                tick_rx_16x <= 1'b0;
            end
        end
    end

endmodule