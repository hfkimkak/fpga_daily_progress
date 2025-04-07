--------------------------------------------------------------------------------
-- File: motor_control_system_tb.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Testbench for DC motor speed control system.
-- Tests PID controller and motor driver integration.
-- Simulates encoder feedback and verifies speed control.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity motor_control_system_tb is
end entity motor_control_system_tb;

architecture sim of motor_control_system_tb is

    -- Component declaration
    component motor_control_system is
        generic (
            CLK_FREQ_HZ_g     : integer;
            SAMPLE_FREQ_HZ_g  : integer;
            PWM_FREQ_HZ_g     : integer;
            DATA_WIDTH_g      : integer;
            FRAC_WIDTH_g      : integer;
            KP_g             : integer;
            KI_g             : integer;
            KD_g             : integer;
            MAX_SPEED_RPM_g   : integer;
            MIN_SPEED_RPM_g   : integer;
            ENC_COUNTS_PER_REV_g : integer;
            DEADBAND_g        : integer
        );
        port (
            clk_i            : in  std_logic;
            reset_n_i        : in  std_logic;
            speed_setpoint_i : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
            direction_i      : in  std_logic;
            enable_i         : in  std_logic;
            encoder_a_i      : in  std_logic;
            encoder_b_i      : in  std_logic;
            pwm_out_o        : out std_logic;
            dir_out_o        : out std_logic;
            brake_out_o      : out std_logic;
            current_speed_o  : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            speed_valid_o    : out std_logic;
            error_o          : out std_logic;
            pid_error_o      : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            pid_output_o     : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            encoder_count_o  : out std_logic_vector(DATA_WIDTH_g-1 downto 0)
        );
    end component;
    
    -- Constants
    constant CLK_PERIOD_c    : time := 20 ns;       -- 50 MHz clock
    constant SIM_TIME_c      : time := 100 ms;      -- Simulation duration
    
    -- Signals
    signal clk              : std_logic := '0';
    signal reset_n          : std_logic := '1';
    signal speed_setpoint   : std_logic_vector(15 downto 0);
    signal direction        : std_logic := '1';
    signal enable           : std_logic := '0';
    signal encoder_a        : std_logic := '0';
    signal encoder_b        : std_logic := '0';
    signal pwm_out          : std_logic;
    signal dir_out          : std_logic;
    signal brake_out        : std_logic;
    signal current_speed    : std_logic_vector(15 downto 0);
    signal speed_valid      : std_logic;
    signal error_flag       : std_logic;
    signal pid_error        : std_logic_vector(15 downto 0);
    signal pid_output       : std_logic_vector(15 downto 0);
    signal encoder_count    : std_logic_vector(15 downto 0);
    
    -- Encoder simulation signals
    signal encoder_state    : std_logic_vector(1 downto 0) := "00";
    signal encoder_timer    : integer := 0;
    signal target_speed     : integer := 0;
    
