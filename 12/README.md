# VGA Output for Drawing Squares

## Project Overview
This project implements a VGA controller and square drawing system in VHDL. The system generates VGA signals to display multiple squares on a standard 640x480@60Hz display. It demonstrates key concepts of VGA timing, video memory, and pixel generation while providing interactive controls for manipulating the squares on screen.

The project features:
- VGA timing and synchronization signal generation (HSYNC, VSYNC)
- Multiple configurable squares with different colors and properties
- User-controlled and automatic square movement
- Collision detection between squares and screen boundaries
- Different display modes with varying square sizes and speeds

## Repository Organization
The project is organized into the following VHDL source files:

- `src/vga_controller.vhd`: Generates standard VGA timing signals
- `src/square_generator.vhd`: Implements a single controllable square
- `src/multi_square_generator.vhd`: Manages multiple squares with collision detection
- `src/vga_square_top.vhd`: Top-level module connecting all components
- `src/vga_square_tb.vhd`: Testbench for simulation and verification

## Implementation Details

### VGA Controller
The VGA controller implements standard 640x480@60Hz timing with:
- Horizontal timing: 640 active + 16 front porch + 96 sync + 48 back porch = 800 pixels
- Vertical timing: 480 active + 10 front porch + 2 sync + 33 back porch = 525 lines
- Pixel clock: 25MHz (generated from system clock)

The controller generates:
- Horizontal and vertical sync signals
- Display enable signal during active video time
- Current pixel coordinates (column, row)

### Square Generator
The square generator creates and manages square objects with:
- Configurable size, color, and position
- Movement controls with boundary collision detection
- Customizable movement speed

### Multi-Square Generator
The multi-square generator extends functionality to handle multiple squares:
- Supports up to 4 squares with different colors
- Manages automatic movement patterns for non-selected squares
- Detects collisions between squares
- Implements prioritized pixel color selection for overlapping squares

### Top-Level Integration
The top level integrates all components with:
- Clock division for 25MHz pixel clock
- User input processing for controlling squares
- Frame-rate generation for consistent animation
- Output RGB color mapping to VGA interface

## VGA Timing Diagram
```
Horizontal Timing:
<--  HSYNC  -->
___|¯¯¯¯¯¯¯¯¯¯|_______________________________
   |          |          |       |            |
   | Back     | Active   | Front | Sync       |
   | Porch    | Video    | Porch |            |
   | 48 px    | 640 px   | 16 px | 96 px      |
   <-------------- 800 pixels total ---------->

Vertical Timing:
<--  VSYNC  -->
___|¯¯¯¯¯¯¯¯¯¯|_______________________________
   |          |          |       |            |
   | Back     | Active   | Front | Sync       |
   | Porch    | Video    | Porch |            |
   | 33 lines | 480 lines| 10 ln | 2 lines    |
   <------------- 525 lines total ------------>
```

## Usage

### Signal Connections
To use this VGA interface in your design:

1. Connect system clock to `clk_i` (50MHz or 100MHz)
2. Connect active-low reset to `reset_n_i`
3. Connect VGA output signals to your display:
   - `vga_hsync_o` → VGA HSYNC pin
   - `vga_vsync_o` → VGA VSYNC pin
   - `vga_red_o` → VGA Red pins (4 bits)
   - `vga_green_o` → VGA Green pins (4 bits)
   - `vga_blue_o` → VGA Blue pins (4 bits)
4. Connect control inputs to your device's buttons/switches:
   - `btn_up_i`, `btn_down_i`, `btn_left_i`, `btn_right_i` → Movement controls
   - `mode_select_i` → Square size and speed mode (2 bits)
   - `square_select_i` → Square selection (2 bits)

### Example Instantiation

```vhdl
vga_system_inst: entity work.vga_square_top
    port map (
        clk_i           => system_clock,
        reset_n_i       => system_reset_n,
        btn_up_i        => button_up,
        btn_down_i      => button_down,
        btn_left_i      => button_left,
        btn_right_i     => button_right,
        mode_select_i   => switch_mode,
        square_select_i => switch_select,
        vga_hsync_o     => vga_hsync,
        vga_vsync_o     => vga_vsync,
        vga_red_o       => vga_red,
        vga_green_o     => vga_green,
        vga_blue_o      => vga_blue,
        led_collision_o => led_collision
    );
```

## Testing

The testbench (`vga_square_tb.vhd`) simulates:
1. VGA signal generation and timing
2. Square movement and collision detection
3. Different operating modes
4. User control scenarios

To verify functionality:
1. Simulate the testbench with your preferred VHDL simulator
2. Monitor the VGA signals to verify timing compliance
3. Check the square movement and collision reporting
4. Confirm color output during active display time

## Applications

This project can serve as a foundation for:
- Video game development on FPGA
- Basic graphics system for embedded displays
- Educational tool for learning VGA principles
- Starting point for more complex graphics applications

## Further Enhancements

Potential enhancements include:
- Support for higher resolutions (800x600, 1024x768)
- Additional graphical elements (circles, lines, text)
- More complex animations and movement patterns
- Sprite-based graphics with image storage
- Background image or pattern generation
- Score display and game mechanics

## References

- VGA Standard Timing: [VESA DMT Standard](https://en.wikipedia.org/wiki/Video_Electronics_Standards_Association)
- Digital Display Timing: [Analog Devices VGA Timing](https://www.analog.com/media/en/technical-documentation/application-notes/AN-1057.pdf)
- FPGA Graphics: ["FPGA Prototyping by VHDL Examples" by Pong P. Chu](https://academic.csuohio.edu/chu_p/rtl/fpga_vhdl.html) 