`timescale 1ns / 1ps

module cmd_parser_fsm (
    input  wire       clk,
    input  wire       rst,
    
    // UART Receiver Interface
    input  wire [7:0] rx_data,
    input  wire       rx_done,
    
    // UART Transmitter Interface
    input  wire       tx_busy,
    output reg  [7:0] tx_data,
    output reg        tx_start,
    
    // Control & Status Outputs
    output reg  [7:0] leds,
    output reg        start_sampling,
    output reg        dump_request
);

    // Frame Framing Protocol Constants
    localparam [7:0] FRAME_HDR  = 8'hAA; // Start-of-frame byte
    localparam [7:0] FRAME_TAIL = 8'h55; // End-of-frame byte

    // Supported Command Opcodes
    localparam [7:0] OP_PING    = 8'h50; // 'P' - Ping / Health Check
    localparam [7:0] OP_LED     = 8'h54; // 'T' - Set LED Array
    localparam [7:0] OP_SAMPLE  = 8'h53; // 'S' - Trigger Sampling
    localparam [7:0] OP_DUMP    = 8'h44; // 'D' - Request Memory Dump

    // Response Opcode Status
    localparam [7:0] RSP_ACK    = 8'h41; // 'A' - Acknowledged
    localparam [7:0] RSP_ERR    = 8'h45; // 'E' - Error / Invalid Frame

    // FSM State Definitions
    localparam [2:0] STATE_WAIT_HDR   = 3'b000;
    localparam [2:0] STATE_WAIT_OPCD  = 3'b001;
    localparam [2:0] STATE_WAIT_PARAM = 3'b010;
    localparam [2:0] STATE_WAIT_TAIL  = 3'b011;
    localparam [2:0] STATE_EXECUTE    = 3'b100;
    localparam [2:0] STATE_SEND_RESP  = 3'b101;

    reg [2:0] state;
    reg [7:0] opcode;
    reg [7:0] param;

    // 4-Byte Response Buffer
    reg [7:0] resp_pkt [0:3];
    reg [1:0] resp_byte_idx;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= STATE_WAIT_HDR;
            opcode         <= 8'h00;
            param          <= 8'h00;
            leds           <= 8'h00;
            start_sampling <= 1'b0;
            dump_request   <= 1'b0;
            tx_data        <= 8'h00;
            tx_start       <= 1'b0;
            resp_byte_idx  <= 2'b00;
            resp_pkt[0]    <= 8'h00;
            resp_pkt[1]    <= 8'h00;
            resp_pkt[2]    <= 8'h00;
            resp_pkt[3]    <= 8'h00;
        end else begin
            // Default single-cycle strobe resets
            start_sampling <= 1'b0;
            dump_request   <= 1'b0;
            tx_start       <= 1'b0;

            case (state)
                // Step 1: Synchronize on Frame Header (0xAA)
                STATE_WAIT_HDR: begin
                    if (rx_done && (rx_data == FRAME_HDR)) begin
                        state <= STATE_WAIT_OPCD;
                    end
                end

                // Step 2: Capture Command Opcode Byte
                STATE_WAIT_OPCD: begin
                    if (rx_done) begin
                        opcode <= rx_data;
                        state  <= STATE_WAIT_PARAM;
                    end
                end

                // Step 3: Capture Payload / Parameter Byte
                STATE_WAIT_PARAM: begin
                    if (rx_done) begin
                        param <= rx_data;
                        state <= STATE_WAIT_TAIL;
                    end
                end

                // Step 4: Validate Frame Tail Byte (0x55)
                STATE_WAIT_TAIL: begin
                    if (rx_done) begin
                        if (rx_data == FRAME_TAIL) begin
                            state <= STATE_EXECUTE;
                        end else begin
                            state <= STATE_WAIT_HDR; // Framing error: drop packet
                        end
                    end
                end

                // Step 5: Execute Command Action & Prepare Response Frame
                STATE_EXECUTE: begin
                    resp_pkt[0] <= FRAME_HDR;
                    resp_pkt[3] <= FRAME_TAIL;

                    case (opcode)
                        OP_PING: begin
                            resp_pkt[1] <= RSP_ACK;
                            resp_pkt[2] <= 8'h00;
                        end

                        OP_LED: begin
                            leds        <= param;
                            resp_pkt[1] <= RSP_ACK;
                            resp_pkt[2] <= param;
                        end

                        OP_SAMPLE: begin
                            start_sampling <= 1'b1;
                            resp_pkt[1]    <= OP_SAMPLE;
                            resp_pkt[2]    <= 8'h01;
                        end

                        OP_DUMP: begin
                            dump_request <= 1'b1;
                            resp_pkt[1]  <= OP_DUMP;
                            resp_pkt[2]  <= 8'h01;
                        end

                        default: begin
                            resp_pkt[1] <= RSP_ERR;
                            resp_pkt[2] <= 8'hFF;
                        end
                    endcase

                    resp_byte_idx <= 2'b00;
                    state         <= STATE_SEND_RESP;
                end

                // Step 6: Stream 4-Byte Response Frame over UART TX
                STATE_SEND_RESP: begin
                    if (!tx_busy && !tx_start) begin
                        tx_data  <= resp_pkt[resp_byte_idx];
                        tx_start <= 1'b1;

                        if (resp_byte_idx == 2'd3) begin
                            state <= STATE_WAIT_HDR;
                        end else begin
                            resp_byte_idx <= resp_byte_idx + 1'b1;
                        end
                    end
                end

                default: state <= STATE_WAIT_HDR;
            endcase
        end
    end

endmodule