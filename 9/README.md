# UART Protocol - "Hello World" Transmission

This project implements a UART (Universal Asynchronous Receiver/Transmitter) protocol to transmit the "Hello, World!" message from an FPGA to a computer or other UART-compatible device.

## Project Description

The UART Hello World module provides a complete implementation of the UART communication protocol with the following features:

- 8-bit data, 1 start bit, 1 stop bit, no parity (8N1)
- Configurable baud rate for different communication speeds
- Supports both transmission and reception (though this example focuses on transmitting)
- Clock-independent design adaptable to any FPGA
- Auto-retransmission with configurable interval
- Push-button trigger for manual transmission
- LED indicators for transmission status
- Complete, self-contained design with testbench

## Repository Organization

- `src/` - Contains all VHDL source and testbench files

## Files

- `src/uart_tx.vhd` - UART transmitter implementation
- `src/uart_rx.vhd` - UART receiver implementation
- `src/uart_hello_world.vhd` - Top-level Hello World implementation
- `src/uart_hello_world_tb.vhd` - Comprehensive testbench

## UART Protocol Overview

UART is an asynchronous serial communication protocol used for point-to-point communication between devices. Key characteristics:

1. **Asynchronous**: No shared clock, timing based on predetermined baud rate
2. **Serial**: Data sent one bit at a time
3. **Frame-based**: Each data byte is sent as a frame with start and stop bits
4. **Full-duplex**: Simultaneous bidirectional communication possible

### UART Frame Structure

```
     Start                                      Stop
      Bit         Data Bits (8-bits)            Bit
     +----+----+----+----+----+----+----+----+----+
     | 0  | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | 1  |
     +----+----+----+----+----+----+----+----+----+
      
     Idle state: Line is HIGH (1)
```

- **Start bit**: Always LOW (0) to signal the beginning of a frame
- **Data bits**: 8 bits of data, LSB first (D0 is transmitted first)
- **Stop bit**: Always HIGH (1) to signal the end of a frame
- **Idle state**: Line remains HIGH when no transmission is occurring

## Implementation Details

### UART Transmitter (uart_tx.vhd)

The UART transmitter is designed as a Finite State Machine (FSM) with four states:

1. **IDLE_ST**: Waiting for data to transmit
2. **START_BIT_ST**: Sending the start bit (logic 0)
3. **DATA_BITS_ST**: Sending the 8 data bits, LSB first
4. **STOP_BIT_ST**: Sending the stop bit (logic 1)

The transmitter includes a baud rate generator that calculates the correct timing based on the system clock frequency and desired baud rate.

### UART Receiver (uart_rx.vhd)

The UART receiver is also implemented as an FSM with matching states:

1. **IDLE_ST**: Waiting for start bit (falling edge)
2. **START_BIT_ST**: Verifying the start bit
3. **DATA_BITS_ST**: Receiving 8 data bits, LSB first
4. **STOP_BIT_ST**: Verifying the stop bit

The receiver includes 16x oversampling to ensure robust reception even with slight timing differences between transmitter and receiver.

### Hello World Implementation (uart_hello_world.vhd)

The Hello World top-level module includes:

1. An internal ROM storing the "Hello, World!" message
2. A transmitter FSM that sends each character sequentially
3. Auto-trigger on reset or button press
4. Status LEDs to indicate transmission progress
5. Configurable retransmission interval

## Usage

To use this module in your design:

1. Add the VHDL files to your project
2. Instantiate the `uart_hello_world` module in your top-level design
3. Connect the module's inputs and outputs to your system
4. Configure the generics based on your requirements:
   - `CLK_FREQ_HZ_g` - Your system clock frequency
   - `BAUD_RATE_g` - Desired UART baud rate
   - `TX_INTERVAL_MS_g` - Interval between automatic retransmissions

### Example Instantiation

```vhdl
-- UART Hello World with 100MHz clock, 9600 baud, and 1-second interval
your_uart_instance : uart_hello_world
    generic map (
        CLK_FREQ_HZ_g   => 100_000_000,  -- 100 MHz system clock
        BAUD_RATE_g     => 9600,         -- 9600 baud
        TX_INTERVAL_MS_g => 1000         -- 1-second interval
    )
    port map (
        clk_i           => system_clock,
        reset_n_i       => system_reset_n,
        send_i          => button_press,
        
        tx_o            => uart_tx_pin,
        rx_i            => uart_rx_pin,
        
        busy_led_o      => led_busy,
        done_led_o      => led_done
    );
```

### Physical Connections

To connect your FPGA to a computer or other UART device:

1. **UART-to-USB converter**: Use an FTDI or similar converter if your FPGA board doesn't have built-in USB-UART
2. **Connections**:
   - Connect the FPGA's `tx_o` to the receiver (RX) pin of your UART device
   - Connect the FPGA's `rx_i` to the transmitter (TX) pin of your UART device
   - Connect ground (GND) between devices
3. **Terminal Software**: Use a terminal program like PuTTY, TeraTerm, or the Arduino Serial Monitor with these settings:
   - Baud rate: Same as configured in your design (e.g., 9600)
   - Data bits: 8
   - Stop bits: 1
   - Parity: None
   - Flow control: None

## Testing

The provided testbench (`uart_hello_world_tb.vhd`) verifies:

1. Correct transmission of the "Hello, World!" message
2. Proper UART protocol timing and framing
3. Character-by-character verification
4. Reset and button trigger functionality
5. Status LED behavior

To run the testbench:

1. Include all project files and the testbench in your simulation tool
2. Run the simulation for sufficient time to observe multiple message transmissions
3. Monitor the terminal output for verification results

## Customization

You can easily customize this design:

1. **Different messages**: Modify the `MESSAGE_ROM_c` constant in `uart_hello_world.vhd`
2. **Different baud rates**: Change the `BAUD_RATE_g` generic
3. **Add hardware flow control**: Extend with RTS/CTS signals if needed
4. **Add parity**: Modify the transmitter and receiver FSMs to include parity bit
5. **Add error handling**: Implement more sophisticated error detection and recovery

## Applications

This UART implementation can be used in many applications:

- Debugging FPGA designs via serial console
- Communicating with microcontrollers and embedded systems
- Interfacing with PC software for data logging
- Remote control systems
- Building bridges between different communication protocols
- Educational tool for understanding serial communication

## Further Enhancements

Some possible enhancements to this design include:

1. Adding FIFO buffers for efficient handling of larger data streams
2. Implementing hardware flow control (RTS/CTS)
3. Adding parity for error detection
4. Implementing more robust clock domain crossing
5. Adding automatic baud rate detection
6. Implementing multi-UART controllers for multiple channels
7. Creating a complete communication protocol stack on top of the UART 