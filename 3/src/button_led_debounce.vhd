---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Button-Controlled LED with Debounce Circuit
--                - Implements a debounce circuit to eliminate button bounce
--                - Uses a counter-based approach with configurable debounce time
--                - Includes two-stage synchronization to prevent metastability
--                - Features edge detection to trigger on button press only
--                - Controls LED patterns that change with each button press
--                - Supports multiple LED patterns in sequence:
--                  * Single LED sequence
--                  * All LEDs on/off
--                  * Shift left/right patterns
--                  * Bounce (ping-pong) effect
--                  * Random patterns
--                - Provides generic parameters for easy customization:
--                  * Clock frequency
--                  * Debounce time
--                  * Number of LEDs
--                  * Effect speed
--                - Board-agnostic design that can be used with various FPGA boards
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;  -- For random number generation

entity button_led_debounce is
    generic (
        CLK_FREQ_HZ_g    : integer := 100_000_000; -- Clock frequency in Hz (default 100 MHz)
        DEBOUNCE_MS_g    : integer := 20;          -- Debounce period in milliseconds (default 20ms)
        NUM_LEDS_g       : integer := 4;           -- Number of LEDs to control (default 4 LEDs)
        EFFECT_SPEED_MS_g: integer := 100          -- Effect speed in milliseconds
    );
    port (
        clk_i     : in  std_logic;                               -- System clock
        reset_n_i : in  std_logic;                               -- Active low reset
        button_i  : in  std_logic;                               -- Button input
        leds_o    : out std_logic_vector(NUM_LEDS_g-1 downto 0)  -- LED outputs
    );
end entity button_led_debounce;

