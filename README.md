# FPGA Data Logger & Memory Tester (Spartan-7)

## Development Phases
- [x] Phase 1: Clocking & Basic UART Engine (Custom Baud Generator, 16x Oversampling RX, Self-Timed TX, Hardware Echo Loopback)[cite: 1]
- [x] Phase 2: FSM Command Parser Engine (4-Byte Packet Protocol, LED Control, Hardware Strobes & Verification)[cite: 1]
- [ ] Phase 3: On-Chip BRAM Buffering (Synchronous Dual-Port Storage)[cite: 1]
- [ ] Phase 4: Clock Domain Crossing (CDC) (Async FIFOs for Dual-Clock Domains)[cite: 1]
- [ ] Phase 5: DDR3 Memory Integration (Xilinx MIG Core Interface)[cite: 1]

---

## Phase 1: Clocking & Custom UART Engine

### Overview
Phase 1 establishes the physical-layer communication infrastructure between the PC and the Spartan-7 FPGA on the Boolean board without using external IP cores[cite: 1]. The system receives serial bytes at 115,200 Baud, displays the character's ASCII binary pattern on the 8 onboard LEDs, and echoes the byte back to the serial terminal[cite: 1].

### Hardware Specifications
* Target Board: Boolean FPGA Board (Xilinx Spartan-7 `XC7S50CSGA324-1`)[cite: 1]
* System Clock: 100 MHz Onboard Oscillator (Pin `F14`)[cite: 1]
* Protocol Format: Standard 8N1 (8 Data Bits, No Parity, 1 Stop Bit) @ 115,200 Baud[cite: 1]
* Pin Mappings:
  * `clk` -> Pin `F14` (100 MHz System Clock)[cite: 1]
  * `rst` -> Pin `J2` (Active-High Pushbutton `BTN0`)[cite: 1]
  * `uart_rx_pin` -> Pin `V12` (FTDI USB-UART RXD)[cite: 1]
  * `uart_tx_pin` -> Pin `U11` (FTDI USB-UART TXD)[cite: 1]
  * `leds[7:0]` -> Pins `E5`, `E3`, `E2`, `E1`, `F2`, `F1`, `G2`, `G1`[cite: 1]

### Module Architecture
1. `uart_baud_gen.v`: Generates a single-cycle pulse (`tick_rx_16x`) every 54 clock cycles ($100\text{ MHz} / (115,200 \times 16)$) to drive 16x oversampling in the receiver[cite: 1].
2. `uart_rx.v`: Uses a 2-stage Flip-Flop input synchronizer to eliminate metastability on `uart_rx_pin`. Samples the RX line in the middle of each bit period (sample tick 7 of 15) and pulses `rx_done` upon receiving a valid byte[cite: 1].
3. `uart_tx.v`: A self-timed 8N1 serializer module. Drives `uart_tx_pin` LOW for the start bit, shifts out 8 data bits (LSB-first), and holds the stop bit HIGH—holding each bit state for exactly 868 clock cycles ($100\text{ MHz} / 115,200$)[cite: 1].
4. `top_level.v`: Top-level wrapper interconnecting RX, TX, baud generator, and board LEDs. Latches received bytes to `leds[7:0]` and directly triggers `uart_tx` on `rx_done` for hardware loopback[cite: 1].

---

## Phase 2: FSM Command Parser Engine

### Overview
Phase 2 transitions the system from simple character loopback into an FSM Command Parser[cite: 1]. The FPGA decodes fixed 4-byte command packets from the host PC over UART, executes control actions (driving onboard LEDs, pulsing sampling/dump strobes), and transmits formatted 4-byte response frames back to the host[cite: 1].

### Command Protocol Framing
Packets require a strict 4-byte sequence framed by header `0xAA` and tail `0x55`[cite: 1]:

| Byte Index | Field | Description | Supported Opcodes / Values |
| :---: | :--- | :--- | :--- |
| **0** | **Header** | Synchronization Byte | `0xAA`[cite: 1] |
| **1** | **Opcode** | Command Instruction | `0x50` (PING), `0x54` (LED Test), `0x53` (Sample), `0x44` (Dump)[cite: 1] |
| **2** | **Payload** | Data Parameter | e.g., LED mask byte or sample enable flag[cite: 1] |
| **3** | **Tail** | End-of-Frame Marker | `0x55`[cite: 1] |

### FSM State Architecture (`cmd_parser_fsm.v`)
1. `STATE_WAIT_HDR`: Synchronizes on `0xAA` header byte[cite: 1].
2. `STATE_WAIT_OPCD`: Captures command opcode byte[cite: 1].
3. `STATE_WAIT_PARAM`: Captures parameter payload byte[cite: 1].
4. `STATE_WAIT_TAIL`: Validates `0x55` tail byte; drops corrupted frames if invalid[cite: 1].
5. `STATE_EXECUTE`: Asserts single-cycle control strobes (`start_sampling`, `dump_request`) or updates `leds[7:0]` register[cite: 1].
6. `STATE_SEND_RESP`: Sequentially transmits a 4-byte response packet back to host via `uart_tx`[cite: 1].

---

### Hardware Verification Terminal Log

Below is the execution output from the Python test suite (`scripts/test_parser.py`) verifying physical hardware command handling on the Spartan-7 board[cite: 1]:

```text
==========================================================
         PHASE 2 FSM COMMAND PARSER TEST BENCH
==========================================================

[Test 1] Sending PING Command (Opcode: 0x50)...
  TX Packet : [ 0xAA 0x50 0x00 0x55 ]
  RX Packet : [ 0xAA 0x41 0x00 0x55 ]
  Result    : PASS - Received Valid ACK Frame

[Test 2] Setting Board LEDs to 0x3C (LED5..LED2 ON)...
  TX Packet : [ 0xAA 0x54 0x3C 0x55 ]
  RX Packet : [ 0xAA 0x41 0x3C 0x55 ]
  Result    : PASS - Board LEDs Updated to 0x3C

[Test 3] Sending START SAMPLING Trigger (Opcode: 0x53)...
  TX Packet : [ 0xAA 0x53 0x01 0x55 ]
  RX Packet : [ 0xAA 0x53 0x01 0x55 ]
  Result    : PASS - Sampling Trigger Asserted

[Test 4] Sending DUMP DATA Trigger (Opcode: 0x44)...
  TX Packet : [ 0xAA 0x44 0x01 0x55 ]
  RX Packet : [ 0xAA 0x44 0x01 0x55 ]
  Result    : PASS - Dump Request Asserted

[Test 5] Sending Corrupted Frame (Invalid Tail: 0xFF)...
  TX Packet : [ 0xAA 0x50 0x00 0xFF ]
  RX Packet : [  ]
  Result    : PASS - Corrupted Frame Properly Ignored (Timeout)

==========================================================
 Testing Completed.
==========================================================