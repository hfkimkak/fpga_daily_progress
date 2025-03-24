---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  SPI Slave Controller
--                - Configurable clock polarity (CPOL) and phase (CPHA)
--                - Configurable data width (8-bit default)
--                - Supports MSB-first or LSB-first transmission
--                - Full-duplex operation (simultaneous read/write)
--                - Transaction detection and completion notification
--                - Can be used for testing or peripheral simulation
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity spi_slave is
    generic (
        DATA_WIDTH_g      : integer := 8;     --! SPI data width in bits (8 is standard)
        CPOL_g            : std_logic := '0'; --! Clock polarity (0: idle low, 1: idle high)
        CPHA_g            : std_logic := '0'; --! Clock phase (0: sample on first edge, 1: sample on second edge)
        MSB_FIRST_g       : boolean := true   --! Data bit order (true: MSB first, false: LSB first)
    );
    port (
        clk_i         : in  std_logic;             --! System clock
        reset_n_i     : in  std_logic;             --! Active low reset
        
        -- Control and status signals
        tx_ready_i    : in  std_logic;             --! New data is ready to transmit
        busy_o        : out std_logic;             --! Transaction in progress
        
        -- Data signals
        tx_data_i     : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);  --! Data to transmit to master
        rx_data_o     : out std_logic_vector(DATA_WIDTH_g-1 downto 0);  --! Data received from master
        rx_valid_o    : out std_logic;             --! Received data valid (pulses for one cycle)
        
        -- SPI signals
        spi_sclk_i    : in  std_logic;             --! SPI clock from master
        spi_mosi_i    : in  std_logic;             --! Master Out Slave In
        spi_miso_o    : out std_logic;             --! Master In Slave Out
        spi_cs_n_i    : in  std_logic              --! Chip select (active low)
    );
end entity spi_slave;

architecture rtl of spi_slave is

    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- FSM state definition
    type spi_state_t is (
        IDLE_ST,        --! Idle state - waiting for CS assertion
        TRANSFER_ST,    --! Transfer state - sending/receiving bits
        COMPLETE_ST     --! Complete state - finishing transaction
    );
    
    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- FSM signals
    signal current_state_s : spi_state_t := IDLE_ST;
    
    -- Synchronization signals for external SPI inputs
    signal sclk_sync_s     : std_logic_vector(1 downto 0);
    signal mosi_sync_s     : std_logic_vector(1 downto 0);
    signal cs_n_sync_s     : std_logic_vector(1 downto 0);
    
    -- Edge detection
    signal sclk_rising_s   : std_logic;
    signal sclk_falling_s  : std_logic;
    
    -- Sampling and shifting control
    signal sample_edge_s   : std_logic;
    signal shift_edge_s    : std_logic;
    
    -- Data shift registers
    signal tx_shift_reg_s  : std_logic_vector(DATA_WIDTH_g-1 downto 0);
    signal rx_shift_reg_s  : std_logic_vector(DATA_WIDTH_g-1 downto 0);
    
    -- Bit counters
    signal bit_counter_s   : integer range 0 to DATA_WIDTH_g-1 := 0;
    signal bits_done_s     : std_logic := '0';
    
    -- Transaction control
    signal transaction_active_s : std_logic := '0';
    
begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- Output assignments
    busy_o <= '0' when current_state_s = IDLE_ST else '1';
    
    -- MISO assignment depends on MSB/LSB first configuration
    spi_miso_o <= tx_shift_reg_s(DATA_WIDTH_g-1) when MSB_FIRST_g else
                 tx_shift_reg_s(0);
    
    -- Edge detection on synchronized clock
    sclk_rising_s  <= '1' when sclk_sync_s(1) = '0' and sclk_sync_s(0) = '1' else '0';
    sclk_falling_s <= '1' when sclk_sync_s(1) = '1' and sclk_sync_s(0) = '0' else '0';
    
    -- Determine sampling and shifting edges based on CPHA
    -- CPHA=0: Sample on first edge (rising if CPOL=0, falling if CPOL=1)
    -- CPHA=1: Sample on second edge (falling if CPOL=0, rising if CPOL=1)
    sample_edge_s <= sclk_rising_s when (CPOL_g = '0' and CPHA_g = '0') or (CPOL_g = '1' and CPHA_g = '1') else
                    sclk_falling_s;
                    
    shift_edge_s  <= sclk_falling_s when (CPOL_g = '0' and CPHA_g = '0') or (CPOL_g = '1' and CPHA_g = '1') else
                    sclk_rising_s;
    
    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- Input synchronization to prevent metastability
    sync_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            sclk_sync_s <= (others => CPOL_g);
            mosi_sync_s <= (others => '0');
            cs_n_sync_s <= (others => '1');
            
        elsif rising_edge(clk_i) then
            -- Two-stage synchronization
            sclk_sync_s <= sclk_sync_s(0) & spi_sclk_i;
            mosi_sync_s <= mosi_sync_s(0) & spi_mosi_i;
            cs_n_sync_s <= cs_n_sync_s(0) & spi_cs_n_i;
        end if;
    end process sync_proc;
    
    -- Main SPI slave controller process
    spi_control_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            current_state_s      <= IDLE_ST;
            rx_valid_o           <= '0';
            bit_counter_s        <= 0;
            bits_done_s          <= '0';
            tx_shift_reg_s       <= (others => '0');
            rx_shift_reg_s       <= (others => '0');
            rx_data_o            <= (others => '0');
            transaction_active_s <= '0';
            
        elsif rising_edge(clk_i) then
            -- Default values for pulsed signals
            rx_valid_o <= '0';
            bits_done_s <= '0';
            
            -- FSM
            case current_state_s is
                when IDLE_ST =>
                    -- Wait for chip select assertion
                    if cs_n_sync_s(0) = '0' and transaction_active_s = '0' then
                        current_state_s      <= TRANSFER_ST;
                        transaction_active_s <= '1';
                        bit_counter_s        <= 0;
                        
                        -- Load transmit data if ready
                        if tx_ready_i = '1' then
                            tx_shift_reg_s <= tx_data_i;
                        else
                            tx_shift_reg_s <= (others => '0'); -- Default value if no data ready
                        end if;
                    end if;
                    
                when TRANSFER_ST =>
                    -- Handle CS deassertion - end of transaction
                    if cs_n_sync_s(0) = '1' then
                        current_state_s <= COMPLETE_ST;
                    else
                        -- Sample data on appropriate clock edge
                        if sample_edge_s = '1' then
                            if MSB_FIRST_g then
                                -- MSB first shift operation
                                rx_shift_reg_s <= rx_shift_reg_s(DATA_WIDTH_g-2 downto 0) & mosi_sync_s(0);
                            else
                                -- LSB first shift operation
                                rx_shift_reg_s <= mosi_sync_s(0) & rx_shift_reg_s(DATA_WIDTH_g-1 downto 1);
                            end if;
                        end if;
                        
                        -- Shift data on appropriate clock edge
                        if shift_edge_s = '1' then
                            -- Increment bit counter
                            if bit_counter_s = DATA_WIDTH_g-1 then
                                bit_counter_s <= 0;
                                bits_done_s   <= '1';
                                
                                -- Prepare for potential next byte in the same transaction
                                if tx_ready_i = '1' then
                                    tx_shift_reg_s <= tx_data_i;
                                end if;
                                
                                -- Output received byte
                                rx_data_o  <= rx_shift_reg_s;
                                rx_valid_o <= '1';
                            else
                                bit_counter_s <= bit_counter_s + 1;
                                
                                -- Shift out next bit
                                if MSB_FIRST_g then
                                    -- MSB first shift operation
                                    tx_shift_reg_s <= tx_shift_reg_s(DATA_WIDTH_g-2 downto 0) & '0';
                                else
                                    -- LSB first shift operation
                                    tx_shift_reg_s <= '0' & tx_shift_reg_s(DATA_WIDTH_g-1 downto 1);
                                end if;
                            end if;
                        end if;
                    end if;
                    
                when COMPLETE_ST =>
                    -- Output the final received data if complete byte not already output
                    if bits_done_s = '0' and bit_counter_s > 0 then
                        rx_data_o  <= rx_shift_reg_s;
                        rx_valid_o <= '1';
                    end if;
                    
                    -- Reset for next transaction
                    transaction_active_s <= '0';
                    current_state_s      <= IDLE_ST;
                    
            end case;
        end if;
    end process spi_control_proc;

end architecture rtl; 