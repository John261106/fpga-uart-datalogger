`timescale 1ns / 1ps

module tb_uart;

    reg        clk;
    reg        rst;
    reg        uart_rx_pin;
    wire       uart_tx_pin;
    wire [7:0] leds;

    // Period for 115,200 baud (1 / 115200 ≈ 8680 ns)
    localparam BIT_PERIOD = 8680;

    // Instantiate Top Level
    top_level uut (
        .clk(clk),
        .rst(rst),
        .uart_rx_pin(uart_rx_pin),
        .uart_tx_pin(uart_tx_pin),
        .leds(leds)
    );

    // 100 MHz Clock Generator (10 ns period)
    always #5 clk = ~clk;

    // Task to send a serial byte over uart_rx_pin
    task send_byte(input [7:0] data);
        integer i;
        begin
            // Start Bit (LOW)
            uart_rx_pin = 1'b0;
            #(BIT_PERIOD);
            
            // 8 Data Bits (LSB First)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_pin = data[i];
                #(BIT_PERIOD);
            end
            
            // Stop Bit (HIGH)
            uart_rx_pin = 1'b1;
            #(BIT_PERIOD);
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        uart_rx_pin = 1;

        #100;
        rst = 0;
        #100;

        // Transmit ASCII 'A' (0x41 = 01000001)
        $display("Sending Byte 0x41 ('A')...");
        send_byte(8'h41);

        #(BIT_PERIOD * 12); // Wait for transmission complete

        if (leds === 8'h41)
            $display("SUCCESS: LED output matches transmitted byte (0x41)!");
        else
            $display("ERROR: Expected 0x41 on LEDs, got 0x%h", leds);

        $finish;
    end

endmodule