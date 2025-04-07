--------------------------------------------------------------------------------
-- File: adc_system_tb.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Testbench for the ADC monitoring system.
-- Simulates the complete system with stimuli for buttons and switches.
-- Tests various ADC acquisition modes and display configurations.
-- Verifies threshold detection and user interaction.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_system_tb is
    -- Testbench has no ports
end entity adc_system_tb;

architecture sim of adc_system_tb is

    -- Component declaration for Unit Under Test (UUT)
    component adc_system_top is
        generic (
            CLK_FREQ_HZ_g     : integer := 50_000_000;
            ADC_BITS_g        : integer range 8 to 16 := 12;
            ADC_CHANNELS_g    : integer range 1 to 8  := 4;
            SPI_FREQ_HZ_g     : integer := 1_000_000;
            DISPLAY_DIGITS_g  : integer range 2 to 8  := 4
        );
        port (
            clk_i              : in  std_logic;
            reset_n_i          : in  std_logic;
            btn_sample_i       : in  std_logic;
            btn_channel_i      : in  std_logic;
            btn_mode_i         : in  std_logic;
            sw_auto_sample_i   : in  std_logic;
            sw_threshold_i     : in  std_logic_vector(1 downto 0);
            sw_threshold_val_i : in  std_logic_vector(1 downto 0);
            spi_cs_n_o         : out std_logic;
            spi_sclk_o         : out std_logic;
            spi_mosi_o         : out std_logic;
            spi_miso_i         : in  std_logic;
            segment_data_o     : out std_logic_vector(7 downto 0);
            digit_sel_o        : out std_logic_vector(DISPLAY_DIGITS_g-1 downto 0);
            led_bar_o          : out std_logic_vector(15 downto 0);
            led_busy_o         : out std_logic;
            led_above_thresh_o : out std_logic;
            led_below_thresh_o : out std_logic;
            led_channel_o      : out std_logic_vector(1 downto 0)
        );
    end component;
    
    -- Constants
    constant CLK_PERIOD       : time := 20 ns;  -- 50MHz clock
    constant SIMULATION_TIME  : time := 50 ms;  -- Total simulation time
    constant ADC_BITS         : integer := 12;
    constant ADC_CHANNELS     : integer := 4;
    constant DISPLAY_DIGITS   : integer := 4;
    
    -- Clock and reset signals
    signal clk                : std_logic := '0';
    signal reset_n            : std_logic := '0';
    signal simulation_done    : boolean := false;
    
    -- Stimulus signals
    signal btn_sample         : std_logic := '0';
    signal btn_channel        : std_logic := '0';
    signal btn_mode           : std_logic := '0';
    signal sw_auto_sample     : std_logic := '0';
    signal sw_threshold       : std_logic_vector(1 downto 0) := "00";
    signal sw_threshold_val   : std_logic_vector(1 downto 0) := "00";
    
    -- External ADC interface
    signal spi_cs_n           : std_logic;
    signal spi_sclk           : std_logic;
    signal spi_mosi           : std_logic;
    signal spi_miso           : std_logic := '0';  -- Default MISO value
    
    -- Output observation signals
    signal segment_data       : std_logic_vector(7 downto 0);
    signal digit_sel          : std_logic_vector(DISPLAY_DIGITS-1 downto 0);
    signal led_bar            : std_logic_vector(15 downto 0);
    signal led_busy           : std_logic;
    signal led_above_thresh   : std_logic;
    signal led_below_thresh   : std_logic;
    signal led_channel        : std_logic_vector(1 downto 0);
    
    -- Helper procedure for button press simulation
    procedure press_button (
        signal btn : out std_logic;
        constant duration : in time := 10 ms
    ) is
    begin
        btn <= '1';
        wait for duration;
        btn <= '0';
        wait for 5 ms;  -- Wait between button presses
    end procedure;
    
