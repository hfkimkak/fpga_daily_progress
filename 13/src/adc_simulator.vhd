--------------------------------------------------------------------------------
-- File: adc_simulator.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- ADC Simulator module for testing the ADC controller.
-- Generates SPI responses that emulate a real ADC device.
-- Produces configurable waveforms (sine, triangle, ramp, constant) for testing.
-- Simulates multi-channel ADC behavior with independent signals per channel.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;  -- For sine wave generation

entity adc_simulator is
    generic (
        -- ADC configuration
        ADC_BITS_g       : integer range 8 to 16 := 12;   -- ADC resolution (bits)
        CHANNELS_g       : integer range 1 to 8  := 4;    -- Number of ADC channels
        
        -- Waveform parameters
        MAX_AMPLITUDE_g  : integer := 4095;  -- Maximum amplitude for 12-bit (2^12-1)
        SINE_FREQ_HZ_g   : integer := 10;    -- Frequency of sine wave (Hz)
        TRI_FREQ_HZ_g    : integer := 5;     -- Frequency of triangle wave (Hz)
        RAMP_STEP_g      : integer := 1;     -- Step size for ramp wave
        CLK_FREQ_HZ_g    : integer := 50_000_000  -- System clock frequency (Hz)
    );
    port (
        -- Clock and reset
        clk_i             : in  std_logic;
        reset_n_i         : in  std_logic;
        
        -- SPI interface (slave side)
        spi_cs_n_i        : in  std_logic;  -- Chip select (active low)
        spi_sclk_i        : in  std_logic;  -- Serial clock
        spi_mosi_i        : in  std_logic;  -- Master out slave in
        spi_miso_o        : out std_logic;  -- Master in slave out
        
        -- Debug/Control
        channel_config_i  : in  std_logic_vector(2*CHANNELS_g-1 downto 0);  -- 2 bits per channel to select waveform
        noise_enable_i    : in  std_logic;  -- Enable noise on signals
        noise_amplitude_i : in  integer range 0 to 255;  -- Noise amplitude
        
        -- Debug outputs
        current_value_o   : out std_logic_vector(ADC_BITS_g-1 downto 0);  -- Current value for debug
        channel_sel_o     : out integer range 0 to CHANNELS_g-1  -- Selected channel for debug
    );
end entity adc_simulator;

architecture rtl of adc_simulator is

    -- Waveform type enumeration
    type waveform_t is (
        CONSTANT_WAVE,   -- Fixed value
        SINE_WAVE,       -- Sine wave
        TRIANGLE_WAVE,   -- Triangle wave
        RAMP_WAVE        -- Ramp/sawtooth wave
    );
    
    -- Array type for channel waveform configuration
    type channel_config_array_t is array(0 to CHANNELS_g-1) of waveform_t;
    signal channel_config : channel_config_array_t;
    
    -- Array for channel values
    type channel_value_array_t is array(0 to CHANNELS_g-1) of integer range 0 to MAX_AMPLITUDE_g;
    signal channel_values : channel_value_array_t;
    
    -- SPI transaction signals
    signal spi_rx_data   : std_logic_vector(15 downto 0);  -- Data received from ADC controller
    signal spi_tx_data   : std_logic_vector(15 downto 0);  -- Data to send to ADC controller
    signal spi_bit_count : integer range 0 to 16;          -- Bit counter for SPI transfer
    signal spi_active    : std_logic;                      -- SPI transaction active flag
    
    -- Waveform generation signals
    signal counter       : integer range 0 to CLK_FREQ_HZ_g-1 := 0;
    signal update_tick   : std_logic;  -- Tick signal for updating waveforms
    signal sine_sample   : integer range 0 to MAX_AMPLITUDE_g;
    signal triangle_sample : integer range 0 to MAX_AMPLITUDE_g;
    signal ramp_sample   : integer range 0 to MAX_AMPLITUDE_g := 0;
    
    -- Selected channel
    signal channel_select : integer range 0 to CHANNELS_g-1 := 0;
    
    -- Random number for noise generation
    signal random_value : integer range -255 to 255 := 0;
    -- Seeds are moved to process variables for random number generation

