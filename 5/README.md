# FPGA Learning Path - PWM LED Brightness Control

This repository contains VHDL code implementing a PWM (Pulse Width Modulation) LED brightness controller for FPGAs. This project is part of a comprehensive FPGA learning roadmap structured as a 7-sprint progression.

## Project Description

The PWM LED Controller module provides a flexible solution for controlling LED brightness using pulse width modulation. The module features:

- Configurable PWM frequency
- Adjustable duty cycle for precise brightness control
- Parameterized resolution (8-bit by default, giving 256 brightness levels)
- Clean, well-documented code following consistent style guidelines
- Testbench for verification

## Repository Organization

- `src/` - Contains all VHDL source and testbench files
- `vhdl_style/` - VHDL style guide and linting rules

## Files

- `src/pwm_led_controller.vhd` - Main PWM controller implementation
- `src/pwm_led_controller_tb.vhd` - Testbench for verification
- `vhdl_style/vhdl_style_rules.md` - VHDL coding style guidelines

## Implementation Details

The PWM LED controller works by generating a square wave at a specified frequency, where the duty cycle (the percentage of time the signal is high) determines the perceived brightness of the LED. The implementation uses:

1. A counter that counts from 0 to the specified PWM period
2. A comparator that compares the counter value to a threshold derived from the input duty cycle
3. Logic that sets the output high when the counter is below the threshold and low otherwise

This creates a PWM signal whose average value is proportional to the duty cycle.

## Usage

To use this module in your design:

1. Add the `pwm_led_controller.vhd` file to your project
2. Instantiate the module in your top-level design
3. Connect the module's inputs and outputs to your system
4. Configure the generics based on your requirements:
   - `CLK_FREQ_HZ_g` - Your system clock frequency
   - `PWM_FREQ_HZ_g` - Desired PWM frequency (typically 100Hz to 1kHz for LED brightness)
   - `PWM_RESOLUTION_g` - Number of bits for duty cycle resolution (8 bits = 256 levels)

## Testing

The provided testbench (`pwm_led_controller_tb.vhd`) verifies the functionality of the PWM controller by:

1. Testing multiple duty cycle settings (0%, 25%, 50%, 75%, 100%)
2. Verifying reset functionality
3. Checking the correct timing of the PWM output signal

Run the testbench in your preferred VHDL simulator to verify proper operation.

## FPGA Learning Roadmap

This project is part of a structured learning path consisting of 7 sprints:

### Sprint 1: Development Environment Setup & Hello World
- Setting up FPGA development environment (Vivado/Quartus)
- Implementing a basic LED blinking project ("Hello World")

### Sprint 2: Basic Logic Gates
- Designing and simulating fundamental logic gates (AND, OR, XOR)
- Learning about Boolean algebra and digital logic fundamentals

### Sprint 3: Button-Controlled LED
- Implementing button input handling with debounce circuitry
- Creating a simple user interface with buttons and LEDs

### Sprint 4: 7-Segment Display Controller
- Building a 7-segment display controller to display decimal numbers (0-9)
- Learning about display interfaces and decimal to 7-segment encoding

### Sprint 5: PWM LED Brightness Control
- Implementing pulse width modulation for LED brightness control
- Understanding timing, counters, and duty cycle concepts

### Sprint 6: 4-Bit Binary Counter
- Creating a binary counter with display output
- Learning about sequential logic and state management

### Sprint 7: Shift Register LED Animation
- Building shift registers for creating LED animations
- Understanding sequential data transfer and LED pattern generation

## Style Guidelines

All code in this repository follows a consistent style defined in the `vhdl_style/vhdl_style_rules.md` file. These guidelines ensure code readability, maintainability, and consistency across all files. 