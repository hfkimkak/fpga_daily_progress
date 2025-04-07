--------------------------------------------------------------------------------
-- File: display_controller.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Display Controller module for visualizing ADC data.
-- Converts ADC values to human-readable format for 7-segment displays.
-- Includes bar graph display mode for LEDs and threshold detection.
-- Supports multiple display modes (raw, voltage, custom scaling).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_controller is
    generic (
        -- Display configuration
        ADC_BITS_g       : integer range 8 to 16 := 12;   -- ADC resolution (bits)
        DISPLAY_DIGITS_g : integer range 2 to 8  := 4;    -- Number of 7-segment digits
        
        -- Reference voltage (in millivolts)
        VREF_MV_g        : integer := 3300;   -- 3.3V reference
        
        -- Custom scaling (for sensor calibration)
        USE_CUSTOM_SCALE_g : boolean := false;   -- Use custom scaling instead of voltage
        CUSTOM_SCALE_g     : integer := 100;     -- Custom scale factor (x100)
        CUSTOM_OFFSET_g    : integer := 0;       -- Custom offset
        CUSTOM_UNIT_CHAR_g : std_logic_vector(7 downto 0) := x"63"  -- 'c' character
    );
    port (
        -- Clock and reset
        clk_i            : in  std_logic;
        reset_n_i        : in  std_logic;
        
        -- ADC data input
        adc_data_i       : in  std_logic_vector(ADC_BITS_g-1 downto 0);
        data_valid_i     : in  std_logic;  -- Pulse when new data available
        
        -- Display mode selection
        display_mode_i   : in  std_logic_vector(1 downto 0);  -- 00:raw, 01:voltage, 10:custom, 11:bar
        
        -- 7-segment display outputs
        segment_data_o   : out std_logic_vector(7 downto 0);  -- Segment pattern (including decimal point)
        digit_sel_o      : out std_logic_vector(DISPLAY_DIGITS_g-1 downto 0);  -- Digit selection
        
        -- LED bar graph output
        led_bar_o        : out std_logic_vector(15 downto 0);  -- LED bar graph display
        
        -- Threshold detection
        threshold_high_i : in  std_logic_vector(ADC_BITS_g-1 downto 0);  -- High threshold
        threshold_low_i  : in  std_logic_vector(ADC_BITS_g-1 downto 0);  -- Low threshold
        above_thresh_o   : out std_logic;  -- Signal when above high threshold
        below_thresh_o   : out std_logic   -- Signal when below low threshold
    );
end entity display_controller;

architecture rtl of display_controller is

    -- Type definitions for BCD conversion
    type bcd_digit_array_t is array(0 to DISPLAY_DIGITS_g-1) of integer range 0 to 9;
    signal bcd_digits : bcd_digit_array_t;
    
    -- Display data signals
    signal display_value : integer;  -- Value to display (after scaling/conversion)
    signal decimal_pos   : integer range 0 to DISPLAY_DIGITS_g-1;  -- Decimal point position
    
    -- Multiplexing counter for display scanning
    signal digit_counter : integer range 0 to DISPLAY_DIGITS_g-1 := 0;
    signal digit_sel     : std_logic_vector(DISPLAY_DIGITS_g-1 downto 0);
    
    -- LED bar calculation signals
    signal led_bar_value : std_logic_vector(15 downto 0);
    
    -- Threshold detection signals
    signal above_threshold : std_logic;
    signal below_threshold : std_logic;
    
    -- 7-segment patterns for hexadecimal digits and special characters
    type segment_pattern_array_t is array(0 to 17) of std_logic_vector(7 downto 0);
    constant SEGMENT_PATTERNS : segment_pattern_array_t := (
        -- Hex digits 0-9, A-F (bit 7 is decimal point, active low)
        "11000000",  -- 0: abcdef-
        "11111001",  -- 1: -bc----
        "10100100",  -- 2: ab-de-g
        "10110000",  -- 3: abcd--g
        "10011001",  -- 4: -bc--fg
        "10010010",  -- 5: a-cd-fg
        "10000010",  -- 6: a-cdefg
        "11111000",  -- 7: abc----
        "10000000",  -- 8: abcdefg
        "10010000",  -- 9: abcd-fg
        "10001000",  -- A: abc-efg
        "10000011",  -- b: --cdefg
        "11000110",  -- C: a--def-
        "10100001",  -- d: -bcde-g
        "10000110",  -- E: a--defg
        "10001110",  -- F: a---efg
        "10111111",  -- Special: dash '-'
        "11111111"   -- Special: blank
    );
    
    -- Constants for display multiplexing
    constant DIGIT_BLANK : integer := 17;  -- Index for blank pattern
    constant DIGIT_DASH  : integer := 16;  -- Index for dash pattern
    
    -- Clock divider for display multiplexing
    constant DISPLAY_REFRESH_DIV : integer := 20000;  -- For ~1kHz refresh with 50MHz clock
    signal refresh_counter : integer range 0 to DISPLAY_REFRESH_DIV-1 := 0;
    signal refresh_tick : std_logic;
    