begin

    -- Map waveform configuration from input port
    -- Each channel has 2 bits of configuration in channel_config_i
    process(channel_config_i)
    begin
        for i in 0 to CHANNELS_g-1 loop
            case channel_config_i(2*i+1 downto 2*i) is
                when "00" => channel_config(i) <= CONSTANT_WAVE;
                when "01" => channel_config(i) <= SINE_WAVE;
                when "10" => channel_config(i) <= TRIANGLE_WAVE;
                when "11" => channel_config(i) <= RAMP_WAVE;
                when others => channel_config(i) <= CONSTANT_WAVE;
            end case;
        end loop;
    end process;
    
    -- Waveform update ticker (at 1kHz)
    process(clk_i, reset_n_i)
        constant UPDATE_LIMIT : integer := CLK_FREQ_HZ_g / 1000;  -- 1kHz update rate
    begin
        if reset_n_i = '0' then
            counter <= 0;
            update_tick <= '0';
        elsif rising_edge(clk_i) then
            update_tick <= '0';  -- Default
            
            if counter = UPDATE_LIMIT-1 then
                counter <= 0;
                update_tick <= '1';
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;
    
    -- Pseudo-random number generator for noise
    process(clk_i, reset_n_i)
        variable rand : real;
        variable seed1, seed2 : positive := 1;  -- Seeds for random number as variables
    begin
        if reset_n_i = '0' then
            random_value <= 0;
            seed1 := 1;
            seed2 := 1;
        elsif rising_edge(clk_i) then
            if update_tick = '1' then
                -- Generate uniform random number
                uniform(seed1, seed2, rand);
                -- Scale to -noise_amplitude to +noise_amplitude
                random_value <= integer(rand * real(2*noise_amplitude_i)) - noise_amplitude_i;
            end if;
        end if;
    end process;

    -- Sine wave generator
    process(clk_i, reset_n_i)
        variable time_counter : integer := 0;
        variable sine_arg : real := 0.0;
        variable sine_value : real := 0.0;
        constant SINE_PERIOD : integer := CLK_FREQ_HZ_g / (1000 * SINE_FREQ_HZ_g);  -- In ticks at 1kHz
    begin
        if reset_n_i = '0' then
            time_counter := 0;
            sine_sample <= MAX_AMPLITUDE_g / 2;  -- Mid-scale
        elsif rising_edge(clk_i) then
            if update_tick = '1' then
                -- Calculate sine value
                sine_arg := real(time_counter) * 2.0 * MATH_PI / real(SINE_PERIOD);
                sine_value := sin(sine_arg);
                
                -- Scale and offset to fit ADC range
                sine_sample <= integer((sine_value + 1.0) * real(MAX_AMPLITUDE_g) / 2.0);
                
                -- Increment counter
                if time_counter = SINE_PERIOD-1 then
                    time_counter := 0;
                else
                    time_counter := time_counter + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Triangle wave generator
    process(clk_i, reset_n_i)
        variable time_counter : integer := 0;
        variable direction : std_logic := '1';  -- '1' for up, '0' for down
        variable triangle_value : integer := 0;
        constant TRI_PERIOD : integer := CLK_FREQ_HZ_g / (1000 * TRI_FREQ_HZ_g * 2);  -- Half period in ticks at 1kHz
    begin
        if reset_n_i = '0' then
            time_counter := 0;
            direction := '1';
            triangle_sample <= 0;
        elsif rising_edge(clk_i) then
            if update_tick = '1' then
                if direction = '1' then
                    -- Increasing phase
                    triangle_value := triangle_value + MAX_AMPLITUDE_g / TRI_PERIOD;
                    if triangle_value >= MAX_AMPLITUDE_g then
                        triangle_value := MAX_AMPLITUDE_g;
                        direction := '0';  -- Change direction
                    end if;
                else
                    -- Decreasing phase
                    triangle_value := triangle_value - MAX_AMPLITUDE_g / TRI_PERIOD;
                    if triangle_value <= 0 then
                        triangle_value := 0;
                        direction := '1';  -- Change direction
                    end if;
                end if;
                
                triangle_sample <= triangle_value;
            end if;
        end if;
    end process;
    
    -- Ramp wave generator
    process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            ramp_sample <= 0;
        elsif rising_edge(clk_i) then
            if update_tick = '1' then
                if ramp_sample >= MAX_AMPLITUDE_g - RAMP_STEP_g then
                    ramp_sample <= 0;  -- Reset to 0 when max reached
                else
                    ramp_sample <= ramp_sample + RAMP_STEP_g;
                end if;
            end if;
        end if;
    end process;
    
    -- Assign waveforms to channels based on configuration
    process(clk_i, reset_n_i)
        variable noisy_value : integer;
    begin
        if reset_n_i = '0' then
            for i in 0 to CHANNELS_g-1 loop
                channel_values(i) <= MAX_AMPLITUDE_g / 2;  -- Initialize to mid-scale
            end loop;
        elsif rising_edge(clk_i) then
            if update_tick = '1' then
                for i in 0 to CHANNELS_g-1 loop
                    -- Select basic waveform based on channel configuration
                    case channel_config(i) is
                        when CONSTANT_WAVE =>
                            noisy_value := MAX_AMPLITUDE_g / 2;  -- Mid-scale
                        when SINE_WAVE =>
                            noisy_value := sine_sample;
                        when TRIANGLE_WAVE =>
                            noisy_value := triangle_sample;
                        when RAMP_WAVE =>
                            noisy_value := ramp_sample;
                        when others =>
                            noisy_value := MAX_AMPLITUDE_g / 2;
                    end case;
                    
                    -- Add noise if enabled
                    if noise_enable_i = '1' then
                        noisy_value := noisy_value + random_value;
                        
                        -- Clamp to valid range
                        if noisy_value < 0 then
                            noisy_value := 0;
                        elsif noisy_value > MAX_AMPLITUDE_g then
                            noisy_value := MAX_AMPLITUDE_g;
                        end if;
                    end if;
                    
                    -- Assign to channel
                    channel_values(i) <= noisy_value;
                end loop;
            end if;
        end if;
    end process;
    
    -- SPI Slave Interface
    -- Handle incoming commands and return ADC data
    spi_slave_proc: process(clk_i, reset_n_i)
        variable edge_detect : std_logic_vector(1 downto 0) := "00";
        variable command_received : std_logic := '0';
    begin
        if reset_n_i = '0' then
            spi_active <= '0';
            spi_bit_count <= 0;
            spi_rx_data <= (others => '0');
            spi_tx_data <= (others => '0');
            spi_miso_o <= '0';
            channel_select <= 0;
            edge_detect := "00";
            command_received := '0';
            
        elsif rising_edge(clk_i) then
            -- SPI chip select detection
            if spi_cs_n_i = '1' then
                -- Inactive, reset SPI
                spi_active <= '0';
                spi_bit_count <= 0;
                edge_detect := "00";
                command_received := '0';
            else
                -- Active, handle SPI transaction
                edge_detect := edge_detect(0) & spi_sclk_i;
                
                -- Rising edge of SCLK
                if edge_detect = "01" then
                    -- Sample MOSI on rising edge
                    spi_rx_data <= spi_rx_data(14 downto 0) & spi_mosi_i;
                    
                    -- First bit marks start of transaction
                    if spi_bit_count = 0 then
                        spi_active <= '1';
                    end if;
                    
                    -- Increment bit counter
                    if spi_bit_count < 16 then
                        spi_bit_count <= spi_bit_count + 1;
                    end if;
                    
                    -- After 8 bits, we should have received the command and channel
                    if spi_bit_count = 8 then
                        command_received := '1';
                        
                        -- Parse command - assuming the most significant 5 bits are command
                        -- and the next 3 bits are channel
                        channel_select <= to_integer(unsigned(spi_rx_data(2 downto 0)));
                        
                        -- Prepare response data - include selected channel's value
                        if channel_select < CHANNELS_g then
                            spi_tx_data <= std_logic_vector(to_unsigned(channel_values(channel_select), 16));
                        else
                            spi_tx_data <= (others => '0');  -- Invalid channel
                        end if;
                    end if;
                    
                -- Falling edge of SCLK
                elsif edge_detect = "10" then
                    -- Drive MISO on falling edge (prepare for next rising edge)
                    if command_received = '1' then
                        spi_miso_o <= spi_tx_data(15);
                        spi_tx_data <= spi_tx_data(14 downto 0) & '0';  -- Shift left
                    else
                        spi_miso_o <= '0';  -- Default output before command
                    end if;
                end if;
            end if;
        end if;
    end process spi_slave_proc;
    
    -- Debug outputs
    process(channel_select, channel_values)
    begin
        if channel_select < CHANNELS_g then
            current_value_o <= std_logic_vector(to_unsigned(channel_values(channel_select), ADC_BITS_g));
        else
            current_value_o <= (others => '0');
        end if;
    end process;
    
    channel_sel_o <= channel_select;
    
end architecture rtl; 