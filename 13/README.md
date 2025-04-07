# ADC Monitoring System

## Project Overview
This project implements a complete analog-to-digital converter (ADC) monitoring system in VHDL. The system interfaces with external ADC devices via SPI, processes the acquired data, and visualizes results on displays and LEDs. The implementation is designed to be configurable and adaptable to different ADC resolutions, number of channels, and display formats.

The system features:
- Configurable SPI-based ADC controller for data acquisition
- Multiple visualization modes including raw values, voltage, and custom scaling
- LED bar graph display for visual trend monitoring
- User-configurable high and low thresholds with indicator outputs
- Support for both manual and automatic sampling modes
- Comprehensive control interface with button and switch inputs
- Flexible channel selection and display mode switching

## Repository Organization
The project consists of the following VHDL source files:

- `src/adc_controller.vhd`: Manages ADC communication and data acquisition via SPI
- `src/adc_simulator.vhd`: Simulates an ADC device for testing without external hardware
- `src/display_controller.vhd`: Processes ADC data and drives display outputs
- `src/adc_system_top.vhd`: Top-level module integrating all components
- `src/adc_system_tb.vhd`: Testbench for system verification

## Implementation Details

### ADC Controller
The ADC Controller module implements the SPI master interface for communicating with external ADC devices. Key features include:

- Configurable SPI clock frequency and timing
- Support for multiple ADC channels with independent sampling
- Automatic sampling mode with adjustable sampling rate
- Complete SPI transaction management for ADC command and data transfer
- Status signals for monitoring conversion progress

The controller supports a typical SPI-based ADC protocol with the following signals:
- CS_N (Chip Select, active low)
- SCLK (Serial Clock)
- MOSI (Master Out Slave In)
- MISO (Master In Slave Out)

### Display Controller
The Display Controller processes the acquired ADC data and drives the visualization outputs. Features include:

- Multiple display modes:
  - Raw ADC values
  - Voltage conversion with reference scaling
  - Custom scaling for sensor-specific applications
  - Bar graph visualization
- BCD conversion for 7-segment display output
- Configurable decimal point positioning
- LED bar graph output for trend visualization
- High and low threshold detection with output signals

### System Architecture
The system architecture integrates the components as shown below:

```
                 +---------------------+
                 |                     |
 User Input ---->|                     |-----> 7-Segment Display
(Buttons,        |   ADC Monitoring    |
 Switches)       |       System        |-----> LED Bar Graph
                 |                     |
                 |                     |-----> Status LEDs
                 +----------^----------+
                            |
                            v
                 +----------+----------+
                 |                     |
                 |    SPI Interface    |<----> External ADC
                 |                     |       (or Simulator)
                 +---------------------+
```

### Finite State Machine
The ADC Controller uses a finite state machine (FSM) to manage the conversion process:

1. **IDLE**: Waiting for conversion trigger
2. **INIT_CONVERSION**: Preparing for conversion
3. **WAIT_SPI_START**: Waiting for SPI clock alignment
4. **TX_CONFIG**: Sending configuration to ADC
5. **RX_DATA**: Receiving data from ADC
6. **PROCESS_RESULT**: Processing received data
7. **CONV_DONE**: Signaling conversion complete

## Usage

### Required Hardware
To use this system with real hardware, you'll need:
- FPGA development board
- External ADC device with SPI interface
- 7-segment display (4 digits)
- LEDs for bar graph display
- Push buttons and switches for control

For simulation purposes, the included ADC simulator can generate test waveforms without external hardware.

### Interface Description

#### Inputs
- `clk_i`: System clock (typically 50MHz)
- `reset_n_i`: Active-low reset
- `btn_sample_i`: Button to trigger manual sampling
- `btn_channel_i`: Button to cycle through ADC channels
- `btn_mode_i`: Button to change display mode
- `sw_auto_sample_i`: Switch to enable automatic sampling
- `sw_threshold_i`: Switches to select threshold adjustment mode
- `sw_threshold_val_i`: Switches to adjust threshold values
- `spi_miso_i`: SPI data input from external ADC

