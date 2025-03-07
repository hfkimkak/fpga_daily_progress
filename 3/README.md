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

3. **LED Control**: Implements various LED patterns and effects that change with each button press.

## Features

- Configurable debounce time (default: 20ms)
- Configurable number of LEDs (default: 4)
- Adjustable effect speed
- Active-low reset input
- Board-agnostic design
- Multiple LED effects:
  * Single LED sequence
  * All LEDs on/off
  * Shift left/right patterns
  * Bounce (ping-pong) effect
  * Random patterns

## LED Effect Modes

The design cycles through the following LED effects with each button press:

1. **Single LED Mode**: One LED moves sequentially through all positions
2. **All LEDs Mode**: All LEDs turn on simultaneously
3. **Shift Right**: LED pattern shifts right continuously
4. **Shift Left**: LED pattern shifts left continuously
5. **Bounce Mode**: LED pattern bounces back and forth (ping-pong effect)
6. **Random Mode**: LEDs display random patterns
7. Back to Single LED Mode

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
- Implements state machine for effect mode selection
- Manages timing for each effect pattern
- Includes random pattern generation
- Handles direction control for bounce effect
- Provides smooth transitions between patterns

## Usage

1. Adjust the generic parameters in the VHDL code if needed:
   - `CLK_FREQ_HZ_g`: Clock frequency of your board
   - `DEBOUNCE_MS_g`: Desired debounce period in milliseconds
   - `NUM_LEDS_g`: Number of LEDs to control
   - `EFFECT_SPEED_MS_g`: Speed of LED effects

2. Synthesize and implement the design using your preferred FPGA development tool.
3. Program your FPGA board with the generated bitstream.
4. Press the button to cycle through LED effects.

## Simulation

The testbench includes comprehensive testing of all features:
- Simulation of button bouncing
- Testing of all LED effect modes
- Reset functionality verification
- Detailed test reporting
- Automated pattern verification

To run the simulation:
1. Open the project in your FPGA development tool
2. Add the source files and testbench
3. Run the simulation
4. Observe the LED patterns and test reports

## Customization

The design can be easily customized by:
- Modifying the generic parameters
- Adding new LED effect patterns
- Adjusting effect timing
- Changing the effect sequence
- Modifying the random pattern generation

## Documentation

Detailed documentation is available in the `docs/` directory:
- Design documentation
- Test results
- Timing diagrams
- Implementation guides 