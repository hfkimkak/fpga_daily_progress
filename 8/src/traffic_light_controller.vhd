---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Traffic Light Controller using Finite State Machine (FSM)
--                - Four states: North-South Green, North-South Yellow, East-West Green, East-West Yellow
--                - Configurable timing for each state
--                - Synchronous reset
--                - Clock divider for seconds timing
--                - Expandable to more complex intersection scenarios
--                - Board-agnostic design for use with any FPGA
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity traffic_light_controller is
    generic (
        CLK_FREQ_HZ_g     : integer := 100000000;  --! System clock frequency in Hz
        NS_GREEN_TIME_g   : integer := 30;         --! North-South green light time in seconds
        NS_YELLOW_TIME_g  : integer := 5;          --! North-South yellow light time in seconds
        EW_GREEN_TIME_g   : integer := 20;         --! East-West green light time in seconds
        EW_YELLOW_TIME_g  : integer := 5           --! East-West yellow light time in seconds
    );
    port (
        clk_i           : in  std_logic;                    --! System clock
        reset_n_i       : in  std_logic;                    --! Active low reset
        
        -- North-South Traffic Lights
        ns_red_o        : out std_logic;                    --! North-South red light
        ns_yellow_o     : out std_logic;                    --! North-South yellow light
        ns_green_o      : out std_logic;                    --! North-South green light
        
        -- East-West Traffic Lights
        ew_red_o        : out std_logic;                    --! East-West red light
        ew_yellow_o     : out std_logic;                    --! East-West yellow light
        ew_green_o      : out std_logic;                    --! East-West green light
        
        -- Optional debug/status outputs
        current_state_o : out std_logic_vector(1 downto 0); --! Current state of FSM
        timer_value_o   : out integer range 0 to 31         --! Current timer value in seconds
    );
end entity traffic_light_controller;