architecture rtl of button_led_debounce is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    -- Type declarations
    type effect_mode_t is (
        SINGLE_LED,     -- Single LED mode
        ALL_LEDS,       -- All LEDs
        SHIFT_RIGHT,    -- Right shift effect
        SHIFT_LEFT,     -- Left shift effect
        BOUNCE,         -- Ping-pong effect
        RANDOM         -- Random blinking
    );

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    constant DEBOUNCE_CYCLES_c  : integer := (CLK_FREQ_HZ_g / 1000) * DEBOUNCE_MS_g;
    constant EFFECT_CYCLES_c    : integer := (CLK_FREQ_HZ_g / 1000) * EFFECT_SPEED_MS_g;

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    signal button_sync_0_s     : std_logic := '0';  --! Synchronization flip-flop 1
    signal button_sync_1_s     : std_logic := '0';  --! Synchronization flip-flop 2
    signal button_debounced_s  : std_logic := '0';  --! Debounced button signal
    signal button_prev_s       : std_logic := '0';  --! Previous button state
    signal debounce_counter_s  : integer range 0 to DEBOUNCE_CYCLES_c := 0; --! Counter for debounce
    
    signal led_pattern_s       : std_logic_vector(NUM_LEDS_g-1 downto 0) := (others => '0'); --! Current LED pattern
    signal current_mode_s      : effect_mode_t := SINGLE_LED;
    signal effect_counter_s    : integer range 0 to EFFECT_CYCLES_c := 0;
    signal direction_right_s   : boolean := true;  -- For bounce effect
    
    signal button_pressed_s    : std_logic := '0';  --! Button press detected signal

    --------------------------------------------------------------------------------------------------------------------
    -- ATTRIBUTE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    -- Function to generate random LED pattern
    function random_pattern(seed: integer) return std_logic_vector is
        variable rand_temp : integer;
        variable result   : std_logic_vector(NUM_LEDS_g-1 downto 0);
    begin
        rand_temp := (seed * 16807) mod 2147483647;  -- Simple PRNG
        for i in 0 to NUM_LEDS_g-1 loop
            result(i) := std_logic(to_unsigned(rand_temp, 32)(i mod 32));
        end loop;
        return result;
    end function;

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL PART
    --------------------------------------------------------------------------------------------------------------------
    
    -- Connect LED pattern to output
    leds_o <= led_pattern_s;

    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL PART
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- DEBOUNCE_PROC : Button debounce process
    --------------------------------------------------------------------------------------------------------------------
    debounce_proc : process (clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            -- Reset all debounce signals
            button_sync_0_s <= '0';
            button_sync_1_s <= '0';
            button_debounced_s <= '0';
            debounce_counter_s <= 0;
        else
            if (rising_edge(clk_i)) then
                -- Two-stage synchronization to prevent metastability
                button_sync_0_s <= button_i;
                button_sync_1_s <= button_sync_0_s;
                
                -- Debounce logic
                if (button_sync_1_s /= button_debounced_s) then
                    -- Button state changed, start/reset counter
                    if (debounce_counter_s = DEBOUNCE_CYCLES_c - 1) then
                        -- Counter reached threshold, update debounced value
                        button_debounced_s <= button_sync_1_s;
                        debounce_counter_s <= 0;
                    else
                        -- Increment counter
                        debounce_counter_s <= debounce_counter_s + 1;
                    end if;
                else
                    -- Button state stable, reset counter
                    debounce_counter_s <= 0;
                end if;
            end if;
        end if;
    end process debounce_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- EDGE_DETECT_PROC : Button press detection (rising edge detection)
    --------------------------------------------------------------------------------------------------------------------
    edge_detect_proc : process (clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            button_prev_s <= '0';
            button_pressed_s <= '0';
        else
            if (rising_edge(clk_i)) then
                -- Detect rising edge (button press)
                button_prev_s <= button_debounced_s;
                button_pressed_s <= button_debounced_s and not button_prev_s;
            end if;
        end if;
    end process edge_detect_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- LED_CONTROL_PROC : LED pattern control process
    --------------------------------------------------------------------------------------------------------------------
    led_control_proc : process (clk_i, reset_n_i) is
        variable effect_step : integer := 0;
    begin
        if (reset_n_i = '0') then
            -- Reset LED pattern
            current_mode_s <= SINGLE_LED;
            led_pattern_s <= (0 => '1', others => '0');
            effect_counter_s <= 0;
            direction_right_s <= true;
        else
            if (rising_edge(clk_i)) then
                -- Mode selection on button press
                if button_pressed_s = '1' then
                    case current_mode_s is
                        when SINGLE_LED  => current_mode_s <= ALL_LEDS;
                        when ALL_LEDS    => current_mode_s <= SHIFT_RIGHT;
                        when SHIFT_RIGHT => current_mode_s <= SHIFT_LEFT;
                        when SHIFT_LEFT  => current_mode_s <= BOUNCE;
                        when BOUNCE      => current_mode_s <= RANDOM;
                        when RANDOM      => current_mode_s <= SINGLE_LED;
                    end case;
                    effect_step := 0;
                end if;

                -- Effect timing control
                if effect_counter_s = EFFECT_CYCLES_c - 1 then
                    effect_counter_s <= 0;
                    
                    -- Effect patterns
                    case current_mode_s is
                        when SINGLE_LED =>
                            led_pattern_s <= (effect_step => '1', others => '0');
                            effect_step := (effect_step + 1) mod NUM_LEDS_g;
                            
                        when ALL_LEDS =>
                            led_pattern_s <= (others => '1');
                            
                        when SHIFT_RIGHT =>
                            led_pattern_s <= '0' & led_pattern_s(NUM_LEDS_g-1 downto 1);
                            
                        when SHIFT_LEFT =>
                            led_pattern_s <= led_pattern_s(NUM_LEDS_g-2 downto 0) & '0';
                            
                        when BOUNCE =>
                            if direction_right_s then
                                if led_pattern_s(NUM_LEDS_g-1) = '1' then
                                    direction_right_s <= false;
                                    led_pattern_s <= '0' & led_pattern_s(NUM_LEDS_g-1 downto 1);
                                else
                                    led_pattern_s <= '0' & led_pattern_s(NUM_LEDS_g-1 downto 1);
                                end if;
                            else
                                if led_pattern_s(0) = '1' then
                                    direction_right_s <= true;
                                    led_pattern_s <= led_pattern_s(NUM_LEDS_g-2 downto 0) & '0';
                                else
                                    led_pattern_s <= led_pattern_s(NUM_LEDS_g-2 downto 0) & '0';
                                end if;
                            end if;
                            
                        when RANDOM =>
                            led_pattern_s <= random_pattern(effect_step);
                            effect_step := effect_step + 1;
                    end case;
                else
                    effect_counter_s <= effect_counter_s + 1;
                end if;
            end if;
        end if;
    end process led_control_proc;

end architecture rtl; 