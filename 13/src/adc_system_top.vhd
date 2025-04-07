--------------------------------------------------------------------------------
-- File: adc_system_top.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Top-level module for the ADC monitoring system.
-- Integrates the ADC controller, simulator, and display controller.
-- Provides a complete system for ADC data acquisition and visualization.
-- Includes user interface for control and configuration.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_system_top is
    generic (
        -- System clock frequency
        CLK_FREQ_HZ_g     : integer := 50_000_000;  -- 50 MHz system clock
        
        -- ADC configuration
        ADC_BITS_g        : integer range 8 to 16 := 12;  -- 12-bit ADC
        ADC_CHANNELS_g    : integer range 1 to 8  := 4;   -- 4 channels
        
        -- SPI configuration
        SPI_FREQ_HZ_g     : integer := 1_000_000;         -- 1 MHz SPI clock
        
        -- Display configuration
        DISPLAY_DIGITS_g  : integer range 2 to 8  := 4     -- 4-digit 7-segment display
    );
    port (
        -- Clock and reset
        clk_i              : in  std_logic;                     -- System clock
        reset_n_i          : in  std_logic;                     -- Active-low reset
        
        -- User interface inputs
        btn_sample_i       : in  std_logic;                     -- Manual sample button
        btn_channel_i      : in  std_logic;                     -- Channel selection button
        btn_mode_i         : in  std_logic;                     -- Display mode button
        sw_auto_sample_i   : in  std_logic;                     -- Auto-sampling enable switch
        sw_threshold_i     : in  std_logic_vector(1 downto 0);  -- Threshold adjust select
        sw_threshold_val_i : in  std_logic_vector(1 downto 0);  -- Threshold value adjust
        
        -- External ADC interface
        spi_cs_n_o         : out std_logic;                     -- SPI chip select
        spi_sclk_o         : out std_logic;                     -- SPI clock
        spi_mosi_o         : out std_logic;                     -- SPI data out
        spi_miso_i         : in  std_logic;                     -- SPI data in
        
        -- Display outputs
        segment_data_o     : out std_logic_vector(7 downto 0);  -- 7-segment data
        digit_sel_o        : out std_logic_vector(DISPLAY_DIGITS_g-1 downto 0); -- Digit select
        led_bar_o          : out std_logic_vector(15 downto 0); -- LED bar display
        
        -- Status outputs
        led_busy_o         : out std_logic;                     -- Conversion in progress
        led_above_thresh_o : out std_logic;                     -- Above threshold indicator
        led_below_thresh_o : out std_logic;                     -- Below threshold indicator
        led_channel_o      : out std_logic_vector(1 downto 0)   -- Current channel indicator
    );
end entity adc_system_top;

