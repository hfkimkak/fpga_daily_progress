--------------------------------------------------------------------------------
-- File: motor_control_system.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Top-level module for DC motor speed control system.
-- Integrates PID controller and motor driver modules.
-- Provides user interface for speed control and monitoring.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity motor_control_system is
    generic (
        -- System configuration
        CLK_FREQ_HZ_g     : integer := 50_000_000;  -- System clock frequency
        SAMPLE_FREQ_HZ_g  : integer := 1000;        -- PID update frequency
        PWM_FREQ_HZ_g     : integer := 20000;       -- PWM frequency
        
        -- Data width configuration
        DATA_WIDTH_g      : integer := 16;          -- Width of data signals
        FRAC_WIDTH_g      : integer := 8;           -- Width of fractional part
        
        -- PID parameters (scaled by 2^FRAC_WIDTH_g)
        KP_g             : integer := 32768;        -- Proportional gain (1.0)
        KI_g             : integer := 16384;        -- Integral gain (0.5)
        KD_g             : integer := 8192;         -- Derivative gain (0.25)
        
        -- Motor configuration
        MAX_SPEED_RPM_g   : integer := 3000;        -- Maximum motor speed in RPM
        MIN_SPEED_RPM_g   : integer := 0;           -- Minimum motor speed in RPM
        ENC_COUNTS_PER_REV_g : integer := 1000;     -- Encoder counts per revolution
        DEADBAND_g        : integer := 100          -- PWM deadband value
    );
    port (
        -- Clock and reset
        clk_i            : in  std_logic;
        reset_n_i        : in  std_logic;
        
        -- User interface
        speed_setpoint_i : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
        direction_i      : in  std_logic;           -- '0' for CCW, '1' for CW
        enable_i         : in  std_logic;
        
        -- Encoder interface
        encoder_a_i      : in  std_logic;
        encoder_b_i      : in  std_logic;
        
        -- Motor control outputs
        pwm_out_o        : out std_logic;
        dir_out_o        : out std_logic;
        brake_out_o      : out std_logic;
        
        -- Status outputs
        current_speed_o  : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
        speed_valid_o    : out std_logic;
        error_o          : out std_logic;
        
        -- Debug outputs
        pid_error_o      : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
        pid_output_o     : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
        encoder_count_o  : out std_logic_vector(DATA_WIDTH_g-1 downto 0)
    );
end entity motor_control_system;

architecture rtl of motor_control_system is

    -- Component declarations
    component pid_controller is
        generic (
            CLK_FREQ_HZ_g     : integer;
            SAMPLE_FREQ_HZ_g  : integer;
            DATA_WIDTH_g      : integer;
            FRAC_WIDTH_g      : integer;
            KP_g             : integer;
            KI_g             : integer;
            KD_g             : integer;
            ANTI_WINDUP_g    : boolean;
            WINDUP_LIMIT_g   : integer;
            OUTPUT_MIN_g     : integer;
            OUTPUT_MAX_g     : integer;
            VELOCITY_MODE_g  : boolean
        );
        port (
            clk_i            : in  std_logic;
            reset_n_i        : in  std_logic;
            setpoint_i       : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
            feedback_i       : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
            enable_i         : in  std_logic;
            output_o         : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            valid_o          : out std_logic;
            error_o          : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            integral_o       : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            derivative_o     : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            proportional_o   : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            pid_sum_o        : out std_logic_vector(DATA_WIDTH_g-1 downto 0)
        );
    end component;
    
    component motor_driver is
        generic (
            CLK_FREQ_HZ_g     : integer;
            PWM_FREQ_HZ_g     : integer;
            DATA_WIDTH_g      : integer;
            PWM_RESOLUTION_g  : integer;
            ENC_COUNTS_PER_REV_g : integer;
            SPEED_CALC_PERIOD_g  : integer;
            MAX_SPEED_RPM_g   : integer;
            MIN_SPEED_RPM_g   : integer;
            DEADBAND_g        : integer
        );
        port (
            clk_i            : in  std_logic;
            reset_n_i        : in  std_logic;
            speed_setpoint_i : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
            enable_i         : in  std_logic;
            direction_i      : in  std_logic;
            encoder_a_i      : in  std_logic;
            encoder_b_i      : in  std_logic;
            pwm_out_o        : out std_logic;
            dir_out_o        : out std_logic;
            brake_out_o      : out std_logic;
            current_speed_o  : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            speed_valid_o    : out std_logic;
            error_o          : out std_logic;
            encoder_count_o  : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            pwm_duty_o       : out std_logic_vector(PWM_RESOLUTION_g-1 downto 0)
        );
    end component;
    
    -- Internal signals
    signal pid_output : std_logic_vector(DATA_WIDTH_g-1 downto 0);
    signal pid_valid : std_logic;
    signal pid_error : std_logic_vector(DATA_WIDTH_g-1 downto 0);
    signal current_speed : std_logic_vector(DATA_WIDTH_g-1 downto 0);
    signal speed_valid : std_logic;
    signal motor_error : std_logic;
    signal encoder_count : std_logic_vector(DATA_WIDTH_g-1 downto 0);
    