begin

    -- Instantiate the Unit Under Test (UUT)
    uut: adc_system_top
        generic map (
            CLK_FREQ_HZ_g     => 50_000_000,   -- Use shortened time periods for simulation
            ADC_BITS_g        => ADC_BITS,
            ADC_CHANNELS_g    => ADC_CHANNELS,
            SPI_FREQ_HZ_g     => 1_000_000,
            DISPLAY_DIGITS_g  => DISPLAY_DIGITS
        )
        port map (
            clk_i              => clk,
            reset_n_i          => reset_n,
            btn_sample_i       => btn_sample,
            btn_channel_i      => btn_channel,
            btn_mode_i         => btn_mode,
            sw_auto_sample_i   => sw_auto_sample,
            sw_threshold_i     => sw_threshold,
            sw_threshold_val_i => sw_threshold_val,
            spi_cs_n_o         => spi_cs_n,
            spi_sclk_o         => spi_sclk,
            spi_mosi_o         => spi_mosi,
            spi_miso_i         => spi_miso,
            segment_data_o     => segment_data,
            digit_sel_o        => digit_sel,
            led_bar_o          => led_bar,
            led_busy_o         => led_busy,
            led_above_thresh_o => led_above_thresh,
            led_below_thresh_o => led_below_thresh,
            led_channel_o      => led_channel
        );
    
    -- Clock generation process
    clk_gen: process
    begin
        while not simulation_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process clk_gen;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Initialize with reset
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait for 1 us;
        
        -- Test Case 1: Manual sampling mode
        report "Test Case 1: Manual Sampling Mode";
        
        -- Press sample button for channel 0
        wait for 5 ms;
        press_button(btn_sample);
        
        -- Change channel to 1
        wait for 5 ms;
        press_button(btn_channel);
        
        -- Press sample button for channel 1
        wait for 5 ms;
        press_button(btn_sample);
        
        -- Test Case 2: Auto sampling mode
        report "Test Case 2: Auto Sampling Mode";
        
        -- Enable auto sampling
        sw_auto_sample <= '1';
        wait for 20 ms;  -- Wait for some samples to be taken
        
        -- Change display mode to voltage
        press_button(btn_mode);
        wait for 5 ms;
        
        -- Change display mode to custom
        press_button(btn_mode);
        wait for 5 ms;
        
        -- Change display mode to bar graph
        press_button(btn_mode);
        wait for 5 ms;
        
        -- Test Case 3: Threshold adjustment
        report "Test Case 3: Threshold Adjustment";
        
        -- Set to adjust high threshold
        sw_threshold <= "01";
        
        -- Increase high threshold
        sw_threshold_val <= "01";
        press_button(btn_sample);
        wait for 5 ms;
        
        -- Decrease high threshold
        sw_threshold_val <= "10";
        press_button(btn_sample);
        wait for 5 ms;
        
        -- Set to adjust low threshold
        sw_threshold <= "10";
        
        -- Increase low threshold
        sw_threshold_val <= "01";
        press_button(btn_sample);
        wait for 5 ms;
        
        -- Decrease low threshold
        sw_threshold_val <= "10";
        press_button(btn_sample);
        wait for 5 ms;
        
        -- Reset threshold adjust
        sw_threshold <= "00";
        sw_threshold_val <= "00";
        
        -- Test Case 4: Channel cycling
        report "Test Case 4: Channel Cycling";
        
        -- Go through all channels
        for i in 0 to ADC_CHANNELS-1 loop
            press_button(btn_channel);
            wait for 5 ms;
        end loop;
        
        -- Test Case 5: Display mode cycling
        report "Test Case 5: Display Mode Cycling";
        
        -- Go through all display modes
        for i in 0 to 3 loop
            press_button(btn_mode);
            wait for 5 ms;
        end loop;
        
        -- Test Case 6: Return to manual mode
        report "Test Case 6: Return to Manual Mode";
        
        -- Disable auto sampling
        sw_auto_sample <= '0';
        wait for 5 ms;
        
        -- Manually sample a few times
        for i in 0 to 2 loop
            press_button(btn_sample);
            wait for 5 ms;
        end loop;
        
        -- End simulation
        wait for 10 ms;
        report "Simulation completed successfully";
        simulation_done <= true;
        wait;
    end process stim_proc;
    
    -- Monitor SPI transactions
    spi_monitor: process
        variable bit_count : integer := 0;
    begin
        wait until falling_edge(spi_cs_n);
        report "SPI transaction started";
        
        -- For simulation purposes, provide a random MISO pattern
        while spi_cs_n = '0' loop
            wait until rising_edge(spi_sclk);
            -- Count bits received on MOSI
            bit_count := bit_count + 1;
            
            -- Toggle MISO on each bit to create test pattern
            wait until falling_edge(spi_sclk);
            spi_miso <= not spi_miso;
        end loop;
        
        report "SPI transaction completed, " & integer'image(bit_count) & " bits transferred";
        bit_count := 0;
        
        -- If simulation end
        if simulation_done then
            wait;
        end if;
    end process spi_monitor;
    
    -- Monitor outputs
    output_monitor: process
    begin
        wait for 1 ms;
        
        while not simulation_done loop
            -- Log current state every 5ms
            wait for 5 ms;
            
            report "Current status: " &
                   "Channel=" & integer'image(to_integer(unsigned(led_channel))) &
                   " Busy=" & std_logic'image(led_busy) &
                   " AboveThr=" & std_logic'image(led_above_thresh) &
                   " BelowThr=" & std_logic'image(led_below_thresh);
        end loop;
        
        wait;
    end process output_monitor;
    
    -- Simulation time limit
    sim_limit: process
    begin
        wait for SIMULATION_TIME;
        report "Simulation time limit reached";
        simulation_done <= true;
        wait;
    end process sim_limit;
    
end architecture sim; 