begin

    -- Instantiate UUT
    uut: motor_control_system
        generic map (
            CLK_FREQ_HZ_g     => 50_000_000,
            SAMPLE_FREQ_HZ_g  => 1000,
            PWM_FREQ_HZ_g     => 20000,
            DATA_WIDTH_g      => 16,
            FRAC_WIDTH_g      => 8,
            KP_g             => 32768,
            KI_g             => 16384,
            KD_g             => 8192,
            MAX_SPEED_RPM_g   => 3000,
            MIN_SPEED_RPM_g   => 0,
            ENC_COUNTS_PER_REV_g => 1000,
            DEADBAND_g        => 100
        )
        port map (
            clk_i            => clk,
            reset_n_i        => reset_n,
            speed_setpoint_i => speed_setpoint,
            direction_i      => direction,
            enable_i         => enable,
            encoder_a_i      => encoder_a,
            encoder_b_i      => encoder_b,
            pwm_out_o        => pwm_out,
            dir_out_o        => dir_out,
            brake_out_o      => brake_out,
            current_speed_o  => current_speed,
            speed_valid_o    => speed_valid,
            error_o          => error_flag,
            pid_error_o      => pid_error,
            pid_output_o     => pid_output,
            encoder_count_o  => encoder_count
        );
    
    -- Clock generation
    clk <= not clk after CLK_PERIOD_c/2;
    
    -- Encoder simulation process
    process(clk)
        variable encoder_period : integer;
    begin
        if rising_edge(clk) then
            if enable = '1' and target_speed > 0 then
                -- Calculate encoder period based on target speed
                encoder_period := (50_000_000 * 60) / (target_speed * 1000);
                
                -- Update encoder timer
                encoder_timer <= encoder_timer + 1;
                
                -- Generate encoder signals
                if encoder_timer >= encoder_period then
                    encoder_timer <= 0;
                    case encoder_state is
                        when "00" => encoder_state <= "01";
                        when "01" => encoder_state <= "11";
                        when "11" => encoder_state <= "10";
                        when "10" => encoder_state <= "00";
                        when others => encoder_state <= "00";
                    end case;
                    
                    encoder_a <= encoder_state(0);
                    encoder_b <= encoder_state(1);
                end if;
            else
                encoder_timer <= 0;
                encoder_state <= "00";
                encoder_a <= '0';
                encoder_b <= '0';
            end if;
        end if;
    end process;
    
    -- Stimulus process
    process
        -- Procedure declarations
        procedure set_speed(speed_rpm : integer) is
        begin
            target_speed <= speed_rpm;
            speed_setpoint <= std_logic_vector(to_signed(speed_rpm, 16));
        end procedure;
        
        procedure wait_for_stable_speed(timeout : time) is
            variable start_time : time;
            variable prev_speed : integer;
            variable stable_count : integer := 0;
        begin
            start_time := now;
            prev_speed := to_integer(signed(current_speed));
            
            while now - start_time < timeout loop
                if abs(to_integer(signed(current_speed)) - prev_speed) < 10 then
                    stable_count := stable_count + 1;
                    if stable_count >= 100 then
                        exit;
                    end if;
                else
                    stable_count := 0;
                    prev_speed := to_integer(signed(current_speed));
                end if;
                wait for CLK_PERIOD_c;
            end loop;
        end procedure;
    begin
        -- Initialize
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait for 100 ns;
        
        -- Test case 1: Basic speed control
        report "Test case 1: Basic speed control";
        enable <= '1';
        set_speed(1000);
        wait_for_stable_speed(10 ms);
        assert abs(to_integer(signed(current_speed)) - 1000) < 50
            report "Speed control failed" severity failure;
        
        -- Test case 2: Speed change
        report "Test case 2: Speed change";
        set_speed(2000);
        wait_for_stable_speed(10 ms);
        assert abs(to_integer(signed(current_speed)) - 2000) < 50
            report "Speed change failed" severity failure;
        
        -- Test case 3: Direction change
        report "Test case 3: Direction change";
        direction <= '0';
        wait_for_stable_speed(10 ms);
        assert to_integer(signed(current_speed)) < 0
            report "Direction change failed" severity failure;
        
        -- Test case 4: Stop and start
        report "Test case 4: Stop and start";
        enable <= '0';
        wait for 1 ms;
        enable <= '1';
        wait_for_stable_speed(10 ms);
        assert abs(to_integer(signed(current_speed)) + 2000) < 50
            report "Stop and start failed" severity failure;
        
        -- Test case 5: PID response
        report "Test case 5: PID response";
        set_speed(1500);
        wait_for_stable_speed(10 ms);
        assert abs(to_integer(signed(current_speed)) - 1500) < 50
            report "PID response failed" severity failure;
        
        -- End simulation
        wait for 1 ms;
        report "Simulation completed successfully" severity note;
        wait;
    end process;
    
    -- Monitor process
    process
        variable last_time : time := 0 ns;
    begin
        while now < SIM_TIME_c loop
            if now - last_time >= 1 ms then
                report "Time: " & time'image(now) &
                       " Speed: " & integer'image(to_integer(signed(current_speed))) &
                       " RPM, Error: " & integer'image(to_integer(signed(pid_error))) &
                       ", Output: " & integer'image(to_integer(signed(pid_output)));
                last_time := now;
            end if;
            wait for 100 ns;
        end loop;
        wait;
    end process;
    
    -- Simulation time limit
    process
    begin
        wait for SIM_TIME_c;
        report "Simulation time limit reached" severity note;
        wait;
    end process;
    
end architecture sim; 