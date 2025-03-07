# Button-Controlled LED with Debounce Circuit

This project implements a button-controlled LED circuit with debounce functionality in VHDL. The design is board-agnostic and can be easily adapted for different FPGA boards.

## Project Structure

```
3/
├── src/                                # Source code
│   ├── button_led_debounce.vhd         # Main VHDL implementation
│   └── button_led_debounce_tb.vhd      # Testbench for simulation
└── docs/                               # Documentation
```

## Design Overview

The design consists of three main components:

1. **Button Debounce Circuit**: Eliminates button bounce by using a counter-based approach with synchronization flip-flops to prevent metastability.

2. **Edge Detection**: Detects the rising edge of the debounced button signal to trigger LED pattern changes only once per button press.

3. **LED Control**: Cycles through different LED patterns each time the button is pressed.

## Features

- Configurable debounce time (default: 20ms)
- Configurable number of LEDs (default: 4)
- Adjustable clock frequency to match different boards
- Multiple LED patterns that cycle with each button press
- Active-low reset input
- Board-agnostic design

## LED Patterns

The design cycles through the following LED patterns with each button press:

1. Only first LED on
2. Only second LED on
3. Only third LED on
4. Only fourth LED on
5. All LEDs on
6. All LEDs off
7. Back to pattern 1

## Implementation Details

### Debounce Circuit

The debounce circuit uses a counter-based approach:
- Two-stage synchronization to prevent metastability
- Counter that must reach a threshold before accepting a button state change
- Configurable debounce period based on clock frequency

### Edge Detection

The edge detection circuit:
- Detects rising edges of the debounced button signal
- Ensures each button press is counted only once
- Generates a single-cycle pulse for each detected button press

### LED Control

The LED control circuit:
- Maintains a counter to track the current LED pattern
- Updates the LED pattern based on button presses
- Resets to the initial pattern after cycling through all patterns

## Usage

1. Adjust the generic parameters in the VHDL code if needed:
   - `CLK_FREQ_HZ_g`: Clock frequency of your board
   - `DEBOUNCE_MS_g`: Desired debounce period in milliseconds
   - `NUM_LEDS_g`: Number of LEDs to control
2. Synthesize and implement the design using Vivado or another FPGA development tool.
3. Program your FPGA board with the generated bitstream.
4. Press the button to cycle through LED patterns.

## Simulation

The testbench includes:
- Simulation of button bouncing to test the debounce circuit
- Multiple button presses to cycle through LED patterns
- Reset functionality testing
- Detailed reporting of test stages

To run the simulation:
1. Open the project in Vivado
2. Add the source files and testbench
3. Run the simulation
4. Observe the LED patterns changing with button presses

## Customization

The design can be easily customized by:
- Modifying the generic parameters in the VHDL code
- Changing the LED patterns in the `led_control_proc` process
- Adjusting the debounce threshold for different button characteristics
- Adding more complex LED patterns or behaviors 