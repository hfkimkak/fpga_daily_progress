# FPGA Zero to Hero

This project offers a structured learning path for FPGA development using VHDL, following a "Zero to Hero" approach. Projects are organized in steps, each building on the knowledge and skills from previous ones.

## Project Structure

This repository is organized into numbered directories, each representing a step in the learning path:

### Sprint 1: FPGA Fundamentals
- `/1` - **Step 1:** FPGA Environment and LED Control
- `/2` - **Step 2:** Logic Gates
- `/3` - **Step 3:** Button-Controlled LED
- `/4` - **Step 4:** 7-Segment Display
- `/5` - **Step 5:** PWM LED Brightness Control
- `/6` - **Step 6:** 4-Bit Binary Counter
- `/7` - **Step 7:** Shift Register LED Animation

### Sprint 2: Intermediate Designs and Protocols
- `/8` - **Step 1:** Traffic Light Controller Using FSM
- `/9` - **Step 2:** UART Protocol - "Hello World" Transmission
- `/10` - **Step 3:** SPI Protocol for External Sensor/EEPROM Communication
- `/11` - **Step 4:** I²C Protocol to Read Temperature Sensor (e.g., LM75)
- `/12` - **Step 5:** VGA Output for Drawing Squares (640x480)
- `/13` - **Step 6:** Analog Signal Reading with ADC
- `/14` - **Step 7:** FIFO Memory Design and Testing

The `/vhdl_style` directory contains the style guidelines followed throughout all projects.

## Learning Roadmap

### Sprint 1: FPGA Fundamentals

#### Step 1: FPGA Environment and LED Control
- Setting up FPGA development environment (Vivado/Quartus)
- Creating a "Hello World" project (LED blinking)
- Learning basic VHDL concepts

#### Step 2: Logic Gates
- Designing and simulating basic logic gates (AND, OR, XOR)
- Learning Boolean algebra and digital logic fundamentals
- Combinational circuit design

#### Step 3: Button-Controlled LED
- Implementing button input handling with debounce circuitry
- Creating a simple user interface with buttons and LEDs
- Understanding input/output control

#### Step 4: 7-Segment Display
- Building a 7-segment display controller to display decimal numbers (0-9)
- Learning about display interfaces and decimal-to-7-segment encoding
- Display unit control

#### Step 5: PWM LED Brightness Control
- Implementing pulse width modulation for LED brightness control
- Understanding timing, counters, and duty cycle concepts
- Using digital techniques for analog-like behaviors

#### Step 6: 4-Bit Binary Counter
- Creating a 4-bit binary counter (0-15)
- Learning about sequential logic and state management
- Up/down counting, reset, and enable control

#### Step 7: Shift Register LED Animation
- Building shift registers for creating LED animations
- Understanding sequential data transfer and LED pattern generation
- More complex digital system control

### Sprint 2: Intermediate Designs and Protocols

#### Step 1: Traffic Light Controller Using FSM
- Implementing a Finite State Machine (FSM) to control traffic lights
- Developing state transition logic and timing control
- Creating reusable state machine templates
- Managing multiple outputs based on state

#### Step 2: UART Protocol - "Hello World" Transmission
- Understanding UART serial communication principles
- Implementing transmitter and receiver modules
- Configuring baud rate and communication parameters
- Sending text data to a computer terminal

#### Step 3: SPI Protocol for External Sensor/EEPROM Communication
- Learning Serial Peripheral Interface (SPI) fundamentals
- Implementing master and slave interfaces
- Handling clock polarity and phase configurations
- Reading from and writing to external devices

#### Step 4: I²C Protocol to Read Temperature Sensor
- Understanding Inter-Integrated Circuit (I²C) bus protocol
- Implementing master controller for I²C communications
- Handling addressing, start/stop conditions, and acknowledgments
- Reading data from a temperature sensor (e.g., LM75)

#### Step 5: VGA Output for Drawing Squares
- Learning VGA timing and synchronization principles
- Generating horizontal and vertical sync signals
- Creating video memory and pixel generation logic
- Drawing basic shapes on a 640x480 display

#### Step 6: Analog Signal Reading with ADC
- Interfacing with Analog-to-Digital Converters
- Implementing sampling control and timing
- Processing and displaying analog measurements
- Signal conditioning and filtering techniques

#### Step 7: FIFO Memory Design and Testing
- Creating First-In-First-Out memory structures
- Implementing write and read pointers management
- Handling full and empty conditions
- Testing FIFO operation and performance

## Code Style

All VHDL code in this repository follows the style guidelines defined in the `/vhdl_style/vhdl_style_rules.md` file. These guidelines ensure code readability, maintainability, and consistency across all projects.

## Author

Halil Furkan KIMKAK

## Getting Started

Each step directory contains its own README with specific instructions for that project. Start from Step 1 and progress sequentially for the best learning experience.

## Requirements

- FPGA development board (Xilinx, Intel/Altera, etc.)
- FPGA development environment (Vivado, Quartus, etc.)
- Basic understanding of digital logic
- VHDL knowledge (or willingness to learn) 