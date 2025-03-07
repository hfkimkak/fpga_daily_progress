---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Button-Controlled LED with Debounce Circuit
--                - Implements a debounce circuit to eliminate button bounce
--                - Uses a counter-based approach with configurable debounce time
--                - Includes two-stage synchronization to prevent metastability
--                - Features edge detection to trigger on button press only
--                - Controls LED patterns that change with each button press
--                - Supports multiple LED patterns in sequence:
--                  * Individual LEDs lighting up in sequence
--                  * All LEDs on
--                  * All LEDs off
--                - Provides generic parameters for easy customization:
--                  * Clock frequency
--                  * Debounce time
--                  * Number of LEDs
--                - Board-agnostic design that can be used with various FPGA boards
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity button_led_debounce is
    generic (
        CLK_FREQ_HZ_g : integer := 100_000_000; --! Clock frequency in Hz (default 100 MHz)
        DEBOUNCE_MS_g : integer := 20;          --! Debounce period in milliseconds (default 20ms)
        NUM_LEDS_g    : integer := 4            --! Number of LEDs to control (default 4 LEDs)
    );
    port (
        clk_i     : in  std_logic;                                --! System clock
        reset_n_i : in  std_logic;                                --! Active low reset
        button_i  : in  std_logic;                                --! Button input
        leds_o    : out std_logic_vector(NUM_LEDS_g-1 downto 0)   --! LED outputs
    );
end entity button_led_debounce;

architecture rtl of button_led_debounce is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    constant DEBOUNCE_CYCLES_c : integer := (CLK_FREQ_HZ_g / 1000) * DEBOUNCE_MS_g; --! Number of clock cycles for debounce

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    signal button_sync_0_s     : std_logic := '0';  --! Synchronization flip-flop 1
    signal button_sync_1_s     : std_logic := '0';  --! Synchronization flip-flop 2
    signal button_debounced_s  : std_logic := '0';  --! Debounced button signal
    signal button_prev_s       : std_logic := '0';  --! Previous button state
    signal debounce_counter_s  : integer range 0 to DEBOUNCE_CYCLES_c := 0; --! Counter for debounce
    
    signal led_pattern_s       : std_logic_vector(NUM_LEDS_g-1 downto 0) := (others => '0'); --! Current LED pattern
    signal led_count_s         : unsigned(NUM_LEDS_g-1 downto 0) := (others => '0'); --! Counter for LED patterns
    signal button_pressed_s    : std_logic := '0';  --! Button press detected signal

    --------------------------------------------------------------------------------------------------------------------
    -- ATTRIBUTE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

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
    begin
        if (reset_n_i = '0') then
            -- Reset LED pattern
            led_count_s <= (others => '0');
            led_pattern_s <= (others => '0');
        else
            if (rising_edge(clk_i)) then
                if (button_pressed_s = '1') then
                    -- Increment LED counter on button press
                    led_count_s <= led_count_s + 1;
                    
                    -- Update LED pattern based on counter
                    case to_integer(led_count_s) is
                        when 0 =>
                            -- First pattern: Only first LED on
                            led_pattern_s <= (0 => '1', others => '0');
                        when 1 =>
                            -- Second pattern: Only second LED on
                            led_pattern_s <= (1 => '1', others => '0');
                        when 2 =>
                            -- Third pattern: Only third LED on
                            led_pattern_s <= (2 => '1', others => '0');
                        when 3 =>
                            -- Fourth pattern: Only fourth LED on
                            led_pattern_s <= (3 => '1', others => '0');
                        when 4 =>
                            -- Fifth pattern: All LEDs on
                            led_pattern_s <= (others => '1');
                        when 5 =>
                            -- Sixth pattern: All LEDs off
                            led_pattern_s <= (others => '0');
                        when others =>
                            -- Reset counter and start over
                            led_count_s <= (others => '0');
                            led_pattern_s <= (0 => '1', others => '0');
                    end case;
                end if;
            end if;
        end if;
    end process led_control_proc;

end architecture rtl; 