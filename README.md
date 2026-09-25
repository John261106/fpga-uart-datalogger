\# FPGA Data Logger \& Memory Tester (Spartan-7)



\## Development Phases

\- \[x] \*\*Phase 1: Clocking \& Basic UART Engine\*\* (Custom Baud Generator, 16x Oversampling RX, Self-Timed TX, Hardware Echo Loopback)

\- \[ ] \*\*Phase 2: FSM Command Parser\*\* (ASCII Parsing Engine for Read/Write/Trigger Ops)

\- \[ ] \*\*Phase 3: On-Chip BRAM Buffering\*\* (Synchronous Dual-Port Storage)\[cite: 5]

\- \[ ] \*\*Phase 4: Clock Domain Crossing (CDC)\*\* (Async FIFOs for Dual-Clock Domains)\[cite: 5]

\- \[ ] \*\*Phase 5: DDR3 Memory Integration\*\* (Xilinx MIG Core Interface)\[cite: 5]



\---



\## 🚀 Phase 1: Clocking \& Custom UART Engine



\### Overview

Phase 1 establishes the physical-layer communication infrastructure between the PC and the Spartan-7 FPGA on the Boolean board without using external IP cores. The system receives serial bytes at 115,200 Baud, displays the character's ASCII binary pattern on the 8 onboard LEDs, and echoes the byte back to the serial terminal.



\### Hardware Specifications

\* \*\*Target Board:\*\* Boolean FPGA Board (Xilinx Spartan-7 `XC7S50CSGA324-1`)

\* \*\*System Clock:\*\* 100 MHz Onboard Oscillator (Pin `F14`)

\* \*\*Protocol Format:\*\* Standard 8N1 (8 Data Bits, No Parity, 1 Stop Bit) @ \*\*115,200 Baud\*\*

\* \*\*Pin Mappings:\*\*

&#x20; \* `clk` $\\rightarrow$ Pin `F14` (100 MHz System Clock)

&#x20; \* `rst` $\\rightarrow$ Pin `J2` (Active-High Pushbutton `BTN0`)

&#x20; \* `uart\_rx\_pin` $\\rightarrow$ Pin `V12` (FTDI USB-UART RXD)

&#x20; \* `uart\_tx\_pin` $\\rightarrow$ Pin `U11` (FTDI USB-UART TXD)

&#x20; \* `leds\[7:0]` $\\rightarrow$ Pins `E5`, `E3`, `E2`, `E1`, `F2`, `F1`, `G2`, `G1`



\### Module Architecture

1\. \*\*`uart\_baud\_gen.v`\*\*: Generates a 1-clock-cycle pulse (`tick\_rx\_16x`) every 54 clock cycles ($100\\text{ MHz} / (115,200 \\times 16)$) to drive 16x oversampling in the receiver.

2\. \*\*`uart\_rx.v`\*\*: Uses a 2-stage Flip-Flop input synchronizer to eliminate metastability on `uart\_rx\_pin`. Samples the RX line in the middle of each bit period (sample tick 7 of 15) and pulses `rx\_done` upon receiving a valid byte.

3\. \*\*`uart\_tx.v`\*\*: A self-timed 8N1 serializer module. Drives `uart\_tx\_pin` LOW for the start bit, shifts out 8 data bits (LSB-first), and holds the stop bit HIGH—holding each bit state for exactly 868 clock cycles ($100\\text{ MHz} / 115,200$).

4\. \*\*`top\_level.v`\*\*: Top-level wrapper interconnecting RX, TX, baud generator, and board LEDs. Latches received bytes to `leds\[7:0]` and directly triggers `uart\_tx` on `rx\_done` for hardware loopback.



\---



\### Hardware Debugging Case Study: Self-Timed TX vs. Free-Running Tick



During initial physical hardware testing, the onboard LEDs correctly displayed received bytes, but Tera Term printed corrupted/garbage characters.



\#### Root Cause (Asynchronous Phase Misalignment)

\* The initial design driven by an external free-running `tick\_tx` strobe from `uart\_baud\_gen` had a timing flaw: `tick\_tx` rolled over every 868 clock cycles continuously in the background.

\* When `rx\_done` triggered `tx\_start`, `uart\_tx` entered `STATE\_START` and pulled `tx\_pin` LOW.

\* Because the external `tick\_tx` pulse was unsynchronized with `tx\_start`, `tick\_tx` could fire just 2 or 3 clock cycles ($0.02\\,\\mu\\text{s}$) into the Start Bit instead of a full 868 cycles ($8.68\\,\\mu\\text{s}$).

\* This truncated the Start Bit, causing the PC serial terminal to lose frame alignment and sample data bits at wrong time intervals.



\#### Solution

\* Replaced the free-running `tick\_tx` strobe with an \*\*internal 16-bit cycle counter (`clk\_count`)\*\* inside `uart\_tx.v`.

\* The counter resets to `0` synchronously when `tx\_start` goes HIGH, holding every bit period (including the Start Bit) for exactly 868 clock cycles.



\---



\### Hardware Verification Matrix

| Transmitted Char | ASCII Hex | ASCII Binary (`LED7` $\\rightarrow$ `LED0`) | Illuminated LEDs |

| :---: | :---: | :---: | :--- |

| \*\*`A`\*\* | `0x41` | `0100 0001` | \*\*LED6\*\*, \*\*LED0\*\* |

| \*\*`B`\*\* | `0x42` | `0100 0010` | \*\*LED6\*\*, \*\*LED1\*\* |

| \*\*`a`\*\* | `0x61` | `0110 0001` | \*\*LED6\*\*, \*\*LED5\*\*, \*\*LED0\*\* |

| \*\*`0`\*\* | `0x30` | `0011 0000` | \*\*LED5\*\*, \*\*LED4\*\* |

| \*\*`Space`\*\* | `0x20` | `0010 0000` | \*\*LED5\*\* |

