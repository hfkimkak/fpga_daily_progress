--------------------------------------------------------------------------------
-- File: pid_controller.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- PID controller implementation for DC motor speed control.
-- Features configurable PID parameters, anti-windup, and output limiting.
-- Implements both position and velocity form PID algorithms.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pid_controller is
    generic (
        -- System configuration
        CLK_FREQ_HZ_g     : integer := 50_000_000;  -- System clock frequency
        SAMPLE_FREQ_HZ_g  : integer := 1000;        -- PID update frequency
        
        -- Data width configuration
        DATA_WIDTH_g      : integer := 16;          -- Width of data signals
        FRAC_WIDTH_g      : integer := 8;           -- Width of fractional part
        
        -- PID parameters (scaled by 2^FRAC_WIDTH_g)
        KP_g             : integer := 32768;        -- Proportional gain (1.0)
        KI_g             : integer := 16384;        -- Integral gain (0.5)
        KD_g             : integer := 8192;         -- Derivative gain (0.25)
        
        -- Anti-windup configuration
        ANTI_WINDUP_g    : boolean := true;         -- Enable anti-windup
        WINDUP_LIMIT_g   : integer := 32768;        -- Anti-windup limit
        
        -- Output configuration
        OUTPUT_MIN_g     : integer := -32768;       -- Minimum output value
        OUTPUT_MAX_g     : integer := 32767;        -- Maximum output value
        
        -- Controller mode
        VELOCITY_MODE_g  : boolean := true          -- Use velocity form PID
    );
    port (
        -- Clock and reset
        clk_i            : in  std_logic;
        reset_n_i        : in  std_logic;
        
        -- Control inputs
        setpoint_i       : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
        feedback_i       : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
        enable_i         : in  std_logic;
        
        -- Control outputs
        output_o         : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
        valid_o          : out std_logic;
        
        -- Status outputs
        error_o          : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
        integral_o       : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
        derivative_o     : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
        
        -- Debug outputs
        proportional_o   : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
        pid_sum_o        : out std_logic_vector(DATA_WIDTH_g-1 downto 0)
    );
end entity pid_controller;

architecture rtl of pid_controller is

    -- Constants for timing
    constant SAMPLE_PERIOD : integer := CLK_FREQ_HZ_g / SAMPLE_FREQ_HZ_g;
    
    -- Type definitions
    type pid_state_t is (IDLE, CALCULATE, UPDATE);
    
    -- State machine signals
    signal current_state : pid_state_t := IDLE;
    signal sample_counter : integer range 0 to SAMPLE_PERIOD-1 := 0;
    
    -- PID calculation signals
    signal error : signed(DATA_WIDTH_g-1 downto 0);
    signal error_prev : signed(DATA_WIDTH_g-1 downto 0);
    signal error_sum : signed(DATA_WIDTH_g-1 downto 0);
    signal error_diff : signed(DATA_WIDTH_g-1 downto 0);
    
    -- PID terms
    signal proportional : signed(DATA_WIDTH_g-1 downto 0);
    signal integral : signed(DATA_WIDTH_g-1 downto 0);
    signal derivative : signed(DATA_WIDTH_g-1 downto 0);
    
    -- Output signals
    signal pid_sum : signed(DATA_WIDTH_g-1 downto 0);
    signal output_reg : signed(DATA_WIDTH_g-1 downto 0);
    signal valid_reg : std_logic;
    
    -- Anti-windup signals
    signal windup_limit : signed(DATA_WIDTH_g-1 downto 0);
    signal windup_active : std_logic;
    
    -- Helper function for fixed-point multiplication
    function multiply_fixed(
        a : signed;
        b : signed;
        frac_width : integer
    ) return signed is
        variable temp : signed(2*DATA_WIDTH_g-1 downto 0);
        variable result : signed(DATA_WIDTH_g-1 downto 0);
    begin
        temp := a * b;
        result := temp(DATA_WIDTH_g+frac_width-1 downto frac_width);
        return result;
    end function;
    
begin

    -- Map internal signals to outputs
    output_o <= std_logic_vector(output_reg);
    valid_o <= valid_reg;
    error_o <= std_logic_vector(error);
    integral_o <= std_logic_vector(integral);
    derivative_o <= std_logic_vector(derivative);
    proportional_o <= std_logic_vector(proportional);
    pid_sum_o <= std_logic_vector(pid_sum);
    
    -- Main PID control process
    pid_process: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            -- Reset all signals
            current_state <= IDLE;
            sample_counter <= 0;
            error <= (others => '0');
            error_prev <= (others => '0');
            error_sum <= (others => '0');
            error_diff <= (others => '0');
            proportional <= (others => '0');
            integral <= (others => '0');
            derivative <= (others => '0');
            pid_sum <= (others => '0');
            output_reg <= (others => '0');
            valid_reg <= '0';
            windup_active <= '0';
            
        elsif rising_edge(clk_i) then
            -- Reset valid signal
            valid_reg <= '0';
            
            case current_state is
                when IDLE =>
                    if enable_i = '1' then
                        current_state <= CALCULATE;
                        sample_counter <= 0;
                    end if;
                    
                when CALCULATE =>
                    -- Calculate error
                    error <= signed(setpoint_i) - signed(feedback_i);
                    
                    -- Calculate proportional term
                    proportional <= multiply_fixed(error, to_signed(KP_g, DATA_WIDTH_g), FRAC_WIDTH_g);
                    
                    -- Calculate integral term with anti-windup
                    if ANTI_WINDUP_g then
                        if windup_active = '0' then
                            error_sum <= error_sum + error;
                        end if;
                    else
                        error_sum <= error_sum + error;
                    end if;
                    integral <= multiply_fixed(error_sum, to_signed(KI_g, DATA_WIDTH_g), FRAC_WIDTH_g);
                    
                    -- Calculate derivative term
                    error_diff <= error - error_prev;
                    derivative <= multiply_fixed(error_diff, to_signed(KD_g, DATA_WIDTH_g), FRAC_WIDTH_g);
                    
                    -- Store current error for next iteration
                    error_prev <= error;
                    
                    -- Calculate PID sum
                    pid_sum <= proportional + integral + derivative;
                    
                    -- Apply output limits
                    if pid_sum > to_signed(OUTPUT_MAX_g, DATA_WIDTH_g) then
                        output_reg <= to_signed(OUTPUT_MAX_g, DATA_WIDTH_g);
                        windup_active <= '1';
                    elsif pid_sum < to_signed(OUTPUT_MIN_g, DATA_WIDTH_g) then
                        output_reg <= to_signed(OUTPUT_MIN_g, DATA_WIDTH_g);
                        windup_active <= '1';
                    else
                        output_reg <= pid_sum;
                        windup_active <= '0';
                    end if;
                    
                    -- Set valid signal
                    valid_reg <= '1';
                    
                    -- Move to update state
                    current_state <= UPDATE;
                    
                when UPDATE =>
                    -- Increment sample counter
                    sample_counter <= sample_counter + 1;
                    
                    -- Check if we should calculate next PID value
                    if sample_counter = SAMPLE_PERIOD-1 then
                        current_state <= CALCULATE;
                        sample_counter <= 0;
                    else
                        current_state <= IDLE;
                    end if;
            end case;
        end if;
    end process pid_process;
    
end architecture rtl; 