begin

    -- Map outputs
    above_thresh_o <= above_threshold;
    below_thresh_o <= below_threshold;
    led_bar_o <= led_bar_value;
    digit_sel_o <= digit_sel;
    
    -- Threshold detection
    above_threshold <= '1' when unsigned(adc_data_i) > unsigned(threshold_high_i) else '0';
    below_threshold <= '1' when unsigned(adc_data_i) < unsigned(threshold_low_i) else '0';
    
    -- Display refresh rate generator
    refresh_tick_gen: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            refresh_counter <= 0;
            refresh_tick <= '0';
        elsif rising_edge(clk_i) then
            refresh_tick <= '0';  -- Default
            
            if refresh_counter = DISPLAY_REFRESH_DIV-1 then
                refresh_counter <= 0;
                refresh_tick <= '1';
            else
                refresh_counter <= refresh_counter + 1;
            end if;
        end if;
    end process refresh_tick_gen;
    
    -- LED bar graph generation
    led_bar_process: process(clk_i, reset_n_i)
        variable adc_norm : integer;
        variable led_count : integer range 0 to 16;
    begin
        if reset_n_i = '0' then
            led_bar_value <= (others => '0');
        elsif rising_edge(clk_i) then
            if data_valid_i = '1' then
                -- Normalize ADC value to 0-16 range for LED bar
                adc_norm := to_integer(unsigned(adc_data_i));
                led_count := (adc_norm * 16) / (2**ADC_BITS_g-1);
                
                -- Generate bar pattern
                led_bar_value <= (others => '0');  -- Start with all LEDs off
                for i in 0 to 15 loop
                    if i < led_count then
                        led_bar_value(i) <= '1';  -- Turn on LEDs up to led_count
                    end if;
                end loop;
            end if;
        end if;
    end process led_bar_process;
    
    -- Value conversion based on display mode
    value_conversion: process(clk_i, reset_n_i)
        variable adc_value : integer;
        variable voltage_mv : integer;
        variable custom_value : integer;
    begin
        if reset_n_i = '0' then
            display_value <= 0;
            decimal_pos <= 0;
        elsif rising_edge(clk_i) then
            if data_valid_i = '1' then
                adc_value := to_integer(unsigned(adc_data_i));
                
                -- Process based on display mode
                case display_mode_i is
                    when "00" =>  -- Raw ADC value
                        display_value <= adc_value;
                        decimal_pos <= DISPLAY_DIGITS_g;  -- No decimal point
                        
                    when "01" =>  -- Voltage in mV
                        -- Calculate voltage: (ADC_value * VREF) / (2^ADC_BITS - 1)
                        voltage_mv := (adc_value * VREF_MV_g) / (2**ADC_BITS_g-1);
                        display_value <= voltage_mv;
                        
                        if DISPLAY_DIGITS_g >= 4 then
                            decimal_pos <= DISPLAY_DIGITS_g - 4;  -- Show as X.XXX V
                        else
                            decimal_pos <= 0;  -- Show as decimal value
                        end if;
                        
                    when "10" =>  -- Custom scaling
                        if USE_CUSTOM_SCALE_g then
                            -- Apply custom scale and offset: (ADC_value * scale / 2^bits) + offset
                            custom_value := (adc_value * CUSTOM_SCALE_g) / (2**ADC_BITS_g-1) + CUSTOM_OFFSET_g;
                            display_value <= custom_value;
                            
                            -- Set decimal point based on scaling factor
                            if CUSTOM_SCALE_g >= 100 then
                                decimal_pos <= 2;  -- XX.YY format
                            elsif CUSTOM_SCALE_g >= 10 then
                                decimal_pos <= 1;  -- X.YYY format
                            else
                                decimal_pos <= 0;  -- 0.YYYY format
                            end if;
                        else
                            -- Default to raw value if custom scaling not enabled
                            display_value <= adc_value;
                            decimal_pos <= DISPLAY_DIGITS_g;  -- No decimal point
                        end if;
                        
                    when others =>  -- "11" - Bar graph mode, but also show raw value
                        display_value <= adc_value;
                        decimal_pos <= DISPLAY_DIGITS_g;  -- No decimal point
                end case;
            end if;
        end if;
    end process value_conversion;
    
    -- BCD conversion for display
    bcd_conversion: process(clk_i, reset_n_i)
        variable bcd_temp : integer;
        variable digit : integer;
    begin
        if reset_n_i = '0' then
            for i in 0 to DISPLAY_DIGITS_g-1 loop
                bcd_digits(i) <= 0;
            end loop;
        elsif rising_edge(clk_i) then
            if data_valid_i = '1' then
                -- Extract individual BCD digits
                bcd_temp := display_value;
                
                for i in 0 to DISPLAY_DIGITS_g-1 loop
                    digit := bcd_temp mod 10;  -- Extract least significant digit
                    bcd_digits(i) <= digit;    -- Store in BCD array (right to left)
                    bcd_temp := bcd_temp / 10; -- Move to next digit
                end loop;
            end if;
        end if;
    end process bcd_conversion;
    
    -- Display multiplexing
    display_multiplex: process(clk_i, reset_n_i)
        variable digit_value : integer range 0 to 17;
        variable current_digit : integer range 0 to DISPLAY_DIGITS_g-1;
        variable has_dp : boolean;
    begin
        if reset_n_i = '0' then
            digit_counter <= 0;
            digit_sel <= (0 => '1', others => '0');
            segment_data_o <= SEGMENT_PATTERNS(DIGIT_BLANK);
        elsif rising_edge(clk_i) then
            if refresh_tick = '1' then
                -- Move to next digit
                if digit_counter = DISPLAY_DIGITS_g-1 then
                    digit_counter <= 0;
                else
                    digit_counter <= digit_counter + 1;
                end if;
                
                -- Select current digit (active low)
                digit_sel <= (others => '1');  -- All off
                digit_sel(digit_counter) <= '0';  -- Current digit on
                
                -- Get value for current digit
                current_digit := digit_counter;
                digit_value := bcd_digits(current_digit);
                
                -- Check if this position needs decimal point
                has_dp := (current_digit = decimal_pos);
                
                -- Select segment pattern for current digit
                if digit_value <= 9 then
                    -- Normal BCD digit
                    segment_data_o <= SEGMENT_PATTERNS(digit_value);
                elsif display_mode_i = "10" and current_digit = 0 and USE_CUSTOM_SCALE_g then
                    -- Special case for custom unit symbol in rightmost position
                    segment_data_o <= CUSTOM_UNIT_CHAR_g;
                else
                    -- For any invalid/unused digits
                    segment_data_o <= SEGMENT_PATTERNS(DIGIT_BLANK);
                end if;
                
                -- Add decimal point if needed (active low for decimal point)
                if has_dp then
                    segment_data_o(7) <= '0';  -- Turn on decimal point (active low)
                end if;
            end if;
        end if;
    end process display_multiplex;
    
end architecture rtl; 