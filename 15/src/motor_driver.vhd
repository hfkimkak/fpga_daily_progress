--------------------------------------------------------------------------------
-- File: motor_driver.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- DC motor driver module that interfaces with the PID controller.
-- Implements PWM control and direction control for the motor.
-- Includes encoder interface for speed feedback.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity motor_driver is
    generic (
        -- System configuration
        CLK_FREQ_HZ_g     : integer := 50_000_000;  -- System clock frequency
        PWM_FREQ_HZ_g     : integer := 20000;       -- PWM frequency
        
        -- Data width configuration
        DATA_WIDTH_g      : integer := 16;          -- Width of data signals
        
        -- PWM configuration
        PWM_RESOLUTION_g  : integer := 8;           -- PWM resolution in bits
        
        -- Encoder configuration
        ENC_COUNTS_PER_REV_g : integer := 1000;     -- Encoder counts per revolution
        SPEED_CALC_PERIOD_g  : integer := 100000;   -- Speed calculation period in clock cycles
        
        -- Motor configuration
        MAX_SPEED_RPM_g   : integer := 3000;        -- Maximum motor speed in RPM
        MIN_SPEED_RPM_g   : integer := 0;           -- Minimum motor speed in RPM
        DEADBAND_g        : integer := 100          -- PWM deadband value
    );
    port (
        -- Clock and reset
        clk_i            : in  std_logic;
        reset_n_i        : in  std_logic;
        
        -- Control interface
        speed_setpoint_i : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
        enable_i         : in  std_logic;
        direction_i      : in  std_logic;           -- '0' for CCW, '1' for CW
        
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
        encoder_count_o  : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
        pwm_duty_o       : out std_logic_vector(PWM_RESOLUTION_g-1 downto 0)
    );
end entity motor_driver;

architecture rtl of motor_driver is

    -- Constants for timing
    constant PWM_PERIOD : integer := CLK_FREQ_HZ_g / PWM_FREQ_HZ_g;
    
    -- Type definitions
    type motor_state_t is (IDLE, RUNNING, BRAKING, ERROR);
    
    -- State machine signals
    signal current_state : motor_state_t := IDLE;
    
    -- PWM signals
    signal pwm_counter : integer range 0 to PWM_PERIOD-1 := 0;
    signal pwm_duty : unsigned(PWM_RESOLUTION_g-1 downto 0) := (others => '0');
    signal pwm_out_reg : std_logic;
    
    -- Encoder signals
    signal encoder_count : signed(DATA_WIDTH_g-1 downto 0) := (others => '0');
    signal encoder_a_prev : std_logic;
    signal encoder_b_prev : std_logic;
    signal encoder_a_curr : std_logic;
    signal encoder_b_curr : std_logic;
    
    -- Speed calculation signals
    signal speed_counter : integer range 0 to SPEED_CALC_PERIOD_g-1 := 0;
    signal speed_reg : signed(DATA_WIDTH_g-1 downto 0) := (others => '0');
    signal speed_valid_reg : std_logic;
    
    -- Error detection signals
    signal error_reg : std_logic;
    signal stall_counter : integer range 0 to 1000000 := 0;
    
    -- Helper function to calculate RPM from encoder count
    function calculate_rpm(
        count : signed;
        period : integer;
        counts_per_rev : integer;
        clk_freq : integer
    ) return signed is
        variable rpm : signed(DATA_WIDTH_g-1 downto 0);
    begin
        -- RPM = (count * 60 * clk_freq) / (period * counts_per_rev)
        rpm := resize(shift_right(count * to_signed(60 * clk_freq / counts_per_rev, DATA_WIDTH_g), 
                     integer(ceil(log2(real(period))))), DATA_WIDTH_g);
        return rpm;
    end function;
    
