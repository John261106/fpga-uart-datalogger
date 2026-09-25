# FPGA Data Logger & Memory Tester (Spartan-7)

## Development Phases
- [x] Phase 1: Clocking & Basic UART Engine (Custom Baud Generator, 16x Oversampling RX, Self-Timed TX, Hardware Echo Loopback)
- [ ] Phase 2: FSM Command Parser (ASCII Parsing Engine for Read/Write/Trigger Ops)
- [ ] Phase 3: On-Chip BRAM Buffering (Synchronous Dual-Port Storage)
- [ ] Phase 4: Clock Domain Crossing (CDC) (Async FIFOs for Dual-Clock Domains)
- [ ] Phase 5: DDR3 Memory Integration (Xilinx MIG Core Interface)[cite: 5]

---

## Phase 1: Clocking & Custom UART Engine

### Overview
Phase 1 establishes the physical-layer communication infrastructure between the PC and the Spartan-7 FPGA on the Boolean board without using external IP cores. The system receives serial bytes at 115,200 Baud, displays the character's ASCII binary pattern on the 8 onboard LEDs, and echoes the byte back to the serial terminal.

### Hardware Specifications
* Target Board: Boolean FPGA Board (Xilinx Spartan-7 `XC7S50CSGA324-1`)
* System Clock: 100 MHz Onboard Oscillator (Pin `F14`)
* Protocol Format: Standard 8N1 (8 Data Bits, No Parity, 1 Stop Bit) @ 115,200 Baud
* Pin Mappings:
  * `clk` -> Pin `F14` (100 MHz System Clock)
  * `rst` -> Pin `J2` (Active-High Pushbutton `BTN0`)
  * `uart_rx_pin` -> Pin `V12` (FTDI USB-UART RXD)
  * `uart_tx_pin` -> Pin `U11` (FTDI USB-UART TXD)
  * `leds[7:0]` -> Pins `E5`, `E3`, `E2`, `E1`, `F2`, `F1`, `G2`, `G1`

### Module Architecture
1. `uart_baud_gen.v`: Generates a single-cycle pulse (`tick_rx_16x`) every 54 clock cycles ($100\text{ MHz} / (115,200 \times 16)$) to drive 16x oversampling in the receiver.
2. `uart_rx.v`: Uses a 2-stage Flip-Flop input synchronizer to eliminate metastability on `uart_rx_pin`. Samples the RX line in the middle of each bit period (sample tick 7 of 15) and pulses `rx_done` upon receiving a valid byte.
3. `uart_tx.v`: A self-timed 8N1 serializer module. Drives `uart_tx_pin` LOW for the start bit, shifts out 8 data bits (LSB-first), and holds the stop bit HIGH—holding each bit state for exactly 868 clock cycles ($100\text{ MHz} / 115,200$).
4. `top_level.v`: Top-level wrapper interconnecting RX, TX, baud generator, and board LEDs. Latches received bytes to `leds[7:0]` and directly triggers `uart_tx` on `rx_done` for hardware loopback.

---

### Hardware Debugging Case Study: Self-Timed TX vs. Free-Running Tick

During initial physical hardware testing, the onboard LEDs correctly displayed received bytes, but Tera Term printed corrupted/garbage characters.

#### Root Cause (Asynchronous Phase Misalignment)
* The initial design was driven by an external free-running `tick_tx` strobe from `uart_baud_gen` that rolled over every 868 clock cycles continuously in the background.
* When `rx_done` triggered `tx_start`, `uart_tx` entered `STATE_START` and pulled `tx_pin` LOW.
* Because the external `tick_tx` pulse was unsynchronized with `tx_start`, `tick_tx` could fire just 2 or 3 clock cycles ($0.02\,\mu\text{s}$) into the Start Bit instead of a full 868 cycles ($8.68\,\mu\text{s}$).
* This truncated the Start Bit, causing the PC serial terminal to lose frame alignment and sample data bits at wrong time intervals.

#### Solution
* Replaced the free-running `tick_tx` strobe with an internal 16-bit cycle counter (`clk_count`) inside `uart_tx.v`.
* The counter resets to `0` synchronously when `tx_start` goes HIGH, holding every bit period (including the Start Bit) for exactly 868 clock cycles.

---

### Hardware Verification Matrix
| Transmitted Char | ASCII Hex | ASCII Binary (`LED7` -> `LED0`) | Illuminated LEDs |
| :---: | :---: | :---: | :--- |
| `A` | `0x41` | `0100 0001` | LED6, LED0 |
| `B` | `0x42` | `0100 0010` | LED6, LED1 |
| `a` | `0x61` | `0110 0001` | LED6, LED5, LED0 |
| `0` | `0x30` | `0011 0000` | LED5, LED4 |
| Space | `0x20` | `0010 0000` | LED5 |