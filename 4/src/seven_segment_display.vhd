---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Seven-Segment Display Controller
--                - Converts binary input (0-9) to 7-segment display output
--                - Supports common anode or common cathode displays
--                - Includes active-low reset
--                - Configurable active level (high/low)
--                - Board-agnostic design for use with any FPGA
--                - Segment mapping follows standard 7-segment convention:
--                   a
--                  ---
--                 |   |
--                f|   |b
--                 | g |
--                  ---
--                 |   |
--                e|   |c
--                 |   |
--                  ---
--                   d
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- < Add More User Library, If required. >

entity seven_segment_display is
    generic (
        COMMON_ANODE_g : boolean := true  --! Set to true for common anode, false for common cathode
    );
    port (
        clk_i      : in  std_logic;                     --! System clock
        reset_n_i  : in  std_logic;                     --! Active low reset
        
        digit_i    : in  std_logic_vector(3 downto 0);  --! Binary input (0-9)
        segments_o : out std_logic_vector(6 downto 0)   --! Segment outputs [a,b,c,d,e,f,g]
    );
end entity seven_segment_display;

architecture rtl of seven_segment_display is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    type segment_patterns_t is array (0 to 15) of std_logic_vector(6 downto 0); --! Type for segment patterns

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Constants for segment patterns (active high)
    --! Segment mapping: segments_o(6 downto 0) = [a,b,c,d,e,f,g]
    constant SEGMENT_PATTERNS_c : segment_patterns_t := (
        "1111110",  -- 0
        "0110000",  -- 1
        "1101101",  -- 2
        "1111001",  -- 3
        "0110011",  -- 4
        "1011011",  -- 5
        "1011111",  -- 6
        "1110000",  -- 7
        "1111111",  -- 8
        "1111011",  -- 9
        "1110111",  -- A
        "0011111",  -- b
        "1001110",  -- C
        "0111101",  -- d
        "1001111",  -- E
        "1000111"   -- F
    );

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    signal segment_pattern_s : std_logic_vector(6 downto 0); --! Current segment pattern
    signal digit_value_s     : integer range 0 to 15;        --! Digit value as integer

    --------------------------------------------------------------------------------------------------------------------
    -- ATTRIBUTE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL PART
    --------------------------------------------------------------------------------------------------------------------
    
    --! Convert binary input to integer
    digit_value_s <= to_integer(unsigned(digit_i));

    --! Output assignment with common anode/cathode handling
    output_proc : process(segment_pattern_s) is
    begin
        if (COMMON_ANODE_g = true) then
            -- For common anode, segments are active low
            segments_o <= not segment_pattern_s;
        else
            -- For common cathode, segments are active high
            segments_o <= segment_pattern_s;
        end if;
    end process output_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL PART
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- SEGMENT_PROC : Segment pattern selection process
    --------------------------------------------------------------------------------------------------------------------
    segment_proc : process(clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            -- Reset to display '0'
            segment_pattern_s <= SEGMENT_PATTERNS_c(0);
        else
            if (rising_edge(clk_i)) then
                -- Select pattern based on input digit
                if (digit_value_s <= 15) then
                    segment_pattern_s <= SEGMENT_PATTERNS_c(digit_value_s);
                else
                    -- Invalid input, display blank
                    segment_pattern_s <= (others => '0');
                end if;
            end if;
        end if;
    end process segment_proc;

end architecture rtl; 