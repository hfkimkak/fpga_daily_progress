# VGA Moving Ball Animation

This project implements a moving ball animation on a VGA display using an FPGA. The ball moves under the influence of gravity, bounces off walls, and experiences friction. The animation is smooth thanks to double buffering.

## Project Structure

The project consists of the following VHDL source files:

- `src/vga_ball_controller.vhd`: VGA controller module that generates VGA signals and manages frame buffer access
- `src/frame_buffer.vhd`: Frame buffer module implementing double buffering for smooth animation
- `src/moving_ball.vhd`: Module that handles physics calculations and collision detection
- `src/vga_ball_system.vhd`: Top-level module integrating all components
- `src/vga_ball_system_tb.vhd`: Testbench for verifying system functionality

## Features

### VGA Controller
- Supports 640x480 resolution at 60 Hz refresh rate
- Generates standard VGA timing signals
- Provides pixel coordinates for drawing
- Implements frame completion detection

### Frame Buffer
- Double buffering for smooth animation
- Independent read and write ports
- 24-bit RGB color support
- Efficient memory access

### Moving Ball
- Physics-based movement with gravity
- Wall collision detection and response
- Configurable bounce and friction effects
- Speed limiting for realistic motion
- Smooth ball rendering with anti-aliasing

## Usage

### Hardware Requirements
- FPGA with sufficient logic resources
- VGA output interface
- 50 MHz system clock
- External VGA display

### Interface Description

#### Inputs
- `clk_i`: System clock (50 MHz)
- `reset_n_i`: Active-low reset signal

#### Outputs
- `vga_hsync_o`: Horizontal sync signal
- `vga_vsync_o`: Vertical sync signal
- `vga_red_o`: Red color channel (8 bits)
- `vga_green_o`: Green color channel (8 bits)
- `vga_blue_o`: Blue color channel (8 bits)
- `vga_blank_o`: Blanking signal
- `ball_x_o`: Current ball X position
- `ball_y_o`: Current ball Y position
- `ball_vx_o`: Ball X velocity
- `ball_vy_o`: Ball Y velocity
- `collision_o`: Collision detection signal
- `frame_done_o`: Frame completion signal

### Example Usage

```vhdl
-- Instantiate the VGA ball system
vga_ball: vga_ball_system
    generic map (
        CLK_FREQ_HZ_g     => 50_000_000,
        H_ACTIVE_g        => 640,
        H_FRONT_g        => 16,
        H_SYNC_g         => 96,
        H_BACK_g         => 48,
        V_ACTIVE_g       => 480,
        V_FRONT_g        => 10,
        V_SYNC_g         => 2,
        V_BACK_g         => 33,
        COLOR_WIDTH_g    => 8,
        PIXEL_WIDTH_g    => 24,
        BALL_RADIUS_g    => 20,
        BALL_COLOR_g     => x"FF0000"  -- Red color
    )
    port map (
        clk_i            => clk,
        reset_n_i        => reset_n,
        vga_hsync_o      => vga_hsync,
        vga_vsync_o      => vga_vsync,
        vga_red_o        => vga_red,
        vga_green_o      => vga_green,
        vga_blue_o       => vga_blue,
        vga_blank_o      => vga_blank,
        ball_x_o         => ball_x,
        ball_y_o         => ball_y,
        ball_vx_o        => ball_vx,
        ball_vy_o        => ball_vy,
        collision_o      => collision,
        frame_done_o     => frame_done
    );
```

## Testing

The testbench verifies:
- VGA timing generation
- Ball physics calculations
- Collision detection
- Frame buffer operation
- System integration

Test scenarios include:
- Ball movement under gravity
- Wall collisions
- Friction effects
- Frame timing
- Memory access patterns

## Applications

This project can be used in:
- Educational demonstrations of physics
- Interactive displays
- Game development
- Visual effects testing

## Further Enhancements

Possible improvements include:
- Multiple balls with collision between them
- User input for ball control
- Different ball colors and effects
- Background graphics
- Sound effects for collisions
- Position control mode
- Communication interface for external control

## References

- VGA Timing Specifications
- Physics Simulation Methods
- FPGA Design Guidelines
- VHDL Best Practices 