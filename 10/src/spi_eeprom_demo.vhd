---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  SPI EEPROM Demo
--                - Demonstrates SPI communication with external EEPROM
--                - Performs read/write operations to EEPROM
--                - Includes manual control via buttons
--                - LED feedback to show operation status
--                - Test pattern data for verification
--                - Self-contained demo with clock generation
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity spi_eeprom_demo is
    generic (
        CLK_FREQ_HZ_g       : integer := 100000000;  --! System clock frequency in Hz
        SPI_CLK_FREQ_HZ_g   : integer := 1000000;    --! SPI clock frequency in Hz
        MEM_SIZE_BYTES_g    : integer := 128;        --! EEPROM size in bytes
        ADDRESS_WIDTH_g     : integer := 7;          --! EEPROM address width
        DATA_WIDTH_g        : integer := 8           --! Data width (8 bits for EEPROM)
    );
    port (
        clk_i               : in  std_logic;         --! System clock
        reset_n_i           : in  std_logic;         --! Active low reset
        
        -- User interface
        btn_write_i         : in  std_logic;         --! Button to initiate write operation
        btn_read_i          : in  std_logic;         --! Button to initiate read operation
        
        -- Status LEDs
        led_busy_o          : out std_logic;         --! Operation in progress
        led_success_o       : out std_logic;         --! Operation completed successfully
        led_error_o         : out std_logic;         --! Error occurred
        
        -- SPI pins (connection to external EEPROM)
        spi_sclk_o          : out std_logic;         --! SPI clock
        spi_mosi_o          : out std_logic;         --! Master Out Slave In
        spi_miso_i          : in  std_logic;         --! Master In Slave Out
        spi_cs_n_o          : out std_logic          --! Chip select (active low)
    );
end entity spi_eeprom_demo;

architecture rtl of spi_eeprom_demo is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- SPI Master component
    component spi_master is
        generic (
            CLK_FREQ_HZ_g     : integer := 100000000;
            SPI_CLK_FREQ_HZ_g : integer := 1000000;
            DATA_WIDTH_g      : integer := 8;
            CPOL_g            : std_logic := '0';
            CPHA_g            : std_logic := '0';
            MSB_FIRST_g       : boolean := true
        );
        port (
            clk_i         : in  std_logic;
            reset_n_i     : in  std_logic;
            start_i       : in  std_logic;
            busy_o        : out std_logic;
            tx_data_i     : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
            rx_data_o     : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            rx_valid_o    : out std_logic;
            spi_sclk_o    : out std_logic;
            spi_mosi_o    : out std_logic;
            spi_miso_i    : in  std_logic;
            spi_cs_n_o    : out std_logic
        );
    end component spi_master;
    
    -- For demonstration, we also integrate an EEPROM model to show a complete system
    component spi_eeprom is
        generic (
            MEM_SIZE_BYTES_g : integer := 128;
            DATA_WIDTH_g     : integer := 8;
            ADDRESS_WIDTH_g  : integer := 7
        );
        port (
            clk_i        : in  std_logic;
            reset_n_i    : in  std_logic;
            spi_sclk_i   : in  std_logic;
            spi_mosi_i   : in  std_logic;
            spi_miso_o   : out std_logic;
            spi_cs_n_i   : in  std_logic
        );
    end component spi_eeprom;
    
    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- EEPROM commands
    constant CMD_READ_c      : std_logic_vector(7 downto 0) := x"03"; -- Read data
    constant CMD_WRITE_c     : std_logic_vector(7 downto 0) := x"02"; -- Write data
    constant CMD_WREN_c      : std_logic_vector(7 downto 0) := x"06"; -- Write enable
    constant CMD_WRDI_c      : std_logic_vector(7 downto 0) := x"04"; -- Write disable
    constant CMD_RDSR_c      : std_logic_vector(7 downto 0) := x"05"; -- Read status register
    constant CMD_WRSR_c      : std_logic_vector(7 downto 0) := x"01"; -- Write status register
    
    -- Demo settings
    constant TEST_ADDR_c     : std_logic_vector(ADDRESS_WIDTH_g-1 downto 0) := "0000101"; -- Address 5
    constant TEST_DATA_BYTES_c : integer := 8; -- Number of bytes to read/write in demo
    
    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- State machine for sequencing SPI operations
    type demo_state_t is (
        IDLE_ST,             --! Idle state - waiting for button press
        WREN_CMD_ST,         --! Send Write Enable command
        WRITE_CMD_ST,        --! Send Write command
        WRITE_ADDR_ST,       --! Send address for Write
        WRITE_DATA_ST,       --! Send data bytes for Write
        READ_CMD_ST,         --! Send Read command
        READ_ADDR_ST,        --! Send address for Read
        READ_DATA_ST,        --! Read data bytes
        WAIT_ST,             --! Wait state between operations
        CHECK_ST,            --! Check read data against expected
        COMPLETE_ST          --! Operation complete
    );
    
    -- Test pattern type for verification
    type test_pattern_t is array (0 to TEST_DATA_BYTES_c-1) of std_logic_vector(7 downto 0);
    
    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- State machine signals
    signal current_state_s    : demo_state_t := IDLE_ST;
    signal next_state_s       : demo_state_t;
    
    -- Button debounce and edge detection
    signal btn_write_sync_s   : std_logic_vector(1 downto 0);
    signal btn_read_sync_s    : std_logic_vector(1 downto 0);
    signal btn_write_pulse_s  : std_logic;
    signal btn_read_pulse_s   : std_logic;
    
    -- SPI master control signals
    signal spi_start_s        : std_logic;
    signal spi_busy_s         : std_logic;
    signal spi_tx_data_s      : std_logic_vector(DATA_WIDTH_g-1 downto 0);
    signal spi_rx_data_s      : std_logic_vector(DATA_WIDTH_g-1 downto 0);
    signal spi_rx_valid_s     : std_logic;
    
    -- SPI signals for connecting to EEPROM model (for simulation)
    signal spi_sclk_int_s     : std_logic;
    signal spi_mosi_int_s     : std_logic;
    signal spi_miso_int_s     : std_logic;
    signal spi_cs_n_int_s     : std_logic;
    
    -- Operation control
    signal byte_counter_s     : integer range 0 to TEST_DATA_BYTES_c := 0;
    signal wait_counter_s     : integer range 0 to 100 := 0;
    signal wait_done_s        : std_logic;
    
    -- Data verification
    signal write_pattern_s    : test_pattern_t := (
        0 => x"A5", 1 => x"5A", 2 => x"F0", 3 => x"0F",
        4 => x"C3", 5 => x"3C", 6 => x"69", 7 => x"96"
    );
    signal read_pattern_s     : test_pattern_t := (others => (others => '0'));
    signal data_match_s       : std_logic;
    signal operation_success_s : std_logic;
    
begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT INSTANTIATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- SPI Master instantiation
    spi_master_inst : spi_master
        generic map (
            CLK_FREQ_HZ_g     => CLK_FREQ_HZ_g,
            SPI_CLK_FREQ_HZ_g => SPI_CLK_FREQ_HZ_g,
            DATA_WIDTH_g      => DATA_WIDTH_g,
            CPOL_g            => '0',
            CPHA_g            => '0',
            MSB_FIRST_g       => true
        )
        port map (
            clk_i         => clk_i,
            reset_n_i     => reset_n_i,
            start_i       => spi_start_s,
            busy_o        => spi_busy_s,
            tx_data_i     => spi_tx_data_s,
            rx_data_o     => spi_rx_data_s,
            rx_valid_o    => spi_rx_valid_s,
            spi_sclk_o    => spi_sclk_int_s,
            spi_mosi_o    => spi_mosi_int_s,
            spi_miso_i    => spi_miso_int_s,
            spi_cs_n_o    => spi_cs_n_int_s
        );
    
    -- EEPROM model for simulation
    -- Note: This would be commented out in the actual FPGA implementation
    -- where a real external EEPROM is used
    spi_eeprom_inst : spi_eeprom
        generic map (
            MEM_SIZE_BYTES_g => MEM_SIZE_BYTES_g,
            DATA_WIDTH_g     => DATA_WIDTH_g,
            ADDRESS_WIDTH_g  => ADDRESS_WIDTH_g
        )
        port map (
            clk_i        => clk_i,
            reset_n_i    => reset_n_i,
            spi_sclk_i   => spi_sclk_int_s,
            spi_mosi_i   => spi_mosi_int_s,
            spi_miso_o   => spi_miso_int_s,
            spi_cs_n_i   => spi_cs_n_int_s
        );
    
    --------------------------------------------------------------------------------------------------------------------
    -- EXTERNAL CONNECTIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Connect internal signals to external pins
    spi_sclk_o <= spi_sclk_int_s;
    spi_mosi_o <= spi_mosi_int_s;
    spi_miso_int_s <= spi_miso_i; -- Note: This would override the EEPROM model's output in actual implementation
    spi_cs_n_o <= spi_cs_n_int_s;
    
    -- Status LEDs
    led_busy_o <= '1' when current_state_s /= IDLE_ST and current_state_s /= COMPLETE_ST else '0';
    led_success_o <= operation_success_s;
    led_error_o <= '1' when current_state_s = COMPLETE_ST and operation_success_s = '0' else '0';
    
    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- Button edge detection
    btn_write_pulse_s <= btn_write_sync_s(0) and not btn_write_sync_s(1);
    btn_read_pulse_s <= btn_read_sync_s(0) and not btn_read_sync_s(1);
    
    -- Wait timer done signal
    wait_done_s <= '1' when wait_counter_s = 0 else '0';
    
    -- Data verification
    data_match_proc : process(read_pattern_s, write_pattern_s) is
        variable match_v : std_logic;
    begin
        match_v := '1';
        
        for i in 0 to TEST_DATA_BYTES_c-1 loop
            if read_pattern_s(i) /= write_pattern_s(i) then
                match_v := '0';
                exit;
            end if;
        end loop;
        
        data_match_s <= match_v;
    end process data_match_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- Button input synchronization
    button_sync_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            btn_write_sync_s <= (others => '0');
            btn_read_sync_s <= (others => '0');
        elsif rising_edge(clk_i) then
            btn_write_sync_s <= btn_write_sync_s(0) & btn_write_i;
            btn_read_sync_s <= btn_read_sync_s(0) & btn_read_i;
        end if;
    end process button_sync_proc;
    
    -- Main state machine
    state_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            current_state_s    <= IDLE_ST;
            spi_start_s        <= '0';
            spi_tx_data_s      <= (others => '0');
            byte_counter_s     <= 0;
            wait_counter_s     <= 0;
            read_pattern_s     <= (others => (others => '0'));
            operation_success_s <= '0';
            
        elsif rising_edge(clk_i) then
            -- Default values
            spi_start_s <= '0';
            
            -- Wait counter logic
            if current_state_s = WAIT_ST then
                if wait_counter_s > 0 then
                    wait_counter_s <= wait_counter_s - 1;
                end if;
            else
                wait_counter_s <= 0;
            end if;
            
            -- State machine
            case current_state_s is
                when IDLE_ST =>
                    -- Reset success flags when entering idle
                    operation_success_s <= '0';
                    byte_counter_s <= 0;
                    
                    -- Start write sequence on write button press
                    if btn_write_pulse_s = '1' then
                        current_state_s <= WREN_CMD_ST;
                    -- Start read sequence on read button press
                    elsif btn_read_pulse_s = '1' then
                        current_state_s <= READ_CMD_ST;
                    end if;
                    
                when WREN_CMD_ST =>
                    -- Send Write Enable command
                    if spi_busy_s = '0' then
                        spi_tx_data_s <= CMD_WREN_c;
                        spi_start_s <= '1';
                        current_state_s <= WRITE_CMD_ST;
                    end if;
                    
                when WRITE_CMD_ST =>
                    -- Wait for previous command to complete
                    if spi_busy_s = '0' then
                        spi_tx_data_s <= CMD_WRITE_c;
                        spi_start_s <= '1';
                        current_state_s <= WRITE_ADDR_ST;
                    end if;
                    
                when WRITE_ADDR_ST =>
                    -- Send address byte
                    if spi_busy_s = '0' then
                        spi_tx_data_s <= "0" & TEST_ADDR_c;  -- Pad address to 8 bits
                        spi_start_s <= '1';
                        current_state_s <= WRITE_DATA_ST;
                        byte_counter_s <= 0;
                    end if;
                    
                when WRITE_DATA_ST =>
                    -- Send data bytes
                    if spi_busy_s = '0' then
                        -- Send current byte from test pattern
                        spi_tx_data_s <= write_pattern_s(byte_counter_s);
                        spi_start_s <= '1';
                        
                        -- Check if all bytes sent
                        if byte_counter_s = TEST_DATA_BYTES_c - 1 then
                            -- Wait for EEPROM write cycle time
                            current_state_s <= WAIT_ST;
                            wait_counter_s <= 100;  -- Arbitrary wait time
                        else
                            byte_counter_s <= byte_counter_s + 1;
                        end if;
                    end if;
                    
                when READ_CMD_ST =>
                    -- Send Read command
                    if spi_busy_s = '0' then
                        spi_tx_data_s <= CMD_READ_c;
                        spi_start_s <= '1';
                        current_state_s <= READ_ADDR_ST;
                    end if;
                    
                when READ_ADDR_ST =>
                    -- Send address byte
                    if spi_busy_s = '0' then
                        spi_tx_data_s <= "0" & TEST_ADDR_c;  -- Pad address to 8 bits
                        spi_start_s <= '1';
                        current_state_s <= READ_DATA_ST;
                        byte_counter_s <= 0;
                    end if;
                    
                when READ_DATA_ST =>
                    -- Read data bytes
                    if spi_busy_s = '0' and byte_counter_s < TEST_DATA_BYTES_c then
                        -- Send dummy byte to clock in data
                        spi_tx_data_s <= (others => '0');
                        spi_start_s <= '1';
                    end if;
                    
                    -- Capture received data
                    if spi_rx_valid_s = '1' then
                        -- Store received byte
                        read_pattern_s(byte_counter_s) <= spi_rx_data_s;
                        
                        -- Check if all bytes received
                        if byte_counter_s = TEST_DATA_BYTES_c - 1 then
                            current_state_s <= CHECK_ST;
                        else
                            byte_counter_s <= byte_counter_s + 1;
                        end if;
                    end if;
                    
                when WAIT_ST =>
                    -- Wait for internal timer
                    if wait_done_s = '1' then
                        current_state_s <= READ_CMD_ST;
                    end if;
                    
                when CHECK_ST =>
                    -- Verify read data matches written data
                    if data_match_s = '1' then
                        operation_success_s <= '1';
                    else
                        operation_success_s <= '0';
                    end if;
                    
                    current_state_s <= COMPLETE_ST;
                    
                when COMPLETE_ST =>
                    -- Wait for button press to return to idle
                    if btn_write_pulse_s = '1' or btn_read_pulse_s = '1' then
                        current_state_s <= IDLE_ST;
                    end if;
                    
            end case;
        end if;
    end process state_proc;

end architecture rtl; 