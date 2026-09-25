`timescale 1ns / 1ps

module top_level (
    input  wire       clk,          // 100 MHz Onboard Clock (Pin F14)
    input  wire       rst,          // Active-High Reset (Pushbutton BTN0)
    input  wire       uart_rx_pin,  // USB-UART Serial RX Pin (Pin V12)
    output wire       uart_tx_pin,  // USB-UART Serial TX Pin (Pin U11)
    output wire [7:0] leds          // Onboard LEDs (LED7 down to LED0)
);

    // Internal Signal Interconnects
    wire       tick_rx_16x;
    wire [7:0] rx_data_bus;
    wire       rx_done_pulse;

    wire [7:0] tx_data_bus;
    wire       tx_start_pulse;
    wire       tx_busy_wire;

    wire       start_sampling_wire;
    wire       dump_request_wire;

    // 1. Baud Rate Generator (16x Oversampling Clock Strobe)
    uart_baud_gen #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115_200)
    ) baud_inst (
        .clk(clk),
        .rst(rst),
        .tick_rx_16x(tick_rx_16x)
    );

    // 2. UART Receiver Instance
    uart_rx rx_inst (
        .clk(clk),
        .rst(rst),
        .rx_pin(uart_rx_pin),
        .tick_rx_16x(tick_rx_16x),
        .rx_data(rx_data_bus),
        .rx_done(rx_done_pulse)
    );

    // 3. FSM Command Parser Instance
    cmd_parser_fsm parser_inst (
        .clk(clk),
        .rst(rst),
        .rx_data(rx_data_bus),
        .rx_done(rx_done_pulse),
        .tx_busy(tx_busy_wire),
        .tx_data(tx_data_bus),
        .tx_start(tx_start_pulse),
        .leds(leds),
        .start_sampling(start_sampling_wire),
        .dump_request(dump_request_wire)
    );

    // 4. Self-Timed UART Transmitter Instance
    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115_200)
    ) tx_inst (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start_pulse),
        .tx_data(tx_data_bus),
        .tx_pin(uart_tx_pin),
        .tx_busy(tx_busy_wire),
        .tx_done()
    );

endmodule