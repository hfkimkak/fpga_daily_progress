--------------------------------------------------------------------------------
-- File: i2c_system_tb.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Testbench for I²C temperature monitoring system. This testbench creates a 
-- complete system with the temperature reader and LM75 temperature sensor
-- connected via I²C. It tests the entire temperature reading workflow and
-- verifies correct operation of the system.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_system_tb is
    -- Empty entity for testbench
end entity i2c_system_tb;

architecture sim of i2c_system_tb is
    -- Clock and reset signals
    constant CLK_PERIOD      : time := 10 ns;  -- 100 MHz system clock
    signal clk_s             : std_logic := '0';
    signal reset_n_s         : std_logic := '0';
    
    -- I²C signals (shared between modules)
    signal i2c_scl_s         : std_logic;
    signal i2c_sda_s         : std_logic;
    
    -- Temperature reader signals
    signal start_read_s      : std_logic := '0';
    signal temp_data_s       : std_logic_vector(15 downto 0);
    signal temp_valid_s      : std_logic;
    signal i2c_busy_s        : std_logic;
    signal error_s           : std_logic;
    signal segments_s        : std_logic_vector(7 downto 0);
    signal digits_s          : std_logic_vector(3 downto 0);
    signal temp_sign_s       : std_logic;
    
    -- Test control
    signal sim_done          : boolean := false;
    
    -- Constants
    constant I2C_SLAVE_ADDR  : std_logic_vector(6 downto 0) := "1001000";  -- 0x48
    constant TEMP_UPDATE_MS  : integer := 10;  -- Speed up for simulation
    
    -- Pull-up resistors for I²C lines (idle high)
    signal i2c_scl_pull      : std_logic := 'H';
    signal i2c_sda_pull      : std_logic := 'H';

    -- Components
    component i2c_temp_reader is
        generic (
            CLK_FREQ_HZ       : integer := 100_000_000;
            I2C_CLK_FREQ_HZ   : integer := 400_000;
            I2C_SLAVE_ADDR    : std_logic_vector(6 downto 0) := "1001000";
            TEMP_UPDATE_MS    : integer := 1000
        );
        port (
            -- Clock and reset
            clk_i             : in  std_logic;
            reset_n_i         : in  std_logic;
            
            -- I²C interface
            i2c_scl_io        : inout std_logic;
            i2c_sda_io        : inout std_logic;
            
            -- User interface
            start_read_i      : in  std_logic;
            temp_data_o       : out std_logic_vector(15 downto 0);
            temp_valid_o      : out std_logic;
            temp_sign_o       : out std_logic;
            i2c_busy_o        : out std_logic;
            error_o           : out std_logic;
            
            -- Display interface (7-segment)
            segments_o        : out std_logic_vector(7 downto 0);
            digits_o          : out std_logic_vector(3 downto 0)
        );
    end component;
    
    component i2c_temp_sensor is
        generic (
            I2C_SLAVE_ADDR    : std_logic_vector(6 downto 0) := "1001000";
            DEFAULT_TEMP      : integer := 25;                -- 25°C
            TEMP_STEP         : integer := 1;                 -- 1°C steps
            MAX_TEMP          : integer := 85;                -- Maximum temperature
            MIN_TEMP          : integer := -25                -- Minimum temperature
        );
        port (
            -- Clock and reset
            clk_i             : in  std_logic;
            reset_n_i         : in  std_logic;
            
            -- I²C interface
            i2c_scl_io        : inout std_logic;
            i2c_sda_io        : inout std_logic
        );
    end component;
    
begin
    -- Clock generation
    clk_s <= not clk_s after CLK_PERIOD/2 when not sim_done else '0';
    
    -- Reset generation
    reset_proc: process
    begin
        reset_n_s <= '0';
        wait for 100 ns;
        reset_n_s <= '1';
        wait;
    end process reset_proc;
    
    -- I²C pull-up resistors simulation
    i2c_scl_s <= 'H';
    i2c_sda_s <= 'H';
    
    -- Instantiate the Temperature Reader
    temp_reader_inst: i2c_temp_reader
        generic map (
            CLK_FREQ_HZ       => 100_000_000,
            I2C_CLK_FREQ_HZ   => 400_000,     -- Fast-mode I²C
            I2C_SLAVE_ADDR    => I2C_SLAVE_ADDR,
            TEMP_UPDATE_MS    => TEMP_UPDATE_MS
        )
        port map (
            clk_i             => clk_s,
            reset_n_i         => reset_n_s,
            i2c_scl_io        => i2c_scl_s,
            i2c_sda_io        => i2c_sda_s,
            start_read_i      => start_read_s,
            temp_data_o       => temp_data_s,
            temp_valid_o      => temp_valid_s,
            temp_sign_o       => temp_sign_s,
            i2c_busy_o        => i2c_busy_s,
            error_o           => error_s,
            segments_o        => segments_s,
            digits_o          => digits_s
        );
    
    -- Instantiate the Temperature Sensor
    temp_sensor_inst: i2c_temp_sensor
        generic map (
            I2C_SLAVE_ADDR    => I2C_SLAVE_ADDR,
            DEFAULT_TEMP      => 25,
            TEMP_STEP         => 1,
            MAX_TEMP          => 85,
            MIN_TEMP          => -10
        )
        port map (
            clk_i             => clk_s,
            reset_n_i         => reset_n_s,
            i2c_scl_io        => i2c_scl_s,
            i2c_sda_io        => i2c_sda_s
        );
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Initial state
        start_read_s <= '0';
        wait for 200 ns;
        
        -- Wait for reset to complete
        wait until reset_n_s = '1';
        wait for 500 ns;
        
        -- Trigger first temperature read
        wait until rising_edge(clk_s);
        start_read_s <= '1';
        wait until rising_edge(clk_s);
        start_read_s <= '0';
        
        -- Wait for read to complete
        wait until temp_valid_s = '1';
        
        -- Log the result
        report "Temperature read: " & integer'image(to_integer(signed(temp_data_s))) & 
               " (raw value)";
        
        -- Verify no errors occurred
        assert error_s = '0'
            report "Error detected during temperature read operation!"
            severity error;
        
        -- Wait for a while
        wait for 10 us;
        
        -- Perform a few more automatic reads
        for i in 1 to 3 loop
            -- Wait for the automatic temperature update
            wait until temp_valid_s = '1';
            
            -- Log the result
            report "Temperature update " & integer'image(i) & 
                   ": " & integer'image(to_integer(signed(temp_data_s))) & 
                   " (raw value)";
            
            -- Verify no errors
            assert error_s = '0'
                report "Error detected during temperature update " & integer'image(i) & "!"
                severity error;
            
            -- Wait a bit after each read
            wait for 5 us;
        end loop;
        
        -- End simulation
        report "Testbench completed successfully";
        sim_done <= true;
        wait;
    end process stim_proc;
    
end architecture sim; 