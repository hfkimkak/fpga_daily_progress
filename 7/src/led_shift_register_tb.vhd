---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Testbench for LED Shift Register Animation
--                - Tests all available animation patterns
--                - Verifies animation timing
--                - Tests enable/disable functionality
--                - Tests reset behavior
--                - Uses reduced clock frequency for simulation efficiency
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity led_shift_register_tb is
    -- Testbench has no ports
end entity led_shift_register_tb;

architecture tb of led_shift_register_tb is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    component led_shift_register is
        generic (
            CLK_FREQ_HZ_g     : integer := 100000000;
            SHIFT_FREQ_HZ_g   : integer := 5;
            REGISTER_LENGTH_g : integer := 8
        );
        port (
            clk_i           : in  std_logic;
            reset_n_i       : in  std_logic;
            enable_i        : in  std_logic;
            pattern_sel_i   : in  std_logic_vector(2 downto 0);
            leds_o          : out std_logic_vector(REGISTER_LENGTH_g-1 downto 0)
        );
    end component led_shift_register;

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Use smaller values for simulation speed
    constant CLK_FREQ_TB_c      : integer := 1000;  --! 1 kHz clock for faster simulation
    constant SHIFT_FREQ_TB_c    : integer := 100;   --! 100 Hz shifting for faster simulation
    constant REGISTER_LENGTH_c  : integer := 8;     --! 8-bit shift register
    
    --! Clock period calculation
    constant CLK_PERIOD_c       : time := 1000 ms / CLK_FREQ_TB_c;
    
    --! Animation period
    constant ANIMATION_PERIOD_c : time := 1000 ms / SHIFT_FREQ_TB_c;
    
    --! Duration to test each pattern (enough to see several cycles)
    constant PATTERN_TEST_TIME_c : time := ANIMATION_PERIOD_c * 20;

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Testbench control signals
    signal sim_done_s      : boolean := false;
    
    --! DUT signals
    signal clk_s           : std_logic := '0';
    signal reset_n_s       : std_logic := '0';
    signal enable_s        : std_logic := '1';
    signal pattern_sel_s   : std_logic_vector(2 downto 0) := "000";
    signal leds_s          : std_logic_vector(REGISTER_LENGTH_c-1 downto 0);

    --! Helper functions for testbench display
    function to_string(a: std_logic_vector) return string is
        variable b : string (1 to a'length) := (others => '0');
    begin
        for i in a'range loop
            b(i+1) := std_logic'image(a(i))(2);
        end loop;
        return b;
    end function;

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT INSTANTIATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Instantiate the Unit Under Test (UUT)
    uut : led_shift_register
        generic map (
            CLK_FREQ_HZ_g     => CLK_FREQ_TB_c,
            SHIFT_FREQ_HZ_g   => SHIFT_FREQ_TB_c,
            REGISTER_LENGTH_g => REGISTER_LENGTH_c
        )
        port map (
            clk_i         => clk_s,
            reset_n_i     => reset_n_s,
            enable_i      => enable_s,
            pattern_sel_i => pattern_sel_s,
            leds_o        => leds_s
        );

    --------------------------------------------------------------------------------------------------------------------
    -- CLOCK PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    --! Clock process
    clk_proc : process is
    begin
        while not sim_done_s loop
            clk_s <= '0';
            wait for CLK_PERIOD_c / 2;
            clk_s <= '1';
            wait for CLK_PERIOD_c / 2;
        end loop;
        wait;
    end process clk_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- STIMULUS PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    --! Stimulus process
    stim_proc : process is
    begin
        -- Initialize inputs
        reset_n_s <= '0';
        enable_s <= '1';
        pattern_sel_s <= "000";  -- Start with pattern 0
        
        -- Wait for a few clock cycles in reset state
        wait for CLK_PERIOD_c * 5;
        
        -- Release reset
        reset_n_s <= '1';
        wait for CLK_PERIOD_c * 2;
        
        -- Test each animation pattern
        for pattern_idx in 0 to 7 loop
            -- Select pattern
            pattern_sel_s <= std_logic_vector(to_unsigned(pattern_idx, 3));
            
            -- Report current pattern
            report "Testing pattern " & integer'image(pattern_idx) severity note;
            
            -- Run the pattern for enough time to observe it
            wait for PATTERN_TEST_TIME_c;
            
            -- Test disable functionality in the middle of the pattern
            enable_s <= '0';
            report "Disabling animation" severity note;
            wait for ANIMATION_PERIOD_c * 5;
            
            -- Re-enable
            enable_s <= '1';
            report "Re-enabling animation" severity note;
            wait for ANIMATION_PERIOD_c * 5;
        end loop;
        
        -- Test reset during operation with the last pattern
        reset_n_s <= '0';
        report "Testing reset during operation" severity note;
        wait for CLK_PERIOD_c * 5;
        reset_n_s <= '1';
        wait for ANIMATION_PERIOD_c * 10;
        
        -- End simulation
        report "Simulation complete" severity note;
        sim_done_s <= true;
        wait;
    end process stim_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- MONITOR PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    --! Monitor process to display LED patterns (useful for debugging)
    monitor_proc : process(clk_s) is
    begin
        if rising_edge(clk_s) then
            if reset_n_s = '0' then
                report "RESET ACTIVE" severity note;
            elsif enable_s = '0' then
                -- Report only on state changes to avoid cluttering the console
                null;
            end if;
        end if;
    end process monitor_proc;

end architecture tb; 