architecture rtl of traffic_light_controller is

    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    -- FSM state definition
    type state_t is (
        NS_GREEN_ST,   --! North-South Green, East-West Red
        NS_YELLOW_ST,  --! North-South Yellow, East-West Red
        EW_GREEN_ST,   --! East-West Green, North-South Red
        EW_YELLOW_ST   --! East-West Yellow, North-South Red
    );

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    -- Clock divider value to generate a 1Hz tick (1 second)
    constant ONE_SECOND_COUNT_c : integer := CLK_FREQ_HZ_g;

    -- State encoding for output
    constant NS_GREEN_ENCODED_c  : std_logic_vector(1 downto 0) := "00";
    constant NS_YELLOW_ENCODED_c : std_logic_vector(1 downto 0) := "01";
    constant EW_GREEN_ENCODED_c  : std_logic_vector(1 downto 0) := "10";
    constant EW_YELLOW_ENCODED_c : std_logic_vector(1 downto 0) := "11";

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    -- FSM signals
    signal current_state_s  : state_t;               --! Current state of the FSM
    signal next_state_s     : state_t;               --! Next state of the FSM
    
    -- Timing signals
    signal clk_div_counter_s : integer range 0 to ONE_SECOND_COUNT_c - 1; --! Clock divider counter
    signal second_tick_s     : std_logic;            --! 1 second tick
    signal timer_s           : integer range 0 to 31; --! Timer for state transitions

    --------------------------------------------------------------------------------------------------------------------
    -- ATTRIBUTE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL PART
    --------------------------------------------------------------------------------------------------------------------
    
    -- Output state for debug/status
    with current_state_s select
        current_state_o <= 
            NS_GREEN_ENCODED_c  when NS_GREEN_ST,
            NS_YELLOW_ENCODED_c when NS_YELLOW_ST,
            EW_GREEN_ENCODED_c  when EW_GREEN_ST,
            EW_YELLOW_ENCODED_c when EW_YELLOW_ST;
    
    -- Timer value output
    timer_value_o <= timer_s;
    
    -- FSM Next State Logic
    next_state_proc : process(current_state_s, timer_s) is
    begin
        -- Default is to stay in current state
        next_state_s <= current_state_s;
        
        -- State transition logic based on timer
        case current_state_s is
            when NS_GREEN_ST =>
                if timer_s = 0 then
                    next_state_s <= NS_YELLOW_ST;
                end if;
                
            when NS_YELLOW_ST =>
                if timer_s = 0 then
                    next_state_s <= EW_GREEN_ST;
                end if;
                
            when EW_GREEN_ST =>
                if timer_s = 0 then
                    next_state_s <= EW_YELLOW_ST;
                end if;
                
            when EW_YELLOW_ST =>
                if timer_s = 0 then
                    next_state_s <= NS_GREEN_ST;
                end if;
                
        end case;
    end process next_state_proc;
    
    -- FSM Output Logic
    output_proc : process(current_state_s) is
    begin
        -- Default all lights off (which should never happen)
        ns_red_o    <= '0';
        ns_yellow_o <= '0';
        ns_green_o  <= '0';
        ew_red_o    <= '0';
        ew_yellow_o <= '0';
        ew_green_o  <= '0';
        
        -- Set lights based on current state
        case current_state_s is
            when NS_GREEN_ST =>
                ns_red_o    <= '0';
                ns_yellow_o <= '0';
                ns_green_o  <= '1';
                ew_red_o    <= '1';
                ew_yellow_o <= '0';
                ew_green_o  <= '0';
                
            when NS_YELLOW_ST =>
                ns_red_o    <= '0';
                ns_yellow_o <= '1';
                ns_green_o  <= '0';
                ew_red_o    <= '1';
                ew_yellow_o <= '0';
                ew_green_o  <= '0';
                
            when EW_GREEN_ST =>
                ns_red_o    <= '1';
                ns_yellow_o <= '0';
                ns_green_o  <= '0';
                ew_red_o    <= '0';
                ew_yellow_o <= '0';
                ew_green_o  <= '1';
                
            when EW_YELLOW_ST =>
                ns_red_o    <= '1';
                ns_yellow_o <= '0';
                ns_green_o  <= '0';
                ew_red_o    <= '0';
                ew_yellow_o <= '1';
                ew_green_o  <= '0';
                
        end case;
    end process output_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL PART
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- CLOCK_DIV_PROC : Clock divider process for 1 second tick generation
    --------------------------------------------------------------------------------------------------------------------
    clock_div_proc : process(clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            clk_div_counter_s <= 0;
            second_tick_s <= '0';
        elsif (rising_edge(clk_i)) then
            -- Default
            second_tick_s <= '0';
            
            -- Increment divider counter
            if (clk_div_counter_s = ONE_SECOND_COUNT_c - 1) then
                clk_div_counter_s <= 0;
                second_tick_s <= '1';  -- Generate tick pulse
            else
                clk_div_counter_s <= clk_div_counter_s + 1;
            end if;
        end if;
    end process clock_div_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- STATE_REG_PROC : FSM state register process
    --------------------------------------------------------------------------------------------------------------------
    state_reg_proc : process(clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            current_state_s <= NS_GREEN_ST;  -- Start with North-South Green
        elsif (rising_edge(clk_i)) then
            current_state_s <= next_state_s;
        end if;
    end process state_reg_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- TIMER_PROC : Timer process for state transitions
    --------------------------------------------------------------------------------------------------------------------
    timer_proc : process(clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            timer_s <= NS_GREEN_TIME_g - 1;  -- Initialize timer for first state
        elsif (rising_edge(clk_i)) then
            -- When state changes, set timer based on the new state
            if (current_state_s /= next_state_s) then
                case next_state_s is
                    when NS_GREEN_ST  => timer_s <= NS_GREEN_TIME_g - 1;
                    when NS_YELLOW_ST => timer_s <= NS_YELLOW_TIME_g - 1;
                    when EW_GREEN_ST  => timer_s <= EW_GREEN_TIME_g - 1;
                    when EW_YELLOW_ST => timer_s <= EW_YELLOW_TIME_g - 1;
                end case;
            -- Decrement timer every second
            elsif (second_tick_s = '1' and timer_s > 0) then
                timer_s <= timer_s - 1;
            end if;
        end if;
    end process timer_proc;

end architecture rtl; 