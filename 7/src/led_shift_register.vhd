---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  LED Shift Register for LED Animations
--                - Configurable length shift register
--                - Multiple animation patterns (rotate, bounce, etc.)
--                - Adjustable animation speed
--                - Pattern selection input
--                - Reset and enable control
--                - Board-agnostic design for use with any FPGA
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity led_shift_register is
    generic (
        CLK_FREQ_HZ_g     : integer := 100000000;  --! System clock frequency in Hz
        SHIFT_FREQ_HZ_g   : integer := 5;          --! Shift frequency in Hz (default: 5 Hz)
        REGISTER_LENGTH_g : integer := 8           --! Shift register length (default: 8 LEDs)
    );
    port (
        clk_i           : in  std_logic;                                  --! System clock
        reset_n_i       : in  std_logic;                                  --! Active low reset
        
        enable_i        : in  std_logic;                                  --! Animation enable (active high)
        pattern_sel_i   : in  std_logic_vector(2 downto 0);               --! Animation pattern selection
        
        leds_o          : out std_logic_vector(REGISTER_LENGTH_g-1 downto 0) --! LED outputs
    );
end entity led_shift_register;

architecture rtl of led_shift_register is

    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    type animation_patterns_t is (
        SINGLE_RIGHT_t,    --! Single LED moving right (loop)
        SINGLE_LEFT_t,     --! Single LED moving left (loop)
        SINGLE_BOUNCE_t,   --! Single LED bouncing back and forth
        FILL_EMPTY_t,      --! Fill LEDs from left, then empty
        KNIGHT_RIDER_t,    --! Knight Rider / KITT scanner effect
        BINARY_COUNT_t,    --! Binary counter pattern
        ALTERNATE_t,       --! Alternating LEDs pattern
        RANDOM_t           --! Random-looking pattern sequence
    );

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    constant SHIFT_DIV_COUNT_c : integer := CLK_FREQ_HZ_g / SHIFT_FREQ_HZ_g;  --! Clock divider value for shift rate
    
    -- Knight Rider pattern length
    constant KNIGHT_RIDER_LENGTH_c : integer := (REGISTER_LENGTH_g * 2) - 2;
    
    -- Binary count iterations (2^N iterations)
    constant BINARY_COUNT_MAX_c : integer := 2**REGISTER_LENGTH_g - 1;
    
    -- LFSR taps for pseudo-random sequence (using maximal length LFSR taps)
    constant LFSR_TAPS_c : std_logic_vector(15 downto 0) := X"8016";  -- Taps for 16-bit LFSR

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    signal clk_div_counter_s   : integer range 0 to SHIFT_DIV_COUNT_c - 1;  --! Clock divider counter
    signal shift_tick_s        : std_logic;  --! Shift clock tick
    
    signal shift_register_s    : std_logic_vector(REGISTER_LENGTH_g-1 downto 0);  --! Shift register state
    signal current_pattern_s   : animation_patterns_t;  --! Current animation pattern
    
    signal direction_right_s   : std_logic;  --! Animation direction flag (for bounce patterns)
    signal position_counter_s  : integer range 0 to KNIGHT_RIDER_LENGTH_c - 1;  --! Position counter for animations
    signal binary_counter_s    : unsigned(REGISTER_LENGTH_g-1 downto 0);  --! Binary counter for counting pattern
    
    signal lfsr_s              : std_logic_vector(15 downto 0);  --! LFSR for pseudo-random sequence

    --------------------------------------------------------------------------------------------------------------------
    -- ATTRIBUTE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL PART
    --------------------------------------------------------------------------------------------------------------------
    
    -- Connect shift register to LEDs output
    leds_o <= shift_register_s;
    
    -- Pattern selection decoder
    pattern_select_proc : process(pattern_sel_i) is
    begin
        case pattern_sel_i is
            when "000"  => current_pattern_s <= SINGLE_RIGHT_t;
            when "001"  => current_pattern_s <= SINGLE_LEFT_t;
            when "010"  => current_pattern_s <= SINGLE_BOUNCE_t;
            when "011"  => current_pattern_s <= FILL_EMPTY_t;
            when "100"  => current_pattern_s <= KNIGHT_RIDER_t;
            when "101"  => current_pattern_s <= BINARY_COUNT_t;
            when "110"  => current_pattern_s <= ALTERNATE_t;
            when others => current_pattern_s <= RANDOM_t;
        end case;
    end process pattern_select_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL PART
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- CLOCK_DIV_PROC : Clock divider process for LED shift rate
    --------------------------------------------------------------------------------------------------------------------
    clock_div_proc : process(clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            clk_div_counter_s <= 0;
            shift_tick_s <= '0';
        elsif (rising_edge(clk_i)) then
            -- Default
            shift_tick_s <= '0';
            
            -- Increment divider counter
            if (clk_div_counter_s = SHIFT_DIV_COUNT_c - 1) then
                clk_div_counter_s <= 0;
                shift_tick_s <= '1';  -- Generate tick pulse
            else
                clk_div_counter_s <= clk_div_counter_s + 1;
            end if;
        end if;
    end process clock_div_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- SHIFT_REGISTER_PROC : Shift register animation controller
    --------------------------------------------------------------------------------------------------------------------
    shift_register_proc : process(clk_i, reset_n_i) is
        variable lfsr_feedback_v : std_logic;  -- LFSR feedback bit
    begin
        if (reset_n_i = '0') then
            -- Reset all signals
            shift_register_s   <= (0 => '1', others => '0');  -- Initialize with single LED on
            direction_right_s  <= '1';  -- Start moving right
            position_counter_s <= 0;
            binary_counter_s   <= (others => '0');
            lfsr_s             <= X"ACE1";  -- Non-zero seed for LFSR
            
        elsif (rising_edge(clk_i)) then
            if (enable_i = '1' and shift_tick_s = '1') then
                
                -- Animation pattern state machine
                case current_pattern_s is
                    
                    -- Single LED moving right in a loop
                    when SINGLE_RIGHT_t =>
                        shift_register_s <= shift_register_s(REGISTER_LENGTH_g-2 downto 0) & shift_register_s(REGISTER_LENGTH_g-1);
                    
                    -- Single LED moving left in a loop
                    when SINGLE_LEFT_t =>
                        shift_register_s <= shift_register_s(0) & shift_register_s(REGISTER_LENGTH_g-1 downto 1);
                    
                    -- Single LED bouncing back and forth
                    when SINGLE_BOUNCE_t =>
                        if (direction_right_s = '1') then
                            -- Moving right
                            if (shift_register_s(REGISTER_LENGTH_g-1) = '1') then
                                -- Reached right end, change direction
                                direction_right_s <= '0';
                                shift_register_s <= shift_register_s(0) & shift_register_s(REGISTER_LENGTH_g-1 downto 1);
                            else
                                -- Continue moving right
                                shift_register_s <= shift_register_s(REGISTER_LENGTH_g-2 downto 0) & shift_register_s(REGISTER_LENGTH_g-1);
                            end if;
                        else
                            -- Moving left
                            if (shift_register_s(0) = '1') then
                                -- Reached left end, change direction
                                direction_right_s <= '1';
                                shift_register_s <= shift_register_s(REGISTER_LENGTH_g-2 downto 0) & shift_register_s(REGISTER_LENGTH_g-1);
                            else
                                -- Continue moving left
                                shift_register_s <= shift_register_s(0) & shift_register_s(REGISTER_LENGTH_g-1 downto 1);
                            end if;
                        end if;
                    
                    -- Fill LEDs from left, then empty
                    when FILL_EMPTY_t =>
                        if (direction_right_s = '1') then
                            -- Filling phase
                            position_counter_s <= position_counter_s + 1;
                            shift_register_s(position_counter_s) <= '1';
                            
                            -- Check if we're full
                            if (position_counter_s = REGISTER_LENGTH_g - 1) then
                                direction_right_s <= '0';  -- Switch to emptying
                                position_counter_s <= 0;
                            end if;
                        else
                            -- Emptying phase
                            position_counter_s <= position_counter_s + 1;
                            shift_register_s(REGISTER_LENGTH_g - 1 - position_counter_s) <= '0';
                            
                            -- Check if we're empty
                            if (position_counter_s = REGISTER_LENGTH_g - 1) then
                                direction_right_s <= '1';  -- Switch to filling
                                position_counter_s <= 0;
                            end if;
                        end if;
                    
                    -- Knight Rider / KITT scanner effect
                    when KNIGHT_RIDER_t =>
                        -- Initialize pattern
                        shift_register_s <= (others => '0');
                        
                        -- Update position counter
                        if (position_counter_s = KNIGHT_RIDER_LENGTH_c - 1) then
                            position_counter_s <= 0;
                        else
                            position_counter_s <= position_counter_s + 1;
                        end if;
                        
                        -- Set the active LED based on position
                        if (position_counter_s < REGISTER_LENGTH_g) then
                            shift_register_s(position_counter_s) <= '1';
                        else
                            shift_register_s(KNIGHT_RIDER_LENGTH_c - position_counter_s) <= '1';
                        end if;
                    
                    -- Binary counter pattern
                    when BINARY_COUNT_t =>
                        -- Simple binary count
                        binary_counter_s <= binary_counter_s + 1;
                        shift_register_s <= std_logic_vector(binary_counter_s);
                    
                    -- Alternating LEDs pattern (0101... then 1010...)
                    when ALTERNATE_t =>
                        if (direction_right_s = '1') then
                            for i in 0 to REGISTER_LENGTH_g-1 loop
                                if (i mod 2 = 0) then
                                    shift_register_s(i) <= '0';
                                else
                                    shift_register_s(i) <= '1';
                                end if;
                            end loop;
                            direction_right_s <= '0';
                        else
                            for i in 0 to REGISTER_LENGTH_g-1 loop
                                if (i mod 2 = 0) then
                                    shift_register_s(i) <= '1';
                                else
                                    shift_register_s(i) <= '0';
                                end if;
                            end loop;
                            direction_right_s <= '1';
                        end if;
                    
                    -- Pseudo-random pattern using LFSR
                    when RANDOM_t =>
                        -- Calculate feedback using XOR of tapped bits
                        lfsr_feedback_v := '0';
                        for i in 0 to 15 loop
                            if (LFSR_TAPS_c(i) = '1') then
                                lfsr_feedback_v := lfsr_feedback_v xor lfsr_s(i);
                            end if;
                        end loop;
                        
                        -- Shift the LFSR
                        lfsr_s <= lfsr_s(14 downto 0) & lfsr_feedback_v;
                        
                        -- Map LFSR to the LED pattern (use lowest bits of LFSR for smaller LED counts)
                        for i in 0 to REGISTER_LENGTH_g-1 loop
                            if (i < 16) then  -- Protect against out-of-range LFSR access
                                shift_register_s(i) <= lfsr_s(i);
                            end if;
                        end loop;
                
                end case;
            end if;
        end if;
    end process shift_register_proc;

end architecture rtl; 