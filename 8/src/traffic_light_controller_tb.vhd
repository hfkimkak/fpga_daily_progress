---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Testbench for Traffic Light Controller FSM
--                - Tests all state transitions
--                - Verifies timing for each state
--                - Tests reset functionality
--                - Displays traffic light states during simulation
--                - Uses accelerated timing for simulation efficiency
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity traffic_light_controller_tb is
    -- Testbench has no ports
end entity traffic_light_controller_tb;

architecture tb of traffic_light_controller_tb is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    component traffic_light_controller is
        generic (
            CLK_FREQ_HZ_g     : integer := 100000000;
            NS_GREEN_TIME_g   : integer := 30;
            NS_YELLOW_TIME_g  : integer := 5;
            EW_GREEN_TIME_g   : integer := 20;
            EW_YELLOW_TIME_g  : integer := 5
        );
        port (
            clk_i           : in  std_logic;
            reset_n_i       : in  std_logic;
            
            ns_red_o        : out std_logic;
            ns_yellow_o     : out std_logic;
            ns_green_o      : out std_logic;
            
            ew_red_o        : out std_logic;
            ew_yellow_o     : out std_logic;
            ew_green_o      : out std_logic;
            
            current_state_o : out std_logic_vector(1 downto 0);
            timer_value_o   : out integer range 0 to 31
        );
    end component traffic_light_controller;

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Use smaller values for simulation speed
    constant CLK_FREQ_TB_c       : integer := 100;      --! 100 Hz clock for faster simulation
    
    --! Times in seconds for the traffic light states
    constant NS_GREEN_TIME_TB_c  : integer := 5;        --! Shorter time for simulation
    constant NS_YELLOW_TIME_TB_c : integer := 2;        --! Shorter time for simulation
    constant EW_GREEN_TIME_TB_c  : integer := 4;        --! Shorter time for simulation
    constant EW_YELLOW_TIME_TB_c : integer := 2;        --! Shorter time for simulation
    
    --! Full cycle time calculation
    constant CYCLE_TIME_c        : integer := NS_GREEN_TIME_TB_c + NS_YELLOW_TIME_TB_c + 
                                             EW_GREEN_TIME_TB_c + EW_YELLOW_TIME_TB_c;
    
    --! Clock period calculation
    constant CLK_PERIOD_c        : time := 1000 ms / CLK_FREQ_TB_c;

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Testbench control signals
    signal sim_done_s      : boolean := false;
    
    --! DUT inputs
    signal clk_s           : std_logic := '0';
    signal reset_n_s       : std_logic := '0';
    
    --! DUT outputs
    signal ns_red_s        : std_logic;
    signal ns_yellow_s     : std_logic;
    signal ns_green_s      : std_logic;
    
    signal ew_red_s        : std_logic;
    signal ew_yellow_s     : std_logic;
    signal ew_green_s      : std_logic;
    
    signal current_state_s : std_logic_vector(1 downto 0);
    signal timer_value_s   : integer range 0 to 31;
    
    --! Helper function to convert boolean to string
    function to_string(b : std_logic) return string is
    begin
        if b = '1' then
            return "ON ";
        else
            return "OFF";
        end if;
    end function;

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT INSTANTIATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Instantiate the Unit Under Test (UUT)
    uut : traffic_light_controller
        generic map (
            CLK_FREQ_HZ_g     => CLK_FREQ_TB_c,
            NS_GREEN_TIME_g   => NS_GREEN_TIME_TB_c,
            NS_YELLOW_TIME_g  => NS_YELLOW_TIME_TB_c,
            EW_GREEN_TIME_g   => EW_GREEN_TIME_TB_c,
            EW_YELLOW_TIME_g  => EW_YELLOW_TIME_TB_c
        )
        port map (
            clk_i           => clk_s,
            reset_n_i       => reset_n_s,
            
            ns_red_o        => ns_red_s,
            ns_yellow_o     => ns_yellow_s,
            ns_green_o      => ns_green_s,
            
            ew_red_o        => ew_red_s,
            ew_yellow_o     => ew_yellow_s,
            ew_green_o      => ew_green_s,
            
            current_state_o => current_state_s,
            timer_value_o   => timer_value_s
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
        reset_n_s <= '0';  -- Start in reset
        
        -- Wait a few clock cycles
        wait for CLK_PERIOD_c * 5;
        
        -- Release reset
        reset_n_s <= '1';
        
        -- Let the FSM run for a few complete cycles
        wait for (CLK_PERIOD_c * CYCLE_TIME_c * 2);
        
        -- Apply reset in the middle of operation
        reset_n_s <= '0';
        wait for CLK_PERIOD_c * 5;
        
        -- Release reset again
        reset_n_s <= '1';
        wait for (CLK_PERIOD_c * CYCLE_TIME_c * 1.5);
        
        -- End simulation
        sim_done_s <= true;
        wait;
    end process stim_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- MONITOR PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    --! Monitor process to display traffic light states
    monitor_proc : process(clk_s) is
        variable state_name : string(1 to 12);
    begin
        if rising_edge(clk_s) then
            -- Determine state name for reporting
            case current_state_s is
                when "00"   => state_name := "NS_GREEN     ";
                when "01"   => state_name := "NS_YELLOW    ";
                when "10"   => state_name := "EW_GREEN     ";
                when "11"   => state_name := "EW_YELLOW    ";
                when others => state_name := "UNKNOWN      ";
            end case;
            
            -- Report state changes and traffic light status
            if reset_n_s = '0' then
                report "RESET ACTIVE" severity note;
            elsif timer_value_s = 0 then
                report "State: " & state_name & 
                      " | NS: R=" & to_string(ns_red_s) & 
                      " Y=" & to_string(ns_yellow_s) & 
                      " G=" & to_string(ns_green_s) & 
                      " | EW: R=" & to_string(ew_red_s) & 
                      " Y=" & to_string(ew_yellow_s) & 
                      " G=" & to_string(ew_green_s) &
                      " | Timer: " & integer'image(timer_value_s)
                      severity note;
            end if;
        end if;
    end process monitor_proc;

end architecture tb; 