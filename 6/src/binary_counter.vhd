---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  4-bit Binary Counter (0-15)
--                - Configurable clock divider for adjustable counting speed
--                - Synchronous reset
--                - Count enable control
--                - Up/down counting support
--                - Board-agnostic design for use with any FPGA
--                - Optional digit output for 7-segment display connection
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity binary_counter is
    generic (
        CLK_FREQ_HZ_g    : integer := 100000000;  --! System clock frequency in Hz
        COUNT_FREQ_HZ_g  : integer := 1;          --! Counting frequency in Hz (default: 1 Hz)
        COUNTER_WIDTH_g  : integer := 4           --! Counter width in bits (default: 4-bit, 0-15)
    );
    port (
        clk_i      : in  std_logic;                                     --! System clock
        reset_n_i  : in  std_logic;                                     --! Active low reset
        
        enable_i   : in  std_logic;                                     --! Count enable (active high)
        up_down_i  : in  std_logic;                                     --! Count direction: '1' for up, '0' for down
        
        count_o    : out std_logic_vector(COUNTER_WIDTH_g-1 downto 0);  --! Binary counter output
        
        -- Optional BCD output for 7-segment display connection
        bcd_digit_o : out std_logic_vector(3 downto 0)                  --! BCD digit output (0-9, truncated)
    );
end entity binary_counter;

architecture rtl of binary_counter is

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    constant MAX_COUNT_c : integer := 2**COUNTER_WIDTH_g - 1;  --! Maximum counter value
    constant CLOCK_DIV_c : integer := CLK_FREQ_HZ_g / COUNT_FREQ_HZ_g;  --! Clock divider value

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    signal clock_div_counter_s : integer range 0 to CLOCK_DIV_c - 1;  --! Clock divider counter
    signal tick_s             : std_logic;  --! Pulse signal at count frequency
    signal counter_s          : unsigned(COUNTER_WIDTH_g-1 downto 0);  --! Internal counter value
    signal bcd_digit_s        : unsigned(3 downto 0);  --! BCD digit value

    --------------------------------------------------------------------------------------------------------------------
    -- ATTRIBUTE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL PART
    --------------------------------------------------------------------------------------------------------------------
    
    -- Convert counter to std_logic_vector for output
    count_o <= std_logic_vector(counter_s);
    
    -- Convert BCD digit to std_logic_vector for output
    bcd_digit_o <= std_logic_vector(bcd_digit_s);
    
    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL PART
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- CLOCK_DIV_PROC : Clock divider process for slower counting
    --------------------------------------------------------------------------------------------------------------------
    clock_div_proc : process(clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            clock_div_counter_s <= 0;
            tick_s <= '0';
        elsif (rising_edge(clk_i)) then
            -- Default
            tick_s <= '0';
            
            -- Increment divider counter
            if (clock_div_counter_s = CLOCK_DIV_c - 1) then
                clock_div_counter_s <= 0;
                tick_s <= '1';  -- Generate tick pulse
            else
                clock_div_counter_s <= clock_div_counter_s + 1;
            end if;
        end if;
    end process clock_div_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- COUNTER_PROC : Binary counter process
    --------------------------------------------------------------------------------------------------------------------
    counter_proc : process(clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            counter_s <= (others => '0');
        elsif (rising_edge(clk_i)) then
            if (enable_i = '1' and tick_s = '1') then
                -- Count up/down based on direction input
                if (up_down_i = '1') then
                    -- Count up (increment)
                    if (counter_s = MAX_COUNT_c) then
                        counter_s <= (others => '0');  -- Wrap around to 0
                    else
                        counter_s <= counter_s + 1;
                    end if;
                else
                    -- Count down (decrement)
                    if (counter_s = 0) then
                        counter_s <= to_unsigned(MAX_COUNT_c, COUNTER_WIDTH_g);  -- Wrap around to max
                    else
                        counter_s <= counter_s - 1;
                    end if;
                end if;
            end if;
        end if;
    end process counter_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- BCD_CONVERSION_PROC : Convert binary to BCD for values 0-9 (truncate rest)
    --------------------------------------------------------------------------------------------------------------------
    bcd_conversion_proc : process(counter_s) is
    begin
        -- Simple conversion for 0-9, truncate rest to maintain valid BCD
        if (counter_s > 9) then
            bcd_digit_s <= to_unsigned(9, 4);  -- Clamp to max BCD digit
        else
            bcd_digit_s <= counter_s(3 downto 0);
        end if;
    end process bcd_conversion_proc;

end architecture rtl; 