#### Outputs
- `segment_data_o`: 7-segment display pattern output
- `digit_sel_o`: Digit selection for 7-segment display
- `led_bar_o`: LED bar graph display output
- `led_busy_o`: Conversion in progress indicator
- `led_above_thresh_o`: Above high threshold indicator
- `led_below_thresh_o`: Below low threshold indicator
- `led_channel_o`: Current selected channel indicator
- `spi_cs_n_o`: SPI chip select output
- `spi_sclk_o`: SPI clock output
- `spi_mosi_o`: SPI data output

### Example Instantiation

```vhdl
adc_system_inst: entity work.adc_system_top
    generic map (
        CLK_FREQ_HZ_g    => 50_000_000,
        ADC_BITS_g       => 12,
        ADC_CHANNELS_g   => 4,
        SPI_FREQ_HZ_g    => 1_000_000,
        DISPLAY_DIGITS_g => 4
    )
    port map (
        clk_i              => system_clock,
        reset_n_i          => system_reset_n,
        btn_sample_i       => button_sample,
        btn_channel_i      => button_channel,
        btn_mode_i         => button_mode,
        sw_auto_sample_i   => switch_auto,
        sw_threshold_i     => switches_threshold_mode,
        sw_threshold_val_i => switches_threshold_value,
        spi_cs_n_o         => adc_cs_n,
        spi_sclk_o         => adc_sclk,
        spi_mosi_o         => adc_mosi,
        spi_miso_i         => adc_miso,
        segment_data_o     => segment_data,
        digit_sel_o        => digit_select,
        led_bar_o          => led_bar,
        led_busy_o         => led_busy,
        led_above_thresh_o => led_above_threshold,
        led_below_thresh_o => led_below_threshold,
        led_channel_o      => led_channel
    );
```

## Testing

The testbench (`adc_system_tb.vhd`) simulates the complete system operation with the following test cases:

1. **Manual Sampling Mode**: Tests button-triggered sampling
2. **Auto Sampling Mode**: Tests automatic sampling functionality
3. **Threshold Adjustment**: Tests high and low threshold setting
4. **Channel Cycling**: Tests channel selection functionality
5. **Display Mode Cycling**: Tests display mode switching
6. **Mode Switching**: Tests switching between auto and manual modes

To run the simulation:
1. Compile all VHDL files in your simulation environment
2. Run the `adc_system_tb` simulation
3. Monitor the console output for transaction reports
4. Verify proper system behavior in waveform viewer

## Applications

This ADC monitoring system can be used in various applications:
- Data acquisition systems
- Sensor monitoring and control
- Environmental monitoring
- Process control systems
- Educational platforms for ADC principles
- Signal analysis and visualization

## Waveform Visualization

The ADC simulator generates the following waveforms for testing:
- Channel 0: Sine wave
- Channel 1: Triangle wave
- Channel 2: Ramp (sawtooth) wave
- Channel 3: Constant value

These waveforms can be visualized on both the 7-segment display and LED bar graph.

## Further Enhancements

Potential enhancements to the system include:
- Support for additional ADC types and interfaces (I²C, parallel)
- Enhanced data processing (averaging, filtering)
- Data logging capabilities via UART
- More advanced visualization options
- Expanded threshold detection with alarm functionality
- Calibration functionality for improved accuracy
- PC connectivity for extended data analysis

## References

- ADC Communication: [SPI Protocol Specification](https://www.analog.com/en/analog-dialogue/articles/introduction-to-spi-interface.html)
- 7-Segment Display: [Interfacing Tutorial](https://www.electronics-tutorials.ws/blog/7-segment-display-tutorial.html)
- FPGA Implementation: ["FPGA Prototyping by VHDL Examples" by Pong P. Chu](https://academic.csuohio.edu/chu_p/rtl/fpga_vhdl.html) 