architecture rtl of adc_system_top is

    -- Component declarations
    component adc_controller is
        generic (
            CLK_FREQ_HZ_g    : integer := 50_000_000;
            SPI_FREQ_HZ_g    : integer := 1_000_000;
            ADC_BITS_g       : integer range 8 to 16 := 12;
            CHANNELS_g       : integer range 1 to 8  := 1;
            AUTO_SAMPLE_g    : boolean := true;
            SAMPLE_RATE_HZ_g : integer := 1000
        );
        port (
            clk_i            : in  std_logic;
            reset_n_i        : in  std_logic;
            start_conv_i     : in  std_logic;
            channel_select_i : in  integer range 0 to CHANNELS_g-1;
            busy_o           : out std_logic;
            done_o           : out std_logic;
            adc_data_o       : out std_logic_vector(ADC_BITS_g-1 downto 0);
            adc_channel_o    : out integer range 0 to CHANNELS_g-1;
            spi_cs_n_o       : out std_logic;
            spi_sclk_o       : out std_logic;
            spi_mosi_o       : out std_logic;
            spi_miso_i       : in  std_logic;
            debug_state_o    : out std_logic_vector(3 downto 0)
        );
    end component;
    
    component display_controller is
        generic (
            ADC_BITS_g       : integer range 8 to 16 := 12;
            DISPLAY_DIGITS_g : integer range 2 to 8  := 4;
            VREF_MV_g        : integer := 3300;
            USE_CUSTOM_SCALE_g : boolean := false;
            CUSTOM_SCALE_g   : integer := 100;
            CUSTOM_OFFSET_g  : integer := 0;
            CUSTOM_UNIT_CHAR_g : std_logic_vector(7 downto 0) := x"63"
        );
        port (
            clk_i            : in  std_logic;
            reset_n_i        : in  std_logic;
            adc_data_i       : in  std_logic_vector(ADC_BITS_g-1 downto 0);
            data_valid_i     : in  std_logic;
            display_mode_i   : in  std_logic_vector(1 downto 0);
            segment_data_o   : out std_logic_vector(7 downto 0);
            digit_sel_o      : out std_logic_vector(DISPLAY_DIGITS_g-1 downto 0);
            led_bar_o        : out std_logic_vector(15 downto 0);
            threshold_high_i : in  std_logic_vector(ADC_BITS_g-1 downto 0);
            threshold_low_i  : in  std_logic_vector(ADC_BITS_g-1 downto 0);
            above_thresh_o   : out std_logic;
            below_thresh_o   : out std_logic
        );
    end component;
    
    -- For simulation only - this should be commented out when synthesizing for hardware
    -- and using a real external ADC
    component adc_simulator is
        generic (
            ADC_BITS_g       : integer range 8 to 16 := 12;
            CHANNELS_g       : integer range 1 to 8  := 4;
            MAX_AMPLITUDE_g  : integer := 4095;
            SINE_FREQ_HZ_g   : integer := 10;
            TRI_FREQ_HZ_g    : integer := 5;
            RAMP_STEP_g      : integer := 1;
            CLK_FREQ_HZ_g    : integer := 50_000_000
        );
        port (
            clk_i            : in  std_logic;
            reset_n_i        : in  std_logic;
            spi_cs_n_i       : in  std_logic;
            spi_sclk_i       : in  std_logic;
            spi_mosi_i       : in  std_logic;
            spi_miso_o       : out std_logic;
            channel_config_i : in  std_logic_vector(2*CHANNELS_g-1 downto 0);
            noise_enable_i   : in  std_logic;
            noise_amplitude_i : in  integer range 0 to 255;
            current_value_o  : out std_logic_vector(ADC_BITS_g-1 downto 0);
            channel_sel_o    : out integer range 0 to CHANNELS_g-1
        );
    end component;
    
    -- Internal signals
    
    -- ADC controller signals
    signal adc_start_conv    : std_logic;
    signal adc_busy          : std_logic;
    signal adc_done          : std_logic;
    signal adc_data          : std_logic_vector(ADC_BITS_g-1 downto 0);
    signal adc_channel       : integer range 0 to ADC_CHANNELS_g-1;
    signal channel_select    : integer range 0 to ADC_CHANNELS_g-1 := 0;
    signal adc_debug_state   : std_logic_vector(3 downto 0);
    
    -- SPI signals
    signal spi_cs_n          : std_logic;
    signal spi_sclk          : std_logic;
    signal spi_mosi          : std_logic;
    signal spi_miso          : std_logic;
    
    -- Display signals
    signal display_mode      : std_logic_vector(1 downto 0) := "00";  -- Default to raw mode
    signal threshold_high    : std_logic_vector(ADC_BITS_g-1 downto 0) := (others => '1');  -- Default max
    signal threshold_low     : std_logic_vector(ADC_BITS_g-1 downto 0) := (others => '0');  -- Default min
    
    -- Button debouncing and edge detection
    signal btn_sample_prev   : std_logic := '0';
    signal btn_channel_prev  : std_logic := '0';
    signal btn_mode_prev     : std_logic := '0';
    signal btn_sample_pulse  : std_logic;
    signal btn_channel_pulse : std_logic;
    signal btn_mode_pulse    : std_logic;
    
    -- Configuration for simulator (if used)
    signal sim_channel_config : std_logic_vector(2*ADC_CHANNELS_g-1 downto 0) := (others => '0');
    
    -- Auto-sampling control
    signal auto_sample_enable : boolean;
    
