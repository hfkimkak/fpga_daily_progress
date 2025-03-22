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

### Sprint 3: Advanced Projects and Optimization
- `/15` - **Step 1:** PID Controller for DC Motor Speed Control
- `/16` - **Step 2:** Moving Ball Animation on VGA Display
- `/17` - **Step 3:** Sound Signal Generation (MIDI/Note-based)
- `/18` - **Step 4:** Embedded RISC-V Core Setup (e.g., PicoRV32)
- `/19` - **Step 5:** Image Processing (e.g., Grayscale Filter)
- `/20` - **Step 6:** Multi-Clock Domain Design (Clock Domain Crossing)
- `/21` - **Step 7:** High-Speed Data Read/Write with DDR Memory Controller

### Sprint 4: Integration and Final Project
- `/22` - **Step 1:** Custom Peripheral Design for Nios II/PicoRV32 Processor
- `/23` - **Step 2:** IoT Application with Bluetooth/WiFi Module
- `/24` - **Step 3:** Digital Clock with Real-Time Clock (RTC)
- `/25` - **Step 4:** Signal Generator on FPGA (DDS-based)
- `/26` - **Step 5:** Simple Object Recognition with CNN (MNIST Dataset)
- `/27` - **Step 6:** Retro Game Console on FPGA (e.g., Pong)
- `/28` - **Step 7:** Resource Usage Optimization (LUT, FF Reduction)
- `/29` - **Step 8:** Timing Analysis and Critical Path Optimization
- `/30` - **Step 9:** Final Project: To Be Determined

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

### Sprint 3: Advanced Projects and Optimization

#### Step 1: PID Controller for DC Motor Speed Control
- Understanding PID control theory and implementation
- Interfacing with motor drivers and encoders
- Creating feedback loops for speed regulation
- Tuning PID parameters for optimal performance

#### Step 2: Moving Ball Animation on VGA Display
- Implementing complex graphics on VGA display
- Creating sprite movement and collision detection
- Managing frame buffers and animation timing
- Developing basic game physics (gravity, bounce)

#### Step 3: Sound Signal Generation (MIDI/Note-based)
- Creating digital waveform generators (sine, square, triangle)
- Implementing note frequency calculation and timing
- Developing audio output interfaces (PWM or DAC)
- Building a simple music sequencer or tone generator

#### Step 4: Embedded RISC-V Core Setup
- Integrating an open-source RISC-V core (e.g., PicoRV32)
- Setting up instruction and data memory
- Implementing basic I/O for the processor
- Writing and running simple programs on the core

#### Step 5: Image Processing (Grayscale Filter)
- Working with image data and buffers
- Implementing grayscale conversion algorithms
- Creating pipeline architectures for efficient processing
- Testing with real image data

#### Step 6: Multi-Clock Domain Design
- Understanding clock domain crossing challenges
- Implementing synchronizers and FIFOs for safe data transfer
- Analyzing and resolving metastability issues
- Creating robust multi-clock systems

#### Step 7: High-Speed Data with DDR Memory Controller
- Interfacing with DDR memory
- Implementing memory controllers with timing constraints
- Managing read/write operations at high frequencies
- Testing memory bandwidth and access patterns

### Sprint 4: Integration and Final Project

#### Step 1: Custom Peripheral Design for Processors
- Creating memory-mapped peripherals for soft processors
- Implementing bus interfaces (Avalon, AXI, Wishbone)
- Developing interrupt handling mechanisms
- Testing peripheral functionality with software

#### Step 2: IoT Application with Bluetooth/WiFi Module
- Interfacing with wireless communication modules
- Implementing communication protocols (AT commands, SPI/UART bridges)
- Creating data acquisition and transmission systems
- Building a complete IoT sensor node

#### Step 3: Digital Clock with Real-Time Clock
- Interfacing with RTC chips for accurate timekeeping
- Creating time display modules with 7-segment or LCD
- Implementing time setting and alarm functions
- Adding battery backup considerations

#### Step 4: Signal Generator on FPGA (DDS-based)
- Implementing Direct Digital Synthesis techniques
- Creating high-precision frequency generators
- Developing configurable waveform types and parameters
- Building a complete bench instrument replacement

#### Step 5: Simple Object Recognition with CNN
- Implementing basic convolutional neural networks
- Working with the MNIST dataset for digit recognition
- Creating inference acceleration architectures
- Optimizing neural network operations for FPGA

#### Step 6: Retro Game Console on FPGA
- Building classic games like Pong or Space Invaders
- Implementing game controllers and interfaces
- Creating sprite-based graphics engines
- Developing game logic and scoring systems

#### Step 7: Resource Usage Optimization
- Analyzing and reducing LUT and flip-flop usage
- Implementing resource sharing techniques
- Using block RAM and DSP slices efficiently
- Applying FPGA-specific optimization strategies

#### Step 8: Timing Analysis and Critical Path Optimization
- Understanding static timing analysis
- Identifying and resolving timing violations
- Implementing pipelining and retiming
- Applying constraints for timing closure

#### Step 9: Final Project
- Comprehensive project combining multiple skills
- Complete system design from requirements to implementation
- Documentation and testing methodologies
- Performance analysis and optimization

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