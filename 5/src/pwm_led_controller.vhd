---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  PWM LED Controller
--                - Controls LED brightness using Pulse Width Modulation (PWM)
--                - Features adjustable PWM frequency and duty cycle
--                - Includes active-low reset
--                - Configurable resolution (bits) for duty cycle control
--                - Board-agnostic design for use with any FPGA
--                - Input duty cycle determines LED brightness (0-100%)
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity pwm_led_controller is
    generic (
        CLK_FREQ_HZ_g     : integer := 100000000;  --! System clock frequency in Hz
        PWM_FREQ_HZ_g     : integer := 1000;       --! PWM frequency in Hz
        PWM_RESOLUTION_g  : integer := 8           --! PWM resolution in bits (8 bits = 256 levels)
    );
    port (
        clk_i        : in  std_logic;                                    --! System clock
        reset_n_i    : in  std_logic;                                    --! Active low reset
        
        duty_cycle_i : in  std_logic_vector(PWM_RESOLUTION_g-1 downto 0); --! Duty cycle input (0 to 2^PWM_RESOLUTION_g - 1)
        pwm_out_o    : out std_logic                                     --! PWM output signal
    );
end entity pwm_led_controller;

architecture rtl of pwm_led_controller is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --! Calculate the PWM period count based on clock and PWM frequencies
    constant PWM_PERIOD_COUNT_c   : integer := CLK_FREQ_HZ_g / PWM_FREQ_HZ_g;
    
    --! Maximum value for the PWM counter
    constant PWM_MAX_COUNT_c      : integer := 2**PWM_RESOLUTION_g - 1;
    
    --! Scaling factor for duty cycle
    constant DUTY_SCALING_FACTOR_c : integer := PWM_PERIOD_COUNT_c / PWM_MAX_COUNT_c;

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    signal pwm_counter_s      : integer range 0 to PWM_PERIOD_COUNT_c - 1;      --! PWM counter
    signal threshold_s        : integer range 0 to PWM_PERIOD_COUNT_c - 1;      --! PWM threshold for comparison
    signal duty_cycle_int_s   : integer range 0 to PWM_MAX_COUNT_c;             --! Duty cycle as integer

    --------------------------------------------------------------------------------------------------------------------
    -- ATTRIBUTE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL PART
    --------------------------------------------------------------------------------------------------------------------
    
    --! Convert duty cycle input to integer
    duty_cycle_int_s <= to_integer(unsigned(duty_cycle_i));
    
    --! Calculate threshold from duty cycle (scaled to match PWM period)
    threshold_s <= duty_cycle_int_s * DUTY_SCALING_FACTOR_c;

    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL PART
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- PWM_COUNTER_PROC : PWM counter process
    --------------------------------------------------------------------------------------------------------------------
    pwm_counter_proc : process(clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            pwm_counter_s <= 0;
        elsif (rising_edge(clk_i)) then
            if (pwm_counter_s = PWM_PERIOD_COUNT_c - 1) then
                pwm_counter_s <= 0;  -- Reset counter at end of period
            else
                pwm_counter_s <= pwm_counter_s + 1;
            end if;
        end if;
    end process pwm_counter_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- PWM_OUTPUT_PROC : PWM output generation process
    --------------------------------------------------------------------------------------------------------------------
    pwm_output_proc : process(clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            pwm_out_o <= '0';
        elsif (rising_edge(clk_i)) then
            -- Generate PWM signal by comparing counter with threshold
            if (pwm_counter_s < threshold_s) then
                pwm_out_o <= '1';  -- LED on when counter < threshold
            else
                pwm_out_o <= '0';  -- LED off when counter >= threshold
            end if;
        end if;
    end process pwm_output_proc;

end architecture rtl; 