begin

    -- Map status outputs
    led_busy_o <= adc_busy;
    led_channel_o <= std_logic_vector(to_unsigned(channel_select, 2));
    
    -- Convert auto-sample switch to boolean
    auto_sample_enable <= (sw_auto_sample_i = '1');
    
    -- Button edge detection for debouncing
    button_edge_detect: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            btn_sample_prev <= '0';
            btn_channel_prev <= '0';
            btn_mode_prev <= '0';
            btn_sample_pulse <= '0';
            btn_channel_pulse <= '0';
            btn_mode_pulse <= '0';
        elsif rising_edge(clk_i) then
            -- Default pulse states
            btn_sample_pulse <= '0';
            btn_channel_pulse <= '0';
            btn_mode_pulse <= '0';
            
            -- Sample button edge detection (rising edge)
            if btn_sample_i = '1' and btn_sample_prev = '0' then
                btn_sample_pulse <= '1';
            end if;
            btn_sample_prev <= btn_sample_i;
            
            -- Channel button edge detection (rising edge)
            if btn_channel_i = '1' and btn_channel_prev = '0' then
                btn_channel_pulse <= '1';
            end if;
            btn_channel_prev <= btn_channel_i;
            
            -- Mode button edge detection (rising edge)
            if btn_mode_i = '1' and btn_mode_prev = '0' then
                btn_mode_pulse <= '1';
            end if;
            btn_mode_prev <= btn_mode_i;
        end if;
    end process button_edge_detect;
    
    -- Channel select handling
    channel_select_proc: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            channel_select <= 0;
        elsif rising_edge(clk_i) then
            if btn_channel_pulse = '1' then
                -- Increment channel and wrap around
                if channel_select = ADC_CHANNELS_g-1 then
                    channel_select <= 0;
                else
                    channel_select <= channel_select + 1;
                end if;
            end if;
        end if;
    end process channel_select_proc;
    
    -- Display mode handling
    display_mode_proc: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            display_mode <= "00";  -- Default to raw mode
        elsif rising_edge(clk_i) then
            if btn_mode_pulse = '1' then
                -- Cycle through display modes
                case display_mode is
                    when "00" =>
                        display_mode <= "01";  -- Raw -> Voltage
                    when "01" =>
                        display_mode <= "10";  -- Voltage -> Custom
                    when "10" =>
                        display_mode <= "11";  -- Custom -> Bar graph
                    when others =>
                        display_mode <= "00";  -- Bar graph -> Raw
                end case;
            end if;
        end if;
    end process display_mode_proc;
    
    -- Threshold handling
    threshold_proc: process(clk_i, reset_n_i)
        variable threshold_high_val : unsigned(ADC_BITS_g-1 downto 0);
        variable threshold_low_val : unsigned(ADC_BITS_g-1 downto 0);
        constant THRESHOLD_STEP : integer := 2**(ADC_BITS_g-4);  -- 1/16 of full scale
    begin
        if reset_n_i = '0' then
            -- Default thresholds: high at 3/4 scale, low at 1/4 scale
            threshold_high <= std_logic_vector(to_unsigned(3 * (2**ADC_BITS_g) / 4, ADC_BITS_g));
            threshold_low <= std_logic_vector(to_unsigned((2**ADC_BITS_g) / 4, ADC_BITS_g));
        elsif rising_edge(clk_i) then
            -- Only adjust thresholds on button press
            if btn_sample_pulse = '1' then
                threshold_high_val := unsigned(threshold_high);
                threshold_low_val := unsigned(threshold_low);
                
                case sw_threshold_i is
                    when "01" =>  -- Adjust high threshold
                        if sw_threshold_val_i = "01" then
                            -- Increase high threshold
                            if threshold_high_val < (2**ADC_BITS_g - 1 - THRESHOLD_STEP) then
                                threshold_high_val := threshold_high_val + THRESHOLD_STEP;
                            end if;
                        elsif sw_threshold_val_i = "10" then
                            -- Decrease high threshold, but keep above low
                            if threshold_high_val > (threshold_low_val + THRESHOLD_STEP) then
                                threshold_high_val := threshold_high_val - THRESHOLD_STEP;
                            end if;
                        end if;
                        
                    when "10" =>  -- Adjust low threshold
                        if sw_threshold_val_i = "01" then
                            -- Increase low threshold, but keep below high
                            if threshold_low_val < (threshold_high_val - THRESHOLD_STEP) then
                                threshold_low_val := threshold_low_val + THRESHOLD_STEP;
                            end if;
                        elsif sw_threshold_val_i = "10" then
                            -- Decrease low threshold
                            if threshold_low_val > THRESHOLD_STEP then
                                threshold_low_val := threshold_low_val - THRESHOLD_STEP;
                            end if;
                        end if;
                        
                    when others =>
                        -- No threshold adjustment
                end case;
                
                threshold_high <= std_logic_vector(threshold_high_val);
                threshold_low <= std_logic_vector(threshold_low_val);
            end if;
        end if;
    end process threshold_proc;
    
    -- Calculate start conversion signal
    adc_start_conv <= btn_sample_pulse when sw_auto_sample_i = '0' else '0';
    
    -- Instantiate ADC controller
    adc_ctrl_inst: adc_controller
        generic map (
            CLK_FREQ_HZ_g    => CLK_FREQ_HZ_g,
            SPI_FREQ_HZ_g    => SPI_FREQ_HZ_g,
            ADC_BITS_g       => ADC_BITS_g,
            CHANNELS_g       => ADC_CHANNELS_g,
            AUTO_SAMPLE_g    => auto_sample_enable,
            SAMPLE_RATE_HZ_g => 10  -- 10 Hz sampling rate in auto mode
        )
        port map (
            clk_i            => clk_i,
            reset_n_i        => reset_n_i,
            start_conv_i     => adc_start_conv,
            channel_select_i => channel_select,
            busy_o           => adc_busy,
            done_o           => adc_done,
            adc_data_o       => adc_data,
            adc_channel_o    => adc_channel,
            spi_cs_n_o       => spi_cs_n,
            spi_sclk_o       => spi_sclk,
            spi_mosi_o       => spi_mosi,
            spi_miso_i       => spi_miso,
            debug_state_o    => adc_debug_state
        );
    
    -- Instantiate display controller
    display_ctrl_inst: display_controller
        generic map (
            ADC_BITS_g       => ADC_BITS_g,
            DISPLAY_DIGITS_g => DISPLAY_DIGITS_g,
            VREF_MV_g        => 3300,  -- 3.3V reference
            USE_CUSTOM_SCALE_g => false,
            CUSTOM_SCALE_g   => 100,
            CUSTOM_OFFSET_g  => 0,
            CUSTOM_UNIT_CHAR_g => x"63"  -- 'c' character
        )
        port map (
            clk_i            => clk_i,
            reset_n_i        => reset_n_i,
            adc_data_i       => adc_data,
            data_valid_i     => adc_done,
            display_mode_i   => display_mode,
            segment_data_o   => segment_data_o,
            digit_sel_o      => digit_sel_o,
            led_bar_o        => led_bar_o,
            threshold_high_i => threshold_high,
            threshold_low_i  => threshold_low,
            above_thresh_o   => led_above_thresh_o,
            below_thresh_o   => led_below_thresh_o
        );
    
    -- For simulation only - this would be commented out in real hardware
    -- where an external ADC is connected
    adc_sim_inst: adc_simulator
        generic map (
            ADC_BITS_g       => ADC_BITS_g,
            CHANNELS_g       => ADC_CHANNELS_g,
            MAX_AMPLITUDE_g  => 2**ADC_BITS_g - 1,
            SINE_FREQ_HZ_g   => 10,
            TRI_FREQ_HZ_g    => 5,
            RAMP_STEP_g      => 1,
            CLK_FREQ_HZ_g    => CLK_FREQ_HZ_g
        )
        port map (
            clk_i            => clk_i,
            reset_n_i        => reset_n_i,
            spi_cs_n_i       => spi_cs_n,
            spi_sclk_i       => spi_sclk,
            spi_mosi_i       => spi_mosi,
            spi_miso_o       => spi_miso,
            channel_config_i => sim_channel_config,
            noise_enable_i   => '1',
            noise_amplitude_i => 64,
            current_value_o  => open,
            channel_sel_o    => open
        );
    
    -- Configure simulator channels with different waveforms
    -- Channel 0: Sine wave
    -- Channel 1: Triangle wave
    -- Channel 2: Ramp wave
    -- Channel 3: Constant value
    sim_channel_config <= "00111001";
    
    -- Connect SPI signals to external pins
    -- In real hardware, the simulator would be removed and these would
    -- connect directly to the external ADC chip
    spi_cs_n_o  <= spi_cs_n;
    spi_sclk_o  <= spi_sclk;
    spi_mosi_o  <= spi_mosi;
    spi_miso    <= spi_miso_i;
    
end architecture rtl; 