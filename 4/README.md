# Seven-Segment Display Controller

This project implements a versatile seven-segment display controller in VHDL. The design is board-agnostic and can be easily adapted for different FPGA boards and display types.

## Project Structure

```
4/
├── src/                                    # Source code
│   ├── seven_segment_display.vhd           # Main VHDL implementation
│   └── seven_segment_display_tb.vhd        # Testbench for simulation
└── docs/                                   # Documentation
```

## Design Overview

The design provides a simple and flexible controller for seven-segment displays:

1. **Binary to Seven-Segment Decoder**: Converts 4-bit binary input (0-F) to the appropriate segment pattern.

2. **Display Type Configuration**: Supports both common anode and common cathode displays through a generic parameter.

3. **Synchronous Operation**: Uses a clock input for synchronous updates and includes an active-low reset.

## Features

- Displays hexadecimal digits (0-9, A-F)
- Configurable for common anode or common cathode displays
- Synchronous operation with clock input
- Active-low reset
- Board-agnostic design
- Standard segment mapping:
  ```
      a
     ---
    |   |
   f|   |b
    | g |
     ---
    |   |
   e|   |c
    |   |
     ---
      d
  ```

## Segment Mapping

The segment outputs are mapped as follows:
- `segments_o(0)` = segment a (top)
- `segments_o(1)` = segment b (top right)
- `segments_o(2)` = segment c (bottom right)
- `segments_o(3)` = segment d (bottom)
- `segments_o(4)` = segment e (bottom left)
- `segments_o(5)` = segment f (top left)
- `segments_o(6)` = segment g (middle)

## Implementation Details

### Binary to Seven-Segment Decoder

The decoder uses a lookup table approach:
- Predefined patterns for each hexadecimal digit
- Efficient implementation using a constant array
- Handles invalid inputs by displaying blank

### Display Type Handling

The controller supports both common anode and common cathode displays:
- For common anode displays, segments are active low (segments_o is inverted)
- For common cathode displays, segments are active high (segments_o is not inverted)
- Configuration via the `COMMON_ANODE_g` generic parameter

## Usage

1. Set the `COMMON_ANODE_g` generic parameter based on your display type:
   - `true` for common anode displays (default)
   - `false` for common cathode displays

2. Connect the ports:
   - `clk_i`: Connect to your system clock
   - `reset_n_i`: Connect to your active-low reset signal
   - `digit_i`: Connect to your 4-bit binary input (0-F)
   - `segments_o`: Connect to your seven-segment display segments

3. Synthesize and implement the design using your preferred FPGA development tool.

## Simulation

The testbench includes comprehensive testing of all features:
- Tests all hexadecimal digits (0-F)
- Verifies correct segment patterns for each digit
- Tests both common anode and common cathode configurations
- Includes reset functionality testing
- Provides detailed test reporting

To run the simulation:
1. Open the project in your FPGA development tool
2. Add the source files and testbench
3. Run the simulation
4. Observe the test reports

## Customization

The design can be easily customized by:
- Modifying the segment patterns for different display layouts
- Adding decimal point support
- Implementing multi-digit display control
- Adding display multiplexing for multiple digits
- Implementing brightness control via PWM 