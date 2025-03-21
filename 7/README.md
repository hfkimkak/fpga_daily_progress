# Shift Register LED Animation

This project implements a versatile LED animation controller using shift registers for creating dynamic LED patterns on an FPGA.

## Project Description

The LED Shift Register module provides a flexible solution for creating various LED animations. Key features include:

- 8 different animation patterns selectable via input signals
- Configurable animation speed (shift frequency)
- Flexible register length for various LED array sizes
- Enable/disable control
- Reset functionality
- Patterns include: single LED movement, bouncing LED, filling/emptying, Knight Rider effect, binary counting, alternating, and pseudo-random sequences
- Clean, well-documented code following consistent style guidelines

## Repository Organization

- `src/` - Contains all VHDL source and testbench files

## Files

- `src/led_shift_register.vhd` - Main LED animation controller implementation
- `src/led_shift_register_tb.vhd` - Testbench for verification

## Implementation Details

The LED shift register works by maintaining a register of bits that are directly mapped to LED outputs. Various animation patterns are implemented by manipulating this register in different ways:

1. **Single Right/Left**: Simple shifting operations that move a single LED bit around the register
2. **Bounce**: A single LED that moves back and forth, changing direction when it reaches either end
3. **Fill/Empty**: Pattern that gradually fills all LEDs from left to right, then empties them
4. **Knight Rider**: Creates a scanning effect similar to the KITT car from Knight Rider
5. **Binary Count**: Counts in binary, lighting LEDs to represent the binary number
6. **Alternating**: Alternates between patterns where even/odd LEDs are lit
7. **Random**: Uses a Linear Feedback Shift Register (LFSR) to create pseudo-random LED patterns

Each animation is configurable in speed via a clock divider that generates a slower "shift tick" for updating the patterns.

## Usage

To use this module in your design:

1. Add the `led_shift_register.vhd` file to your project
2. Instantiate the module in your top-level design
3. Connect the module's inputs and outputs to your system
4. Configure the generics based on your requirements:
   - `CLK_FREQ_HZ_g` - Your system clock frequency
   - `SHIFT_FREQ_HZ_g` - Desired animation speed
   - `REGISTER_LENGTH_g` - Number of LEDs in your design

### Example Instantiation

```vhdl
-- LED animation controller with 16 LEDs and 2 Hz animation speed
your_animation_instance : led_shift_register
    generic map (
        CLK_FREQ_HZ_g     => 100_000_000,  -- 100 MHz system clock
        SHIFT_FREQ_HZ_g   => 2,            -- 2 Hz animation speed
        REGISTER_LENGTH_g => 16            -- 16 LEDs
    )
    port map (
        clk_i         => system_clock,
        reset_n_i     => system_reset_n,
        enable_i      => animation_enable,
        pattern_sel_i => pattern_select,  -- 3 bits for selecting 8 patterns
        leds_o        => led_outputs
    );
```

## Testing

The provided testbench (`led_shift_register_tb.vhd`) verifies the functionality by:

1. Testing all 8 animation patterns
2. Verifying enable/disable functionality during animations
3. Testing reset behavior
4. Checking animation timing
5. Reporting pattern changes and animation states

Run the testbench in your preferred VHDL simulator to visualize the LED patterns.

## Animation Patterns

The following animation patterns are available (selected using the 3-bit `pattern_sel_i` input):

| pattern_sel_i | Animation Pattern | Description |
|---------------|------------------|-------------|
| 000 | Single Right | Single LED moving right in loop |
| 001 | Single Left | Single LED moving left in loop |
| 010 | Bounce | Single LED bouncing back and forth |
| 011 | Fill/Empty | LEDs fill from left, then empty |
| 100 | Knight Rider | Classic scanning light pattern |
| 101 | Binary Count | Binary counting pattern |
| 110 | Alternating | Alternating LED pattern (0101→1010) |
| 111 | Random | Pseudo-random LED patterns using LFSR |

## Applications

This LED animation controller can be used in many applications, including:

- Status indicators
- Visual effects for electronic devices
- User interface feedback
- Decorative lighting
- Visual debugging
- Interactive displays
- Gaming systems

## Further Enhancements

Some possible enhancements to this design could include:

1. Adding individual brightness control for each LED
2. Implementing more complex patterns and sequences
3. Adding pattern transitions and blending effects
4. Creating a pattern memory for custom user-defined animations
5. Adding RGB LED support for color animations
6. Implementing music/sound reactive patterns 