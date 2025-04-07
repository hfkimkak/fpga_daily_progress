# FIFO Memory Design

## Project Overview
This project implements a configurable First-In-First-Out (FIFO) memory module in VHDL. The FIFO provides a reliable data buffering solution with features for monitoring its state and handling overflow/underflow conditions. The implementation is designed to be flexible and can be adapted to various data widths and depths.

The system features:
- Configurable data width and FIFO depth
- Write and read pointer management
- Full and empty condition detection
- Almost full/empty status indicators
- Overflow and underflow detection
- Support for simultaneous read and write operations
- Comprehensive status monitoring

## Repository Organization
The project consists of the following VHDL source files:

- `src/fifo_memory.vhd`: Main FIFO memory module implementation
- `src/fifo_memory_tb.vhd`: Testbench for verifying FIFO functionality

## Implementation Details

### FIFO Memory Module
The FIFO memory module implements a circular buffer with the following key features:

- **Configurable Parameters**:
  - Data width (default: 8 bits)
  - FIFO depth (default: 16 words, must be power of 2)
  - System clock frequency

- **Interface Signals**:
  - Write interface (write_en, write_data, full, almost_full)
  - Read interface (read_en, read_data, empty, almost_empty)
  - Status outputs (fifo_count, overflow, underflow)
  - Debug outputs (write_ptr, read_ptr)

- **Status Indicators**:
  - Full: FIFO is completely filled
  - Empty: FIFO is completely empty
  - Almost Full: FIFO is near capacity (2 words from full)
  - Almost Empty: FIFO is near empty (2 words from empty)
  - Overflow: Write attempted when FIFO is full
  - Underflow: Read attempted when FIFO is empty

### Memory Organization
The FIFO uses a circular buffer implementation with the following components:

1. **Memory Array**:
   - Dual-port memory array for storing data
   - Size determined by FIFO_DEPTH_g and DATA_WIDTH_g

2. **Pointers**:
   - Write pointer: Indicates next write location
   - Read pointer: Indicates next read location
   - Both pointers wrap around to 0 when reaching FIFO_DEPTH_g-1

3. **Counter**:
   - Tracks number of words currently in FIFO
   - Used for full/empty detection and status reporting

## Usage

### Required Hardware
For simulation:
- VHDL simulator (e.g., ModelSim, Vivado Simulator)

For synthesis:
- FPGA development board
- Clock source (typically 50MHz)

### Interface Description

#### Inputs
- `clk_i`: System clock
- `reset_n_i`: Active-low reset
- `write_en_i`: Write enable signal
- `write_data_i`: Data to write (DATA_WIDTH_g bits)
- `read_en_i`: Read enable signal

#### Outputs
- `full_o`: FIFO full indicator
- `almost_full_o`: Almost full indicator
- `read_data_o`: Data read from FIFO
- `empty_o`: FIFO empty indicator
- `almost_empty_o`: Almost empty indicator
- `fifo_count_o`: Current number of words in FIFO
- `overflow_o`: Overflow condition indicator
- `underflow_o`: Underflow condition indicator
- `write_ptr_o`: Current write pointer position
- `read_ptr_o`: Current read pointer position

### Example Instantiation

```vhdl
fifo_inst: entity work.fifo_memory
    generic map (
        DATA_WIDTH_g    => 8,
        FIFO_DEPTH_g    => 16,
        CLK_FREQ_HZ_g   => 50_000_000
    )
    port map (
        clk_i           => system_clock,
        reset_n_i       => system_reset_n,
        write_en_i      => write_enable,
        write_data_i    => write_data,
        full_o          => fifo_full,
        almost_full_o   => fifo_almost_full,
        read_en_i       => read_enable,
        read_data_o     => read_data,
        empty_o         => fifo_empty,
        almost_empty_o  => fifo_almost_empty,
        fifo_count_o    => fifo_count,
        overflow_o      => fifo_overflow,
        underflow_o     => fifo_underflow,
        write_ptr_o     => write_pointer,
        read_ptr_o      => read_pointer
    );
```

## Testing

The testbench (`fifo_memory_tb.vhd`) verifies the FIFO functionality through the following test cases:

1. **Basic Write and Read**:
   - Tests fundamental write and read operations
   - Verifies data integrity through read operations

2. **FIFO Full Condition**:
   - Tests FIFO filling to capacity
   - Verifies overflow detection
   - Tests write operations when full

3. **FIFO Empty Condition**:
   - Tests FIFO emptying
   - Verifies empty condition detection
   - Tests read operations when empty

4. **Almost Full/Empty Conditions**:
   - Tests almost full threshold detection
   - Tests almost empty threshold detection
   - Verifies status indicators

5. **Simultaneous Read and Write**:
   - Tests concurrent read and write operations
   - Verifies FIFO count remains correct
   - Checks data integrity during simultaneous operations

To run the simulation:
1. Compile both VHDL files in your simulation environment
2. Run the `fifo_memory_tb` simulation
3. Monitor the console output for test results
4. Verify proper FIFO behavior in waveform viewer

## Applications

This FIFO implementation can be used in various applications:
- Data buffering between different clock domains
- Serial communication interfaces
- Audio/video data streaming
- Sensor data collection
- Network packet buffering
- DMA transfers
- Multi-processor communication

## Further Enhancements

Potential enhancements to the system include:
- Asynchronous FIFO implementation for different clock domains
- Programmable almost full/empty thresholds
- Additional status flags (e.g., half-full)
- Error correction capabilities
- Performance monitoring features
- Power management options
- Extended debug capabilities

## References

- FIFO Design: [FIFO Memory Design Guide](https://www.xilinx.com/support/documentation/application_notes/xapp263.pdf)
- VHDL Implementation: ["FPGA Prototyping by VHDL Examples" by Pong P. Chu](https://academic.csuohio.edu/chu_p/rtl/fpga_vhdl.html)
- Clock Domain Crossing: [Xilinx Clock Domain Crossing Guide](https://www.xilinx.com/support/documentation/white_papers/wp272.pdf) 