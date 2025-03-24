---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  SPI EEPROM Emulator
--                - Emulates an SPI EEPROM device (25LC/25AA series compatible)
--                - Supports READ, WRITE, WREN, WRDI, RDSR, WRSR commands
--                - 128-byte memory array (customizable)
--                - Includes write protection functionality
--                - Models timing requirements of real EEPROM
--                - Can be used for testing SPI master implementations
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity spi_eeprom is
    generic (
        MEM_SIZE_BYTES_g : integer := 128;       --! Memory size in bytes
        DATA_WIDTH_g     : integer := 8;         --! Data width (always 8 for standard EEPROMs)
        ADDRESS_WIDTH_g  : integer := 7          --! Address width based on memory size
    );
    port (
        clk_i           : in  std_logic;         --! System clock
        reset_n_i       : in  std_logic;         --! Active low reset
        
        -- SPI signals
        spi_sclk_i      : in  std_logic;         --! SPI clock
        spi_mosi_i      : in  std_logic;         --! Master Out Slave In
        spi_miso_o      : out std_logic;         --! Master In Slave Out
        spi_cs_n_i      : in  std_logic          --! Chip select (active low)
    );
end entity spi_eeprom;

architecture rtl of spi_eeprom is

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- EEPROM instruction set
    constant CMD_READ_c      : std_logic_vector(7 downto 0) := x"03"; -- Read data
    constant CMD_WRITE_c     : std_logic_vector(7 downto 0) := x"02"; -- Write data
    constant CMD_WREN_c      : std_logic_vector(7 downto 0) := x"06"; -- Write enable
    constant CMD_WRDI_c      : std_logic_vector(7 downto 0) := x"04"; -- Write disable
    constant CMD_RDSR_c      : std_logic_vector(7 downto 0) := x"05"; -- Read status register
    constant CMD_WRSR_c      : std_logic_vector(7 downto 0) := x"01"; -- Write status register
    
    -- Status register bit positions
    constant SR_WIP_c        : integer := 0;  -- Write in progress bit
    constant SR_WEL_c        : integer := 1;  -- Write enable latch bit
    constant SR_BP0_c        : integer := 2;  -- Block protection bit 0
    constant SR_BP1_c        : integer := 3;  -- Block protection bit 1
    constant SR_WPEN_c       : integer := 7;  -- Write protect enable bit
    
    -- Timing constants (in clock cycles for simulation)
    constant WRITE_CYCLE_c   : integer := 50;  -- Write cycle time (page write)
    
    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Memory array type
    type memory_array_t is array (0 to MEM_SIZE_BYTES_g-1) of std_logic_vector(DATA_WIDTH_g-1 downto 0);
    
    -- FSM state type
    type eeprom_state_t is (
        IDLE_ST,          --! Idle state - waiting for CS assertion
        CMD_ST,           --! Command state - receiving instruction
        ADDR_ST,          --! Address state - receiving address bytes
        DATA_ST,          --! Data state - reading/writing data
        BUSY_ST           --! Busy state - processing write operation
    );
    
    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Memory and registers
    signal memory_array_s    : memory_array_t := (others => (others => '0'));
    signal status_reg_s      : std_logic_vector(7 downto 0) := (others => '0');
    
    -- FSM signals
    signal current_state_s   : eeprom_state_t := IDLE_ST;
    
    -- Command processing
    signal command_s         : std_logic_vector(7 downto 0);
    signal address_s         : std_logic_vector(ADDRESS_WIDTH_g-1 downto 0);
    signal write_data_s      : std_logic_vector(7 downto 0);
    
    -- Bit counting and data shifting
    signal bit_counter_s     : integer range 0 to 15 := 0;
    signal byte_counter_s    : integer range 0 to 3 := 0;
    signal shift_reg_s       : std_logic_vector(7 downto 0);
    
    -- SPI signal synchronization
    signal sclk_sync_s       : std_logic_vector(1 downto 0);
    signal mosi_sync_s       : std_logic_vector(1 downto 0);
    signal cs_n_sync_s       : std_logic_vector(1 downto 0);
    
    -- Write timing
    signal write_counter_s   : integer range 0 to WRITE_CYCLE_c := 0;
    signal write_active_s    : std_logic := '0';
    
    -- Edge detection
    signal sclk_rising_s     : std_logic;
    signal sclk_falling_s    : std_logic;
    signal cs_falling_s      : std_logic;
    signal cs_rising_s       : std_logic;
    
    -- Memory address calculated from input address
    signal mem_addr_s        : integer range 0 to MEM_SIZE_BYTES_g-1;
    
begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- Edge detection on synchronized signals
    sclk_rising_s  <= '1' when sclk_sync_s(1) = '0' and sclk_sync_s(0) = '1' else '0';
    sclk_falling_s <= '1' when sclk_sync_s(1) = '1' and sclk_sync_s(0) = '0' else '0';
    cs_falling_s   <= '1' when cs_n_sync_s(1) = '1' and cs_n_sync_s(0) = '0' else '0';
    cs_rising_s    <= '1' when cs_n_sync_s(1) = '0' and cs_n_sync_s(0) = '1' else '0';
    
    -- Address conversion to integer for memory array access
    mem_addr_s <= to_integer(unsigned(address_s)) when unsigned(address_s) < MEM_SIZE_BYTES_g else 0;
    
    -- WIP (Write In Progress) bit in status register
    status_reg_s(SR_WIP_c) <= '1' when current_state_s = BUSY_ST else '0';
    
    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- Input synchronization to prevent metastability
    sync_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            sclk_sync_s <= (others => '0');
            mosi_sync_s <= (others => '0');
            cs_n_sync_s <= (others => '1');
            
        elsif rising_edge(clk_i) then
            -- Two-stage synchronization
            sclk_sync_s <= sclk_sync_s(0) & spi_sclk_i;
            mosi_sync_s <= mosi_sync_s(0) & spi_mosi_i;
            cs_n_sync_s <= cs_n_sync_s(0) & spi_cs_n_i;
        end if;
    end process sync_proc;
    
    -- Main EEPROM controller process
    eeprom_proc : process(clk_i, reset_n_i) is
        variable next_addr_v : unsigned(ADDRESS_WIDTH_g-1 downto 0);
        variable new_status_v : std_logic_vector(7 downto 0);
    begin
        if reset_n_i = '0' then
            current_state_s <= IDLE_ST;
            bit_counter_s   <= 0;
            byte_counter_s  <= 0;
            command_s       <= (others => '0');
            address_s       <= (others => '0');
            shift_reg_s     <= (others => '0');
            write_active_s  <= '0';
            write_counter_s <= 0;
            spi_miso_o      <= '0';
            
            -- Reset status register to default values
            status_reg_s(SR_WEL_c) <= '0';
            status_reg_s(SR_BP0_c) <= '0';
            status_reg_s(SR_BP1_c) <= '0';
            status_reg_s(SR_WPEN_c) <= '0';
            
        elsif rising_edge(clk_i) then
            -- Write cycle timing counter
            if write_active_s = '1' then
                if write_counter_s = WRITE_CYCLE_c - 1 then
                    write_counter_s <= 0;
                    write_active_s  <= '0';
                    current_state_s <= IDLE_ST;
                    
                    -- Clear write enable latch after write completes
                    status_reg_s(SR_WEL_c) <= '0';
                else
                    write_counter_s <= write_counter_s + 1;
                end if;
            end if;
            
            -- CS rising edge (end of transaction)
            if cs_rising_s = '1' and current_state_s /= BUSY_ST then
                current_state_s <= IDLE_ST;
                bit_counter_s   <= 0;
                byte_counter_s  <= 0;
            end if;
            
            -- Process based on current state
            case current_state_s is
                when IDLE_ST =>
                    spi_miso_o <= '0';  -- Default tri-state, but using '0' for simulation
                    
                    -- Start of new transaction
                    if cs_falling_s = '1' then
                        current_state_s <= CMD_ST;
                        bit_counter_s   <= 0;
                    end if;
                    
                when CMD_ST =>
                    -- Process command byte
                    if sclk_rising_s = '1' then
                        -- Shift in command bit
                        shift_reg_s <= shift_reg_s(6 downto 0) & mosi_sync_s(0);
                        
                        if bit_counter_s = 7 then
                            -- Command byte complete
                            command_s      <= shift_reg_s(6 downto 0) & mosi_sync_s(0);
                            bit_counter_s  <= 0;
                            byte_counter_s <= 0;
                            
                            -- Determine next state based on command
                            case shift_reg_s(6 downto 0) & mosi_sync_s(0) is
                                when CMD_READ_c | CMD_WRITE_c =>
                                    current_state_s <= ADDR_ST;
                                    
                                when CMD_RDSR_c =>
                                    current_state_s <= DATA_ST;
                                    shift_reg_s     <= status_reg_s;
                                    
                                when CMD_WRSR_c =>
                                    -- Only proceed if write enable latch is set
                                    if status_reg_s(SR_WEL_c) = '1' then
                                        current_state_s <= DATA_ST;
                                    else
                                        current_state_s <= IDLE_ST;
                                    end if;
                                    
                                when CMD_WREN_c =>
                                    -- Set write enable latch
                                    status_reg_s(SR_WEL_c) <= '1';
                                    current_state_s <= IDLE_ST;
                                    
                                when CMD_WRDI_c =>
                                    -- Clear write enable latch
                                    status_reg_s(SR_WEL_c) <= '0';
                                    current_state_s <= IDLE_ST;
                                    
                                when others =>
                                    -- Unknown command, return to idle
                                    current_state_s <= IDLE_ST;
                            end case;
                        else
                            bit_counter_s <= bit_counter_s + 1;
                        end if;
                    end if;
                    
                when ADDR_ST =>
                    -- Process address byte(s)
                    if sclk_rising_s = '1' then
                        -- Shift in address bit
                        shift_reg_s <= shift_reg_s(6 downto 0) & mosi_sync_s(0);
                        
                        if bit_counter_s = 7 then
                            -- Address byte complete
                            bit_counter_s <= 0;
                            
                            -- Store address or go to data phase
                            if byte_counter_s = 0 then
                                -- For simplicity, assuming we only need one address byte
                                address_s      <= shift_reg_s(ADDRESS_WIDTH_g-2 downto 0) & mosi_sync_s(0);
                                byte_counter_s <= byte_counter_s + 1;
                                
                                -- Prepare for data phase based on command
                                if command_s = CMD_READ_c then
                                    current_state_s <= DATA_ST;
                                    -- Pre-load shift register with first data byte for read
                                    shift_reg_s <= memory_array_s(to_integer(unsigned(
                                        shift_reg_s(ADDRESS_WIDTH_g-2 downto 0) & mosi_sync_s(0)
                                    )));
                                elsif command_s = CMD_WRITE_c then
                                    -- Only proceed to data phase if write enable latch is set
                                    if status_reg_s(SR_WEL_c) = '1' then
                                        current_state_s <= DATA_ST;
                                    else
                                        current_state_s <= IDLE_ST;
                                    end if;
                                end if;
                            end if;
                        else
                            bit_counter_s <= bit_counter_s + 1;
                        end if;
                    end if;
                    
                    -- Start outputting data for READ command on falling edges
                    if command_s = CMD_READ_c and sclk_falling_s = '1' and byte_counter_s = 1 then
                        spi_miso_o <= shift_reg_s(7);
                    end if;
                    
                when DATA_ST =>
                    -- Process data based on command
                    if command_s = CMD_READ_c then
                        -- READ command - output data
                        if sclk_falling_s = '1' then
                            -- Shift out next bit
                            shift_reg_s <= shift_reg_s(6 downto 0) & '0';
                            spi_miso_o  <= shift_reg_s(7);
                            
                            -- Check if byte is complete
                            if bit_counter_s = 7 then
                                bit_counter_s <= 0;
                                
                                -- Calculate next address for continuous reading
                                next_addr_v := unsigned(address_s) + 1;
                                address_s   <= std_logic_vector(next_addr_v);
                                
                                -- Load next byte from memory
                                shift_reg_s <= memory_array_s(to_integer(next_addr_v));
                            else
                                bit_counter_s <= bit_counter_s + 1;
                            end if;
                        end if;
                        
                    elsif command_s = CMD_WRITE_c then
                        -- WRITE command - input data
                        if sclk_rising_s = '1' then
                            -- Shift in data bit
                            shift_reg_s <= shift_reg_s(6 downto 0) & mosi_sync_s(0);
                            
                            -- Check if byte is complete
                            if bit_counter_s = 7 then
                                bit_counter_s  <= 0;
                                
                                -- Store data to memory if write is allowed
                                -- In a real EEPROM, we would check block protection here
                                write_data_s <= shift_reg_s(6 downto 0) & mosi_sync_s(0);
                                memory_array_s(mem_addr_s) <= shift_reg_s(6 downto 0) & mosi_sync_s(0);
                                
                                -- Calculate next address for page write
                                next_addr_v := unsigned(address_s) + 1;
                                address_s   <= std_logic_vector(next_addr_v);
                            else
                                bit_counter_s <= bit_counter_s + 1;
                            end if;
                        end if;
                        
                    elsif command_s = CMD_RDSR_c then
                        -- RDSR command - output status register
                        if sclk_falling_s = '1' then
                            -- Shift out next bit of status register
                            shift_reg_s <= shift_reg_s(6 downto 0) & '0';
                            spi_miso_o  <= shift_reg_s(7);
                            
                            -- Continuously loop through status register
                            if bit_counter_s = 7 then
                                bit_counter_s <= 0;
                                shift_reg_s   <= status_reg_s;
                            else
                                bit_counter_s <= bit_counter_s + 1;
                            end if;
                        end if;
                        
                    elsif command_s = CMD_WRSR_c then
                        -- WRSR command - input new status register value
                        if sclk_rising_s = '1' then
                            -- Shift in status register bit
                            shift_reg_s <= shift_reg_s(6 downto 0) & mosi_sync_s(0);
                            
                            -- Update status register when byte complete
                            if bit_counter_s = 7 then
                                -- Prepare complete new status register value
                                new_status_v := shift_reg_s(6 downto 0) & mosi_sync_s(0);
                                
                                -- Only update the bits that are allowed to be changed
                                -- WEL bit is controlled internally, WIP bit is read-only
                                status_reg_s(SR_BP0_c) <= new_status_v(SR_BP0_c);
                                status_reg_s(SR_BP1_c) <= new_status_v(SR_BP1_c);
                                status_reg_s(SR_WPEN_c) <= new_status_v(SR_WPEN_c);
                                
                                -- Return to idle
                                current_state_s <= IDLE_ST;
                            else
                                bit_counter_s <= bit_counter_s + 1;
                            end if;
                        end if;
                    end if;
                    
                when BUSY_ST =>
                    -- Write cycle in progress, EEPROM is busy
                    -- Just wait until write_counter_s reaches WRITE_CYCLE_c
                    null;
                    
            end case;
            
            -- Handle transition to BUSY state at the end of WRITE operation when CS is deasserted
            if cs_rising_s = '1' and current_state_s = DATA_ST and command_s = CMD_WRITE_c then
                current_state_s <= BUSY_ST;
                write_active_s  <= '1';
                write_counter_s <= 0;
            end if;
        end if;
    end process eeprom_proc;

end architecture rtl; 