begin

    -- Map internal signals to outputs
    pwm_out_o <= pwm_out_reg;
    dir_out_o <= direction_i;
    brake_out_o <= '1' when current_state = BRAKING else '0';
    current_speed_o <= std_logic_vector(speed_reg);
    speed_valid_o <= speed_valid_reg;
    error_o <= error_reg;
    encoder_count_o <= std_logic_vector(encoder_count);
    pwm_duty_o <= std_logic_vector(pwm_duty);
    
    -- Main motor control process
    motor_control: process(clk_i, reset_n_i)
        variable speed_setpoint_abs : unsigned(DATA_WIDTH_g-1 downto 0);
        variable prev_encoder_count : signed(DATA_WIDTH_g-1 downto 0);
        variable encoder_diff : signed(DATA_WIDTH_g-1 downto 0);
    begin
        if reset_n_i = '0' then
            -- Reset all signals
            current_state <= IDLE;
            pwm_counter <= 0;
            pwm_duty <= (others => '0');
            pwm_out_reg <= '0';
            encoder_count <= (others => '0');
            encoder_a_prev <= '0';
            encoder_b_prev <= '0';
            encoder_a_curr <= '0';
            encoder_b_curr <= '0';
            speed_counter <= 0;
            speed_reg <= (others => '0');
            speed_valid_reg <= '0';
            error_reg <= '0';
            stall_counter <= 0;
            prev_encoder_count := (others => '0');
            
        elsif rising_edge(clk_i) then
            -- Reset status signals
            speed_valid_reg <= '0';
            
            -- Update encoder state
            encoder_a_curr <= encoder_a_i;
            encoder_b_curr <= encoder_b_i;
            
            -- Detect encoder edges and count pulses
            if (encoder_a_curr /= encoder_a_prev) or (encoder_b_curr /= encoder_b_prev) then
                -- Determine direction based on encoder signals
                if (encoder_a_curr = '1' and encoder_b_curr = '0') or 
                   (encoder_a_curr = '0' and encoder_b_curr = '1') then
                    -- Forward movement
                    if direction_i = '1' then
                        encoder_count <= encoder_count + 1;
                    else
                        encoder_count <= encoder_count - 1;
                    end if;
                else
                    -- Reverse movement
                    if direction_i = '1' then
                        encoder_count <= encoder_count - 1;
                    else
                        encoder_count <= encoder_count + 1;
                    end if;
                end if;
                
                -- Reset stall counter on encoder activity
                stall_counter <= 0;
            end if;
            
            -- Save previous encoder state
            encoder_a_prev <= encoder_a_curr;
            encoder_b_prev <= encoder_b_curr;
            
            -- Handle state machine
            case current_state is
                when IDLE =>
                    -- Reset outputs
                    pwm_out_reg <= '0';
                    pwm_duty <= (others => '0');
                    
                    -- Enter running state when enabled
                    if enable_i = '1' then
                        current_state <= RUNNING;
                        encoder_count <= (others => '0');
                        prev_encoder_count := (others => '0');
                    end if;
                    
                when RUNNING =>
                    -- Get absolute speed setpoint
                    speed_setpoint_abs := unsigned(abs(signed(speed_setpoint_i)));
                    
                    -- Scale setpoint to PWM duty cycle
                    pwm_duty <= resize(shift_right(speed_setpoint_abs * (2**PWM_RESOLUTION_g - 1), DATA_WIDTH_g - 2), PWM_RESOLUTION_g);
                    
                    -- Apply deadband
                    if pwm_duty < to_unsigned(DEADBAND_g, PWM_RESOLUTION_g) then
                        pwm_duty <= (others => '0');
                    end if;
                    
                    -- Generate PWM output
                    if pwm_counter < to_integer(pwm_duty) then
                        pwm_out_reg <= '1';
                    else
                        pwm_out_reg <= '0';
                    end if;
                    
                    -- Update PWM counter
                    if pwm_counter >= PWM_PERIOD-1 then
                        pwm_counter <= 0;
                    else
                        pwm_counter <= pwm_counter + 1;
                    end if;
                    
                    -- Calculate speed
                    if speed_counter >= SPEED_CALC_PERIOD_g-1 then
                        -- Calculate encoder count difference
                        encoder_diff := encoder_count - prev_encoder_count;
                        prev_encoder_count := encoder_count;
                        
                        -- Calculate speed in RPM
                        speed_reg <= calculate_rpm(encoder_diff, SPEED_CALC_PERIOD_g, ENC_COUNTS_PER_REV_g, CLK_FREQ_HZ_g);
                        
                        -- Set speed valid
                        speed_valid_reg <= '1';
                        
                        -- Detect stall condition
                        if enable_i = '1' and pwm_duty > to_unsigned(DEADBAND_g, PWM_RESOLUTION_g) then
                            if encoder_diff = 0 then
                                stall_counter <= stall_counter + 1;
                                if stall_counter > 10 then  -- Stall detected after 10 periods
                                    error_reg <= '1';
                                    current_state <= ERROR;
                                end if;
                            else
                                stall_counter <= 0;
                            end if;
                        end if;
                        
                        -- Reset counter
                        speed_counter <= 0;
                    else
                        speed_counter <= speed_counter + 1;
                    end if;
                    
                    -- Handle disable condition
                    if enable_i = '0' then
                        current_state <= BRAKING;
                    end if;
                    
                when BRAKING =>
                    -- Stop motor
                    pwm_out_reg <= '0';
                    pwm_duty <= (others => '0');
                    
                    -- Check if motor has stopped
                    if abs(speed_reg) < 10 then
                        current_state <= IDLE;
                    end if;
                    
                when ERROR =>
                    -- Handle error condition
                    pwm_out_reg <= '0';
                    pwm_duty <= (others => '0');
                    
                    -- Clear error when disabled
                    if enable_i = '0' then
                        error_reg <= '0';
                        current_state <= IDLE;
                    end if;
            end case;
        end if;
    end process motor_control;
    
end architecture rtl; 