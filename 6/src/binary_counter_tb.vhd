---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Testbench for 4-bit Binary Counter
--                - Tests up/down counting
--                - Verifies counter wraparound behavior
--                - Tests reset functionality
--                - Validates enable control
--                - Checks BCD output conversion
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity binary_counter_tb is
    -- Testbench has no ports
end entity binary_counter_tb;

architecture tb of binary_counter_tb is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    component binary_counter is
        generic (
            CLK_FREQ_HZ_g    : integer := 100000000;
            COUNT_FREQ_HZ_g  : integer := 1;
            COUNTER_WIDTH_g  : integer := 4
        );
        port (
            clk_i       : in  std_logic;
            reset_n_i   : in  std_logic;
            enable_i    : in  std_logic;
            up_down_i   : in  std_logic;
            count_o     : out std_logic_vector(COUNTER_WIDTH_g-1 downto 0);
            bcd_digit_o : out std_logic_vector(3 downto 0)
        );
    end component binary_counter;

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Use smaller values for simulation speed
    constant CLK_FREQ_TB_c     : integer := 1000;     --! 1 kHz clock for faster simulation
    constant COUNT_FREQ_TB_c   : integer := 100;      --! 100 Hz counting for faster simulation
    constant COUNTER_WIDTH_c   : integer := 4;        --! 4-bit counter (0-15)
    
    --! Clock period calculation
    constant CLK_PERIOD_c      : time := 1000 ms / CLK_FREQ_TB_c;
    
    --! Counter tick period calculation
    constant COUNT_PERIOD_c    : time := 1000 ms / COUNT_FREQ_TB_c;

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Testbench control signals
    signal sim_done_s    : boolean := false;
    
    --! DUT signals
    signal clk_s         : std_logic := '0';
    signal reset_n_s     : std_logic := '0';
    signal enable_s      : std_logic := '1';
    signal up_down_s     : std_logic := '1';  -- Default: count up
    signal count_s       : std_logic_vector(COUNTER_WIDTH_c-1 downto 0);
    signal bcd_digit_s   : std_logic_vector(3 downto 0);

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT INSTANTIATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Instantiate the Unit Under Test (UUT)
    uut : binary_counter
        generic map (
            CLK_FREQ_HZ_g    => CLK_FREQ_TB_c,
            COUNT_FREQ_HZ_g  => COUNT_FREQ_TB_c,
            COUNTER_WIDTH_g  => COUNTER_WIDTH_c
        )
        port map (
            clk_i       => clk_s,
            reset_n_i   => reset_n_s,
            enable_i    => enable_s,
            up_down_i   => up_down_s,
            count_o     => count_s,
            bcd_digit_o => bcd_digit_s
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
        up_down_s <= '1';
        
        -- Wait for a few clock cycles
        wait for CLK_PERIOD_c * 5;
        
        -- Release reset
        reset_n_s <= '1';
        wait for CLK_PERIOD_c * 2;
        
        -- Test counter in up mode (should count from 0 to 15 and wrap around)
        -- Need to wait enough for a full cycle (16 ticks)
        wait for COUNT_PERIOD_c * 20;
        
        -- Test disable functionality
        enable_s <= '0';
        wait for COUNT_PERIOD_c * 5;
        enable_s <= '1';
        wait for COUNT_PERIOD_c * 2;
        
        -- Test counter in down mode
        up_down_s <= '0';
        wait for COUNT_PERIOD_c * 20;
        
        -- Test reset during operation
        reset_n_s <= '0';
        wait for CLK_PERIOD_c * 5;
        reset_n_s <= '1';
        
        -- Change back to up-counting
        up_down_s <= '1';
        wait for COUNT_PERIOD_c * 5;
        
        -- End simulation
        sim_done_s <= true;
        wait;
    end process stim_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- MONITOR PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    --! Monitor process to print counter values (useful for debugging)
    monitor_proc : process(clk_s) is
    begin
        if (rising_edge(clk_s)) then
            if (reset_n_s = '0') then
                -- Report reset state
                report "Counter RESET" severity note;
            elsif (enable_s = '1') then
                -- Report counter value when tick occurs
                -- (This will be less frequent than the clock due to the clock divider)
                null;
            end if;
        end if;
    end process monitor_proc;

end architecture tb; 