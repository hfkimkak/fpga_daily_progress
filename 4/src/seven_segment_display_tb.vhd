---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Testbench for Seven-Segment Display Controller
--                - Tests all digits from 0-9 and hexadecimal A-F
--                - Verifies correct segment patterns for each digit
--                - Tests both common anode and common cathode configurations
--                - Includes reset functionality testing
--                - Provides detailed test reporting
--                - Automated verification of segment patterns
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- < Add More User Library, If required. >

entity seven_segment_display_tb is
    -- Testbench has no ports
end entity seven_segment_display_tb;

architecture sim of seven_segment_display_tb is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    component seven_segment_display is
        generic (
            COMMON_ANODE_g : boolean := true
        );
        port (
            clk_i      : in  std_logic;
            reset_n_i  : in  std_logic;
            digit_i    : in  std_logic_vector(3 downto 0);
            segments_o : out std_logic_vector(6 downto 0)
        );
    end component seven_segment_display;

    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    type segment_patterns_t is array (0 to 15) of std_logic_vector(6 downto 0); --! Type for segment patterns

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    constant CLK_PERIOD_c : time := 10 ns;  --! 100 MHz clock

    --! Expected segment patterns (active high)
    constant EXPECTED_PATTERNS_c : segment_patterns_t := (
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

    signal clk_s          : std_logic := '0';                    --! Clock signal
    signal reset_n_s      : std_logic := '0';                    --! Reset signal
    signal digit_s        : std_logic_vector(3 downto 0) := (others => '0'); --! Digit input
    signal segments_ca_s  : std_logic_vector(6 downto 0);        --! Common anode output
    signal segments_cc_s  : std_logic_vector(6 downto 0);        --! Common cathode output
    signal sim_done_s     : boolean := false;                    --! Simulation done flag

    --------------------------------------------------------------------------------------------------------------------
    -- ATTRIBUTE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL PART
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT MODULE NAME : DEFINITION
    --------------------------------------------------------------------------------------------------------------------
    
    --! DUT instantiation - Common Anode
    dut_ca_inst : component seven_segment_display
        generic map (
            COMMON_ANODE_g => true
        )
        port map (
            clk_i      => clk_s,
            reset_n_i  => reset_n_s,
            digit_i    => digit_s,
            segments_o => segments_ca_s
        );

    --! DUT instantiation - Common Cathode
    dut_cc_inst : component seven_segment_display
        generic map (
            COMMON_ANODE_g => false
        )
        port map (
            clk_i      => clk_s,
            reset_n_i  => reset_n_s,
            digit_i    => digit_s,
            segments_o => segments_cc_s
        );

    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL PART
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- CLK_GEN_PROC : Clock generation process
    --------------------------------------------------------------------------------------------------------------------
    clk_gen_proc : process is
    begin
        while not sim_done_s loop
            clk_s <= '0';
            wait for CLK_PERIOD_c/2;
            clk_s <= '1';
            wait for CLK_PERIOD_c/2;
        end loop;
        wait;
    end process clk_gen_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- STIM_PROC : Stimulus process
    --------------------------------------------------------------------------------------------------------------------
    stim_proc : process is
    begin
        -- Initial reset
        reset_n_s <= '0';
        wait for 5 * CLK_PERIOD_c;
        reset_n_s <= '1';
        wait for 2 * CLK_PERIOD_c;

        report "Starting Seven-Segment Display Tests...";

        -- Test all digits from 0 to F
        for i in 0 to 15 loop
            digit_s <= std_logic_vector(to_unsigned(i, 4));
            wait for 5 * CLK_PERIOD_c;
            
            -- Verify common anode output (active low)
            assert segments_ca_s = not EXPECTED_PATTERNS_c(i)
                report "Common Anode Test Failed for digit " & integer'image(i) &
                       ". Expected: " & to_string(not EXPECTED_PATTERNS_c(i)) &
                       ", Got: " & to_string(segments_ca_s)
                severity error;
                
            -- Verify common cathode output (active high)
            assert segments_cc_s = EXPECTED_PATTERNS_c(i)
                report "Common Cathode Test Failed for digit " & integer'image(i) &
                       ". Expected: " & to_string(EXPECTED_PATTERNS_c(i)) &
                       ", Got: " & to_string(segments_cc_s)
                severity error;
                
            report "Digit " & integer'image(i) & " tested successfully";
        end loop;

        -- Test reset functionality
        report "Testing reset functionality...";
        reset_n_s <= '0';
        wait for 3 * CLK_PERIOD_c;
        
        -- Verify reset state (should display '0')
        assert segments_ca_s = not EXPECTED_PATTERNS_c(0)
            report "Common Anode Reset Test Failed. Expected: " & 
                   to_string(not EXPECTED_PATTERNS_c(0)) &
                   ", Got: " & to_string(segments_ca_s)
            severity error;
            
        assert segments_cc_s = EXPECTED_PATTERNS_c(0)
            report "Common Cathode Reset Test Failed. Expected: " & 
                   to_string(EXPECTED_PATTERNS_c(0)) &
                   ", Got: " & to_string(segments_cc_s)
            severity error;
            
        reset_n_s <= '1';
        wait for 2 * CLK_PERIOD_c;

        -- End simulation
        report "All tests completed successfully!";
        sim_done_s <= true;
        wait;
    end process stim_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- MONITOR_PROC : Monitor process to check LED patterns
    --------------------------------------------------------------------------------------------------------------------
    monitor_proc : process is
    begin
        wait until rising_edge(clk_s);
        if (reset_n_s = '0') then
            assert segments_ca_s = not EXPECTED_PATTERNS_c(0)
                report "Reset state incorrect for common anode"
                severity error;
                
            assert segments_cc_s = EXPECTED_PATTERNS_c(0)
                report "Reset state incorrect for common cathode"
                severity error;
        end if;
    end process monitor_proc;

end architecture sim; 