begin

    -- Map internal signals to outputs
    current_speed_o <= current_speed;
    speed_valid_o <= speed_valid;
    error_o <= motor_error;
    pid_error_o <= pid_error;
    pid_output_o <= pid_output;
    encoder_count_o <= encoder_count;
    
    -- Instantiate PID controller
    pid_inst: pid_controller
        generic map (
            CLK_FREQ_HZ_g     => CLK_FREQ_HZ_g,
            SAMPLE_FREQ_HZ_g  => SAMPLE_FREQ_HZ_g,
            DATA_WIDTH_g      => DATA_WIDTH_g,
            FRAC_WIDTH_g      => FRAC_WIDTH_g,
            KP_g             => KP_g,
            KI_g             => KI_g,
            KD_g             => KD_g,
            ANTI_WINDUP_g    => true,
            WINDUP_LIMIT_g   => 32768,
            OUTPUT_MIN_g     => -32768,
            OUTPUT_MAX_g     => 32767,
            VELOCITY_MODE_g  => true
        )
        port map (
            clk_i            => clk_i,
            reset_n_i        => reset_n_i,
            setpoint_i       => speed_setpoint_i,
            feedback_i       => current_speed,
            enable_i         => enable_i,
            output_o         => pid_output,
            valid_o          => pid_valid,
            error_o          => pid_error,
            integral_o       => open,
            derivative_o     => open,
            proportional_o   => open,
            pid_sum_o        => open
        );
    
    -- Instantiate motor driver
    motor_inst: motor_driver
        generic map (
            CLK_FREQ_HZ_g     => CLK_FREQ_HZ_g,
            PWM_FREQ_HZ_g     => PWM_FREQ_HZ_g,
            DATA_WIDTH_g      => DATA_WIDTH_g,
            PWM_RESOLUTION_g  => 8,
            ENC_COUNTS_PER_REV_g => ENC_COUNTS_PER_REV_g,
            SPEED_CALC_PERIOD_g  => 100000,
            MAX_SPEED_RPM_g   => MAX_SPEED_RPM_g,
            MIN_SPEED_RPM_g   => MIN_SPEED_RPM_g,
            DEADBAND_g        => DEADBAND_g
        )
        port map (
            clk_i            => clk_i,
            reset_n_i        => reset_n_i,
            speed_setpoint_i => pid_output,
            enable_i         => enable_i,
            direction_i      => direction_i,
            encoder_a_i      => encoder_a_i,
            encoder_b_i      => encoder_b_i,
            pwm_out_o        => pwm_out_o,
            dir_out_o        => dir_out_o,
            brake_out_o      => brake_out_o,
            current_speed_o  => current_speed,
            speed_valid_o    => speed_valid,
            error_o          => motor_error,
            encoder_count_o  => encoder_count,
            pwm_duty_o       => open
        );
    
end architecture rtl; 