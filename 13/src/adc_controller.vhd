--------------------------------------------------------------------------------
-- File: adc_controller.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- ADC Controller module for interfacing with external ADC devices.
-- Supports SPI-based ADC communication with configurable parameters.
-- Handles ADC initialization, sample acquisition, and result processing.
-- Designed to work with various ADC resolutions and sampling rates.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_controller is
    generic (
        -- Clock and timing parameters
        CLK_FREQ_HZ_g    : integer := 50_000_000;  -- System clock frequency (Hz)
        SPI_FREQ_HZ_g    : integer := 1_000_000;   -- SPI clock frequency (Hz)
        
        -- ADC configuration parameters
        ADC_BITS_g       : integer range 8 to 16 := 12;   -- ADC resolution (bits)
        CHANNELS_g       : integer range 1 to 8  := 1;    -- Number of ADC channels
        
        -- Conversion parameters
        AUTO_SAMPLE_g    : boolean := true;  -- Enable automatic sampling
        SAMPLE_RATE_HZ_g : integer := 1000   -- Sample rate when in auto mode (Hz)
    );
    port (
        -- Clock and reset
        clk_i            : in  std_logic;
        reset_n_i        : in  std_logic;
        
        -- Control signals
        start_conv_i     : in  std_logic;                            -- Start conversion (pulse)
        channel_select_i : in  integer range 0 to CHANNELS_g-1;      -- Channel selection
        busy_o           : out std_logic;                            -- Conversion in progress
        done_o           : out std_logic;                            -- Conversion complete (pulse)
        
        -- Data output
        adc_data_o       : out std_logic_vector(ADC_BITS_g-1 downto 0);  -- ADC result
        adc_channel_o    : out integer range 0 to CHANNELS_g-1;          -- Channel of result
        
        -- SPI interface to ADC
        spi_cs_n_o       : out std_logic;                            -- Chip select (active low)
        spi_sclk_o       : out std_logic;                            -- Serial clock
        spi_mosi_o       : out std_logic;                            -- Master out slave in
        spi_miso_i       : in  std_logic;                            -- Master in slave out
        
        -- Debug outputs
        debug_state_o    : out std_logic_vector(3 downto 0)          -- Current state for debugging
    );
end entity adc_controller;

architecture rtl of adc_controller is

    -- SPI clock generation
    constant SPI_CLK_DIV_c      : integer := CLK_FREQ_HZ_g / SPI_FREQ_HZ_g;
    signal spi_clk_counter      : integer range 0 to SPI_CLK_DIV_c-1;
    signal spi_clk_enable       : std_logic;
    
    -- Auto-sampling timer
    constant AUTO_SAMPLE_DIV_c  : integer := CLK_FREQ_HZ_g / SAMPLE_RATE_HZ_g;
    signal auto_sample_counter  : integer range 0 to AUTO_SAMPLE_DIV_c-1;
    signal auto_sample_tick     : std_logic;
    
    -- State machine definition
    type adc_state_t is (
        IDLE,             -- Waiting for conversion trigger
        INIT_CONVERSION,  -- Prepare for conversion
        WAIT_SPI_START,   -- Wait for SPI clock alignment
        TX_CONFIG,        -- Send configuration to ADC
        RX_DATA,          -- Receive data from ADC
        PROCESS_RESULT,   -- Process received data
        CONV_DONE         -- Signal conversion complete
    );
    signal state : adc_state_t;
    
    -- SPI transaction signals
    signal spi_tx_data     : std_logic_vector(15 downto 0);  -- Data to send to ADC
    signal spi_rx_data     : std_logic_vector(15 downto 0);  -- Data received from ADC
    signal spi_bit_count   : integer range 0 to 16;          -- Bit counter for SPI transfer
    signal spi_cs_n        : std_logic;                      -- Chip select internal signal
    signal spi_sclk        : std_logic;                      -- SPI clock internal signal
    signal spi_mosi        : std_logic;                      -- MOSI internal signal
    
    -- ADC data processing
    signal adc_result      : std_logic_vector(ADC_BITS_g-1 downto 0);
    signal current_channel : integer range 0 to CHANNELS_g-1;
    
    -- Control flags
    signal conversion_busy : std_logic;
    signal conversion_complete : std_logic;
    
