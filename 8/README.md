# Traffic Light Controller Using FSM

This project implements a basic traffic light controller for an intersection using a Finite State Machine (FSM) approach in VHDL.

## Project Description

The Traffic Light Controller module provides a flexible solution for managing traffic lights at a four-way intersection with North-South and East-West directions. Key features include:

- Four-state Finite State Machine (FSM) implementation
- Configurable timing for each traffic light state
- Complete traffic light control (red, yellow, green) for two perpendicular directions
- Clock divider for actual seconds-based timing
- Reset functionality
- Debug/status outputs for monitoring
- Clean, well-documented code following consistent style guidelines

## Repository Organization

- `src/` - Contains all VHDL source and testbench files

## Files

- `src/traffic_light_controller.vhd` - Main traffic light controller implementation
- `src/traffic_light_controller_tb.vhd` - Testbench for verification

## Implementation Details

The traffic light controller is implemented as a Finite State Machine (FSM) with four primary states:

1. **North-South Green / East-West Red**: Main North-South traffic flow is allowed while East-West is stopped
2. **North-South Yellow / East-West Red**: North-South traffic is warned to stop with a yellow light
3. **East-West Green / North-South Red**: Main East-West traffic flow is allowed while North-South is stopped
4. **East-West Yellow / North-South Red**: East-West traffic is warned to stop with a yellow light

Each state has a configurable duration (in seconds), controlled by a timer that is decremented once per second using a clock divider. The FSM transitions between states when the timer reaches zero, following a cyclic pattern.

## FSM State Diagram

```
                  timer = 0                      timer = 0
   +------------+           +---------------+            +------------+
   |            |           |               |            |            |
   | NS_GREEN   +---------->+ NS_YELLOW     +----------->  EW_GREEN   |
   |            |           |               |            |            |
   +------------+           +---------------+            +------------+
         ^                                                     |
         |                                                     |
         |                                                     |
         |                                                     |
         |                     timer = 0                       v
         |                  +---------------+                   |
         |                  |               |                   |
         +------------------+ EW_YELLOW     +<------------------+
                            |               |      timer = 0
                            +---------------+
```

## Usage

To use this module in your design:

1. Add the `traffic_light_controller.vhd` file to your project
2. Instantiate the module in your top-level design
3. Connect the module's inputs and outputs to your system
4. Configure the generics based on your requirements:
   - `CLK_FREQ_HZ_g` - Your system clock frequency
   - `NS_GREEN_TIME_g` - Duration of North-South green light (seconds)
   - `NS_YELLOW_TIME_g` - Duration of North-South yellow light (seconds)
   - `EW_GREEN_TIME_g` - Duration of East-West green light (seconds)
   - `EW_YELLOW_TIME_g` - Duration of East-West yellow light (seconds)

### Example Instantiation

```vhdl
-- Traffic light controller with 30s NS green, 5s NS yellow, 20s EW green, 5s EW yellow
your_traffic_light_instance : traffic_light_controller
    generic map (
        CLK_FREQ_HZ_g     => 100_000_000,   -- 100 MHz system clock
        NS_GREEN_TIME_g   => 30,            -- 30 seconds for NS green
        NS_YELLOW_TIME_g  => 5,             -- 5 seconds for NS yellow
        EW_GREEN_TIME_g   => 20,            -- 20 seconds for EW green
        EW_YELLOW_TIME_g  => 5              -- 5 seconds for EW yellow
    )
    port map (
        clk_i           => system_clock,
        reset_n_i       => system_reset_n,
        
        ns_red_o        => ns_red_signal,
        ns_yellow_o     => ns_yellow_signal,
        ns_green_o      => ns_green_signal,
        
        ew_red_o        => ew_red_signal,
        ew_yellow_o     => ew_yellow_signal,
        ew_green_o      => ew_green_signal,
        
        current_state_o => current_state,
        timer_value_o   => timer_value
    );
```

## Testing

The provided testbench (`traffic_light_controller_tb.vhd`) verifies the functionality by:

1. Testing all state transitions in the FSM cycle
2. Verifying the timing for each state
3. Testing reset functionality during operation
4. Monitoring the traffic light outputs to ensure correct behavior
5. Reporting state changes and traffic light status during simulation

The testbench uses accelerated timing to make simulation efficient.

## Applications

This traffic light controller can be used in many applications, including:

- Simple intersection traffic control systems
- Educational demonstrations of FSM principles
- Laboratory experiments with hardware control
- Traffic simulation models
- Embedded systems development
- Integration into larger traffic management solutions

## Further Enhancements

Some possible enhancements to this design could include:

1. Adding pedestrian crossing signals and buttons
2. Implementing emergency vehicle override (e.g., for fire trucks, ambulances)
3. Adding time-of-day or day-of-week scheduling for different traffic patterns
4. Implementing traffic sensors to adjust timing based on demand
5. Adding more complex intersections with turn signals
6. Implementing coordination between multiple intersections
7. Adding fault detection and handling (e.g., for burned-out light bulbs) 