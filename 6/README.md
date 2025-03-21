# 4-Bit Binary Counter Implementation

This project implements a configurable 4-bit binary counter (0-15) with various features for FPGA implementation.

## Project Description

The binary counter module provides a flexible solution for counting applications. Key features include:

- 4-bit counter range (0-15) with configurable bit width
- Up/down counting capability
- Configurable clock divider for adjustable counting speed
- Count enable control
- Synchronous reset
- BCD digit output (0-9) for direct 7-segment display connection
- Clean, well-documented code following consistent style guidelines

## Repository Organization

- `src/` - Contains all VHDL source and testbench files

## Files

- `src/binary_counter.vhd` - Main binary counter implementation
- `src/binary_counter_tb.vhd` - Testbench for verification

## Implementation Details

The binary counter works by:

1. Dividing the system clock to generate a slower count frequency (adjustable via generics)
2. Generating a tick signal at the desired count frequency
3. Incrementing or decrementing the counter based on the up/down control input
4. Wrapping around appropriately (0→15→0 for up-counting, 15→0→15 for down-counting)
5. Converting the binary output to BCD for optional 7-segment display connection

The implementation uses parameterized generics for flexibility, making it usable in many different applications.

## Usage

To use this module in your design:

1. Add the `binary_counter.vhd` file to your project
2. Instantiate the module in your top-level design
3. Connect the module's inputs and outputs to your system
4. Configure the generics based on your requirements:
   - `CLK_FREQ_HZ_g` - Your system clock frequency
   - `COUNT_FREQ_HZ_g` - Desired counting frequency
   - `COUNTER_WIDTH_g` - Number of bits for counter (default: 4 for 0-15 range)

### Example Instantiation

```vhdl
-- 4-bit counter that counts at 2Hz with a 100MHz system clock
your_counter_instance : binary_counter
    generic map (
        CLK_FREQ_HZ_g    => 100_000_000,  -- 100 MHz system clock
        COUNT_FREQ_HZ_g  => 2,            -- 2 Hz counting
        COUNTER_WIDTH_g  => 4             -- 4-bit counter (0-15)
    )
    port map (
        clk_i       => system_clock,
        reset_n_i   => system_reset_n,
        enable_i    => count_enable,
        up_down_i   => count_direction,   -- '1' for up, '0' for down
        count_o     => binary_count,
        bcd_digit_o => bcd_value
    );
```

## Testing

The provided testbench (`binary_counter_tb.vhd`) verifies the functionality by:

1. Testing up-counting (0→15→0)
2. Testing down-counting (15→0→15)
3. Verifying counter enable/disable functionality
4. Testing reset during operation
5. Checking correct wraparound behavior

Run the testbench in your preferred VHDL simulator to verify proper operation.

## Applications

This binary counter can be used in many applications, including:

- Simple timers and counters
- Control sequencing
- Frequency division
- Display control
- State machine control
- LED pattern generation

## Integration with 7-Segment Display

The counter includes a BCD output that can be directly connected to a 7-segment display decoder. For numbers above 9, the BCD output is clamped to 9 to maintain valid BCD format. For two-digit display, additional logic would be required to separate the binary value into tens and ones.

## Further Enhancements

Some possible enhancements to this counter could include:

1. Adding load capability to preset the counter
2. Adding multi-digit BCD conversion for values above 9
3. Adding terminal count outputs for cascading counters
4. Adding more sophisticated display mappings
5. Implementing modulo-N counting (counting to values other than 2^N-1) 