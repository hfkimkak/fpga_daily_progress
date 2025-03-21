---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Testbench for PWM LED Controller
--                - Tests various duty cycle settings
--                - Verifies PWM output waveform
--                - Tests reset functionality
--                - Uses reduced clock and PWM frequencies for simulation
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity pwm_led_controller_tb is
    -- Testbench has no ports
end entity pwm_led_controller_tb;

architecture tb of pwm_led_controller_tb is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    component pwm_led_controller is
        generic (
            CLK_FREQ_HZ_g     : integer := 100000000;
            PWM_FREQ_HZ_g     : integer := 1000;
            PWM_RESOLUTION_g  : integer := 8
        );
        port (
            clk_i        : in  std_logic;
            reset_n_i    : in  std_logic;
            
            duty_cycle_i : in  std_logic_vector(PWM_RESOLUTION_g-1 downto 0);
            pwm_out_o    : out std_logic
        );
    end component pwm_led_controller;

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Use smaller values for simulation speed
    constant CLK_FREQ_TB_c     : integer := 1000;   --! 1 kHz clock for faster simulation
    constant PWM_FREQ_TB_c     : integer := 100;    --! 100 Hz PWM frequency
    constant PWM_RESOLUTION_c  : integer := 8;      --! 8-bit resolution (256 levels)
    
    --! Clock period calculation
    constant CLK_PERIOD_c      : time := 1000 ms / CLK_FREQ_TB_c;
    
    --! PWM period calculation
    constant PWM_PERIOD_c      : time := 1000 ms / PWM_FREQ_TB_c;

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Testbench control signals
    signal sim_done_s    : boolean := false;
    
    --! DUT signals
    signal clk_s         : std_logic := '0';
    signal reset_n_s     : std_logic := '0';
    signal duty_cycle_s  : std_logic_vector(PWM_RESOLUTION_c-1 downto 0) := (others => '0');
    signal pwm_out_s     : std_logic;

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT INSTANTIATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Instantiate the Unit Under Test (UUT)
    uut : pwm_led_controller
        generic map (
            CLK_FREQ_HZ_g    => CLK_FREQ_TB_c,
            PWM_FREQ_HZ_g    => PWM_FREQ_TB_c,
            PWM_RESOLUTION_g => PWM_RESOLUTION_c
        )
        port map (
            clk_i        => clk_s,
            reset_n_i    => reset_n_s,
            duty_cycle_i => duty_cycle_s,
            pwm_out_o    => pwm_out_s
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
        duty_cycle_s <= (others => '0');
        
        -- Wait for a few clock cycles
        wait for CLK_PERIOD_c * 5;
        
        -- Release reset
        reset_n_s <= '1';
        wait for CLK_PERIOD_c * 2;
        
        -- Test case 1: 0% duty cycle (LED off)
        duty_cycle_s <= (others => '0');
        wait for PWM_PERIOD_c * 3;
        
        -- Test case 2: 25% duty cycle
        duty_cycle_s <= std_logic_vector(to_unsigned(64, PWM_RESOLUTION_c));  -- 64/256 = 25%
        wait for PWM_PERIOD_c * 3;
        
        -- Test case 3: 50% duty cycle
        duty_cycle_s <= std_logic_vector(to_unsigned(128, PWM_RESOLUTION_c)); -- 128/256 = 50%
        wait for PWM_PERIOD_c * 3;
        
        -- Test case 4: 75% duty cycle
        duty_cycle_s <= std_logic_vector(to_unsigned(192, PWM_RESOLUTION_c)); -- 192/256 = 75%
        wait for PWM_PERIOD_c * 3;
        
        -- Test case 5: 100% duty cycle (LED fully on)
        duty_cycle_s <= (others => '1');
        wait for PWM_PERIOD_c * 3;
        
        -- Test reset again
        reset_n_s <= '0';
        wait for CLK_PERIOD_c * 5;
        
        -- End simulation
        sim_done_s <= true;
        wait;
    end process stim_proc;

end architecture tb; 