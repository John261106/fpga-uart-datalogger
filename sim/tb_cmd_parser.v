`timescale 1ns / 1ps

module tb_cmd_parser;

    reg        clk;
    reg        rst;
    reg        uart_rx_pin;
    wire       uart_tx_pin;
    wire [7:0] leds;

    localparam BIT_PERIOD = 8680; // Bit duration for 115,200 Baud @ 100 MHz (ns)

    // Instantiate Top Level
    top_level uut (
        .clk(clk),
        .rst(rst),
        .uart_rx_pin(uart_rx_pin),
        .uart_tx_pin(uart_tx_pin),
        .leds(leds)
    );

    // 100 MHz Clock Generation (10 ns period)
    always #5 clk = ~clk;

    // Task: Transmit Single Byte over Serial Input
    task send_byte(input [7:0] data);
        integer i;
        begin
            uart_rx_pin = 1'b0; // Start Bit
            #(BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_pin = data[i]; // LSB First
                #(BIT_PERIOD);
            end
            uart_rx_pin = 1'b1; // Stop Bit
            #(BIT_PERIOD);
        end
    endtask

    // Task: Transmit Complete 4-Byte Frame
    task send_frame(input [7:0] op, input [7:0] param);
        begin
            send_byte(8'hAA); // Header
            send_byte(op);   // Opcode
            send_byte(param);// Parameter
            send_byte(8'h55); // Tail
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        uart_rx_pin = 1;

        #100;
        rst = 0;
        #100;

        // Test Case 1: Send Ping Frame (0xAA 0x50 0x00 0x55)
        $display("[SIM] Sending PING command frame...");
        send_frame(8'h50, 8'h00);
        #(BIT_PERIOD * 50);

        // Test Case 2: Send LED Test Frame (0xAA 0x54 0xA5 0x55)
        $display("[SIM] Sending LED TEST command frame (Setting LEDs to 0xA5)...");
        send_frame(8'h54, 8'hA5);
        #(BIT_PERIOD * 50);

        if (leds === 8'hA5)
            $display("[SUCCESS] LEDs successfully updated to 0xA5!");
        else
            $display("[ERROR] Expected 0xA5 on LEDs, got 0x%h", leds);

        $finish;
    end

endmodule