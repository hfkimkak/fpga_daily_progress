# I²C Temperature Monitoring System

## Project Overview
This project demonstrates a complete I²C communication system designed for temperature monitoring. It consists of an I²C master controller, an I²C slave interface, an LM75 temperature sensor emulator, and a temperature reading module that displays temperature data on a 7-segment display.

The system shows the implementation of the I²C protocol in VHDL, including:
- Bidirectional communication
- START and STOP condition generation and detection
- Address and data transmission
- ACK/NACK handling
- Multi-byte register access
- Clock stretching support

## Repository Organization
This repository contains the following VHDL files:

- `src/i2c_master.vhd`: I²C Master controller implementing the bus protocol
- `src/i2c_slave.vhd`: I²C Slave interface for peripheral implementation
- `src/i2c_temp_sensor.vhd`: LM75 temperature sensor emulator using the I²C slave interface
- `src/i2c_temp_reader.vhd`: Temperature reader module that reads from the LM75 sensor
- `src/i2c_system_tb.vhd`: Testbench that verifies the complete system functionality

## Implementation Details

### I²C Master
The I²C Master implements a full-featured controller that can:
- Generate START, repeated START, and STOP conditions
- Transmit and receive data bytes with proper ACK/NACK handling
- Support standard (100 kHz) and fast (400 kHz) modes
- Handle transactions with configurable timeout detection
- Provide simple register read/write interface for higher-level modules

### I²C Slave
The I²C Slave provides a flexible interface that can be used to implement any I²C peripheral. Features include:
- 7-bit address recognition with programmable address
- START/STOP condition detection
- ACK/NACK signaling
- Optional clock stretching
- Data buffer for reads and writes
- Simple interface for connecting to device-specific logic

### LM75 Temperature Sensor
The LM75 temperature sensor emulator implements a standard digital temperature sensor with I²C interface. It provides:
- 11-bit temperature readings with 0.125°C resolution
- Configurable temperature range and step size for simulation
- Standard LM75 register map:
  - Temperature register (read-only)
  - Configuration register
  - Thyst register (over-temperature threshold)
  - Tos register (hysteresis threshold)

### Temperature Reader
The temperature reader module periodically reads temperature data from the LM75 sensor and displays it on a 7-segment display. Features include:
- Configurable update rate
- Temperature formatting in degrees Celsius
- Error detection and handling
- User-triggered and automatic reading modes
- 7-segment display output with multiplexing control

## Protocol Details
The I²C protocol operates with two bidirectional lines:
- SCL (Serial Clock Line): provides synchronization between devices
- SDA (Serial Data Line): carries the data bits

The protocol uses START and STOP conditions to mark the beginning and end of transactions:
- START: SDA transitions high-to-low while SCL is high
- STOP: SDA transitions low-to-high while SCL is high

Data bits are transmitted with MSB first, and each byte is followed by an ACK/NACK bit from the receiver.

## Usage

### Integration
To integrate the I²C modules into your design:

1. Include the master controller if your device needs to initiate I²C transactions
2. Include the slave interface if your device needs to respond to I²C transactions
3. Connect the SCL and SDA lines to the appropriate pins with external pull-up resistors

### Configuration
Each module has configurable parameters:

```vhdl
-- Master controller configuration example
i2c_master_inst: i2c_master
    generic map (
        CLK_FREQ_HZ    => 100_000_000,  -- System clock frequency
        I2C_FREQ_HZ    => 400_000       -- I²C clock frequency (Fast mode)
    )
    port map (
        -- Port connections
    );

-- Slave configuration example
i2c_slave_inst: i2c_slave
    generic map (
        SLAVE_ADDR     => "1001000",    -- 7-bit address (0x48)
        BUFFER_SIZE    => 8,            -- Internal buffer size
        CLOCK_STRETCH  => true          -- Enable clock stretching
    )
    port map (
        -- Port connections
    );
```

## Testing

The testbench (`i2c_system_tb.vhd`) demonstrates the complete I²C system. It performs the following:

1. Initializes the temperature reader and sensor modules
2. Triggers temperature reading operations
3. Verifies successful data transfers
4. Checks error handling
5. Reports temperature values

To run the testbench:
1. Compile all VHDL files in your simulation environment
2. Run the simulation for at least 100 μs to observe multiple temperature readings
3. Check simulation waveforms and console output for results

## Applications

This I²C implementation can be adapted for various applications:
- Environmental monitoring systems
- Data acquisition systems
- Control systems with I²C sensors
- FPGA-based test equipment
- I²C protocol analyzers

## Enhancements

Potential enhancements to this system include:
- Support for 10-bit addressing
- Multi-master arbitration
- Support for SMBus extensions
- Additional peripheral implementations (EEPROM, ADC, RTC, etc.)
- Bus monitoring and debugging features

## References

- I²C Bus Specification: [NXP I²C Specification](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
- LM75 Datasheet: [LM75 Digital Temperature Sensor](https://www.ti.com/lit/ds/symlink/lm75.pdf) 