begin

    -- Map internal signals to outputs
    busy_o        <= conversion_busy;
    done_o        <= conversion_complete;
    adc_data_o    <= adc_result;
    adc_channel_o <= current_channel;
    spi_cs_n_o    <= spi_cs_n;
    spi_sclk_o    <= spi_sclk;
    spi_mosi_o    <= spi_mosi;
    
    -- Debug output - encode state machine state
    with state select debug_state_o <=
        "0000" when IDLE,
        "0001" when INIT_CONVERSION,
        "0010" when WAIT_SPI_START,
        "0011" when TX_CONFIG,
        "0100" when RX_DATA,
        "0101" when PROCESS_RESULT,
        "0110" when CONV_DONE,
        "1111" when others;
    
    -- SPI clock generation process
    spi_clock_gen: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            spi_clk_counter <= 0;
            spi_clk_enable <= '0';
        elsif rising_edge(clk_i) then
            spi_clk_enable <= '0';  -- Default: not enabled
            
            if conversion_busy = '1' then
                if spi_clk_counter = SPI_CLK_DIV_c-1 then
                    spi_clk_counter <= 0;
                    spi_clk_enable <= '1';  -- Enable for one cycle
                else
                    spi_clk_counter <= spi_clk_counter + 1;
                end if;
            else
                spi_clk_counter <= 0;
            end if;
        end if;
    end process spi_clock_gen;
    
    -- Auto-sampling timer process
    auto_sampling_gen: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            auto_sample_counter <= 0;
            auto_sample_tick <= '0';
        elsif rising_edge(clk_i) then
            auto_sample_tick <= '0';  -- Default: not triggered
            
            if AUTO_SAMPLE_g then
                if auto_sample_counter = AUTO_SAMPLE_DIV_c-1 then
                    auto_sample_counter <= 0;
                    auto_sample_tick <= '1';  -- Trigger sample
                else
                    auto_sample_counter <= auto_sample_counter + 1;
                end if;
            end if;
        end if;
    end process auto_sampling_gen;
    
    -- Main ADC controller state machine
    adc_state_machine: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            -- Reset state and control signals
            state <= IDLE;
            conversion_busy <= '0';
            conversion_complete <= '0';
            spi_cs_n <= '1';  -- Deactivate chip select
            spi_sclk <= '0';  -- Initial clock state
            spi_mosi <= '0';  -- Default MOSI value
            spi_bit_count <= 0;
            current_channel <= 0;
            adc_result <= (others => '0');
            spi_tx_data <= (others => '0');
            spi_rx_data <= (others => '0');
            
        elsif rising_edge(clk_i) then
            -- Default pulse signals to inactive
            conversion_complete <= '0';
            
            -- State machine
            case state is
                when IDLE =>
                    -- Reset SPI signals
                    spi_cs_n <= '1';
                    spi_sclk <= '0';
                    spi_bit_count <= 0;
                    
                    -- Wait for conversion trigger
                    if start_conv_i = '1' or auto_sample_tick = '1' then
                        state <= INIT_CONVERSION;
                        conversion_busy <= '1';
                        current_channel <= channel_select_i;
                    end if;
                    
                when INIT_CONVERSION =>
                    -- Prepare configuration word for ADC based on channel
                    -- Format will depend on the specific ADC being used
                    -- Example for a generic SPI ADC:
                    -- Bit 15: Start bit (1)
                    -- Bit 14-12: Channel selection (single-ended)
                    -- Bit 11-0: Don't care for TX
                    spi_tx_data <= "1" & std_logic_vector(to_unsigned(current_channel, 3)) & "000000000000";
                    spi_cs_n <= '0';  -- Activate chip select
                    state <= WAIT_SPI_START;
                    
                when WAIT_SPI_START =>
                    -- Wait for next SPI clock enable to align timing
                    if spi_clk_enable = '1' then
                        state <= TX_CONFIG;
                        spi_bit_count <= 16;  -- Prepare to send 16 bits (typical ADC word size)
                    end if;
                    
                when TX_CONFIG =>
                    -- Transmit configuration and receive data on SPI
                    if spi_clk_enable = '1' then
                        if spi_sclk = '0' then
                            -- Prepare data on MOSI at clock low
                            spi_mosi <= spi_tx_data(15);  -- MSB first
                            spi_tx_data <= spi_tx_data(14 downto 0) & '0';  -- Shift left
                            spi_sclk <= '1';  -- Clock goes high
                        else
                            -- Sample data from MISO at clock high
                            spi_rx_data <= spi_rx_data(14 downto 0) & spi_miso_i;  -- Shift in from MISO
                            spi_sclk <= '0';  -- Clock goes low
                            
                            -- Decrement bit counter
                            spi_bit_count <= spi_bit_count - 1;
                            
                            -- Check if all bits have been transferred
                            if spi_bit_count = 1 then
                                state <= PROCESS_RESULT;
                            end if;
                        end if;
                    end if;
                    
                when PROCESS_RESULT =>
                    -- Deactivate chip select
                    spi_cs_n <= '1';
                    
                    -- Extract ADC data from received SPI data
                    -- Format depends on ADC model - here assuming data in lower ADC_BITS_g bits
                    adc_result <= spi_rx_data(ADC_BITS_g-1 downto 0);
                    
                    state <= CONV_DONE;
                    
                when CONV_DONE =>
                    -- Signal conversion complete
                    conversion_busy <= '0';
                    conversion_complete <= '1';
                    state <= IDLE;
                    
                when others =>
                    -- Should never get here, go back to IDLE
                    state <= IDLE;
                    
            end case;
        end if;
    end process adc_state_machine;
    
end architecture rtl; 