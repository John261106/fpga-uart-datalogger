`timescale 1ns / 1ps

module top_level (
    input  wire       clk,        // 100 MHz Onboard Clock (Pin N15)
    input  wire       rst,        // Active-High Reset Pushbutton
    input  wire       uart_rx_pin,// Serial Input from USB-UART Bridge
    output wire       uart_tx_pin,// Serial Output to USB-UART Bridge
    output wire [7:0] leds        // Onboard LEDs to display last received byte
);

    // Internal Wires
    wire       tick_tx;
    wire       tick_rx_16x;
    wire [7:0] rx_data_bus;
    wire       rx_done_pulse;

    // Reg to hold character for LED display
    reg [7:0]  led_register;

    // 1. Baud Rate Generator Instance
   // Baud Rate Generator Instance (Only for 16x RX oversampling)
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

    // 3. UART Transmitter Instance (Loopback / Echo Mode)
    // Trigger transmission whenever rx_done fires
    // 3. UART Transmitter Instance
    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115_200)
    ) tx_inst (
        .clk(clk),
        .rst(rst),
        .tx_start(rx_done_pulse),
        .tx_data(rx_data_bus),
        .tx_pin(uart_tx_pin),
        .tx_busy(),
        .tx_done()
    );

    // 4. Register received byte to drive LEDs
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            led_register <= 8'h00;
        end else if (rx_done_pulse) begin
            led_register <= rx_data_bus;
        end
    end

    assign leds = led_register;

endmodule