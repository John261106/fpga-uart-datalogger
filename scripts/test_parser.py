import serial
import serial.tools.list_ports
import time

# Frame Framing Protocol Constants
FRAME_HDR  = 0xAA
FRAME_TAIL = 0x55

# Command Opcodes
OP_PING    = 0x50  # 'P' - Health Check
OP_LED     = 0x54  # 'T' - Set LED Pattern
OP_SAMPLE  = 0x53  # 'S' - Trigger Sampling
OP_DUMP    = 0x44  # 'D' - Request Data Dump

def find_com_port():
    """Detects available COM ports and prompts user selection."""
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("[-] Error: No COM ports detected. Ensure Boolean board is connected and powered ON.")
        return None
    
    print("\nDetected COM Ports:")
    for i, p in enumerate(ports):
        print(f"  [{i}] {p.device} - {p.description}")
    
    if len(ports) == 1:
        print(f"[+] Auto-selected {ports[0].device}")
        return ports[0].device
        
    idx = int(input("Select COM port index: "))
    return ports[idx].device

def send_command(ser, opcode, param=0x00):
    """Formats and transmits a 4-byte command frame, then reads the 4-byte response frame."""
    tx_frame = bytes([FRAME_HDR, opcode, param, FRAME_TAIL])
    ser.write(tx_frame)
    
    # Read returning 4-byte response frame from FPGA
    rx_frame = ser.read(4)
    return tx_frame, rx_frame

def format_hex(data_bytes):
    """Formats bytes array into readable hex string."""
    return " ".join([f"0x{b:02X}" for b in data_bytes])

def main():
    port_name = find_com_port()
    if not port_name:
        return

    # Open Serial Connection @ 115,200 Baud matching Phase 2 hardware configuration
    try:
        ser = serial.Serial(port_name, baudrate=115200, timeout=1.0)
        time.sleep(0.5) # Let connection settle
        print(f"[+] Connected to {port_name} at 115,200 Baud.\n")
    except Exception as e:
        print(f"[-] Connection failed: {e}")
        return

    print("==========================================================")
    print("         PHASE 2 FSM COMMAND PARSER TEST BENCH            ")
    print("==========================================================")

    # Test 1: PING Command (0x50)
    print("\n[Test 1] Sending PING Command (Opcode: 0x50)...")
    tx, rx = send_command(ser, OP_PING, 0x00)
    print(f"  TX Packet : [ {format_hex(tx)} ]")
    print(f"  RX Packet : [ {format_hex(rx)} ]")
    if len(rx) == 4 and rx[1] == 0x41: # 0x41 = ASCII 'A' (ACK)
        print("  Result    : PASS - Received Valid ACK Frame")
    else:
        print("  Result    : FAIL - Invalid Response")

    # Test 2: LED Control Test (0x54, Param: 0x3C / 0b00111100)
    print("\n[Test 2] Setting Board LEDs to 0x3C (LED5..LED2 ON)...")
    tx, rx = send_command(ser, OP_LED, 0x3C)
    print(f"  TX Packet : [ {format_hex(tx)} ]")
    print(f"  RX Packet : [ {format_hex(rx)} ]")
    if len(rx) == 4 and rx[2] == 0x3C:
        print("  Result    : PASS - Board LEDs Updated to 0x3C")
    else:
        print("  Result    : FAIL - LED State Mismatch")

    # Test 3: START SAMPLING Command (0x53)
    print("\n[Test 3] Sending START SAMPLING Trigger (Opcode: 0x53)...")
    tx, rx = send_command(ser, OP_SAMPLE, 0x01)
    print(f"  TX Packet : [ {format_hex(tx)} ]")
    print(f"  RX Packet : [ {format_hex(rx)} ]")
    if len(rx) == 4 and rx[1] == OP_SAMPLE:
        print("  Result    : PASS - Sampling Trigger Asserted")
    else:
        print("  Result    : FAIL - Invalid Response")

    # Test 4: DUMP DATA Command (0x44)
    print("\n[Test 4] Sending DUMP DATA Trigger (Opcode: 0x44)...")
    tx, rx = send_command(ser, OP_DUMP, 0x01)
    print(f"  TX Packet : [ {format_hex(tx)} ]")
    print(f"  RX Packet : [ {format_hex(rx)} ]")
    if len(rx) == 4 and rx[1] == OP_DUMP:
        print("  Result    : PASS - Dump Request Asserted")
    else:
        print("  Result    : FAIL - Invalid Response")

    # Test 5: Invalid Frame / Error Handling Test (Invalid Tail 0xFF)
    print("\n[Test 5] Sending Corrupted Frame (Invalid Tail: 0xFF)...")
    corrupt_frame = bytes([FRAME_HDR, OP_PING, 0x00, 0xFF])
    ser.write(corrupt_frame)
    rx = ser.read(4)
    print(f"  TX Packet : [ {format_hex(corrupt_frame)} ]")
    print(f"  RX Packet : [ {format_hex(rx)} ]")
    if len(rx) == 0:
        print("  Result    : PASS - Corrupted Frame Properly Ignored (Timeout)")
    else:
        print("  Result    : FAIL - Unhandled Frame Error")

    print("\n==========================================================")
    print(" Testing Completed.")
    print("==========================================================")
    ser.close()

if __name__ == "__main__":
    main()