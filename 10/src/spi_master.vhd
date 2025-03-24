---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  SPI Master Controller
--                - Configurable clock polarity (CPOL) and phase (CPHA)
--                - Configurable data width (8-bit default)
--                - Configurable clock division
--                - Supports MSB-first or LSB-first transmission
--                - Full-duplex operation (simultaneous read/write)
--                - Transaction-level control with start trigger
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity spi_master is
    generic (
        CLK_FREQ_HZ_g     : integer := 100000000;  --! System clock frequency in Hz
        SPI_CLK_FREQ_HZ_g : integer := 1000000;    --! SPI clock frequency in Hz
        DATA_WIDTH_g      : integer := 8;          --! SPI data width in bits (8 is standard)
        CPOL_g            : std_logic := '0';      --! Clock polarity (0: idle low, 1: idle high)
        CPHA_g            : std_logic := '0';      --! Clock phase (0: sample on first edge, 1: sample on second edge)
        MSB_FIRST_g       : boolean := true        --! Data bit order (true: MSB first, false: LSB first)
    );
    port (
        clk_i         : in  std_logic;             --! System clock
        reset_n_i     : in  std_logic;             --! Active low reset
        
        -- Control and status signals
        start_i       : in  std_logic;             --! Start transaction (pulse)
        busy_o        : out std_logic;             --! Transaction in progress
        
        -- Data signals
        tx_data_i     : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);  --! Data to transmit
        rx_data_o     : out std_logic_vector(DATA_WIDTH_g-1 downto 0);  --! Received data
        rx_valid_o    : out std_logic;             --! Received data valid (pulses for one cycle)
        
        -- SPI signals
        spi_sclk_o    : out std_logic;             --! SPI clock
        spi_mosi_o    : out std_logic;             --! Master Out Slave In
        spi_miso_i    : in  std_logic;             --! Master In Slave Out
        spi_cs_n_o    : out std_logic              --! Chip select (active low)
    );
end entity spi_master;

architecture rtl of spi_master is

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Calculate the number of clock cycles for desired SPI clock
    constant CLK_DIV_c        : integer := CLK_FREQ_HZ_g / SPI_CLK_FREQ_HZ_g;
    constant CLK_DIV_HALF_c   : integer := CLK_DIV_c / 2;
    
    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- FSM state definition
    type spi_state_t is (
        IDLE_ST,        --! Idle state - waiting for start
        TRANSFER_ST,    --! Transfer state - sending/receiving bits
        COMPLETE_ST     --! Complete state - finishing transaction
    );
    
    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- FSM signals
    signal current_state_s : spi_state_t := IDLE_ST;
    
    -- SPI clock generation
    signal sclk_counter_s   : integer range 0 to CLK_DIV_c-1 := 0;
    signal sclk_enable_s    : std_logic := '0';
    signal sclk_s           : std_logic := CPOL_g; -- Initialize to idle polarity
    
    -- Data shift registers
    signal tx_shift_reg_s   : std_logic_vector(DATA_WIDTH_g-1 downto 0);
    signal rx_shift_reg_s   : std_logic_vector(DATA_WIDTH_g-1 downto 0);
    
    -- Bit counters
    signal bit_counter_s    : integer range 0 to DATA_WIDTH_g-1 := 0;
    signal bits_done_s      : std_logic := '0';
    
    -- Sampling and shifting control
    signal sample_edge_s    : std_logic := '0';
    signal shift_edge_s     : std_logic := '0';
    signal sclk_rising_s    : std_logic := '0';
    signal sclk_falling_s   : std_logic := '0';
    signal sclk_prev_s      : std_logic := CPOL_g;
    
    -- Chip select control
    signal cs_n_s           : std_logic := '1';
    
begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- Output assignments
    spi_sclk_o  <= sclk_s;
    spi_cs_n_o  <= cs_n_s;
    busy_o      <= '0' when current_state_s = IDLE_ST else '1';
    
    -- MOSI assignment depends on MSB/LSB first configuration
    spi_mosi_o <=  tx_shift_reg_s(DATA_WIDTH_g-1) when MSB_FIRST_g else
                   tx_shift_reg_s(0);
    
    -- Clock edge detection
    sclk_rising_s  <= '1' when sclk_prev_s = '0' and sclk_s = '1' else '0';
    sclk_falling_s <= '1' when sclk_prev_s = '1' and sclk_s = '0' else '0';
    
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
    
    -- Main SPI controller process
    spi_control_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            current_state_s <= IDLE_ST;
            cs_n_s          <= '1';
            rx_valid_o      <= '0';
            sclk_enable_s   <= '0';
            bit_counter_s   <= 0;
            bits_done_s     <= '0';
            tx_shift_reg_s  <= (others => '0');
            rx_shift_reg_s  <= (others => '0');
            rx_data_o       <= (others => '0');
            
        elsif rising_edge(clk_i) then
            -- Default values for pulsed signals
            rx_valid_o    <= '0';
            bits_done_s   <= '0';
            
            -- SPI clock edge tracking
            sclk_prev_s <= sclk_s;
            
            -- FSM
            case current_state_s is
                when IDLE_ST =>
                    -- Reset signals
                    sclk_s        <= CPOL_g;
                    cs_n_s        <= '1';
                    sclk_enable_s <= '0';
                    bit_counter_s <= 0;
                    
                    -- Start new transaction when requested
                    if start_i = '1' then
                        current_state_s <= TRANSFER_ST;
                        tx_shift_reg_s  <= tx_data_i;
                        cs_n_s          <= '0';  -- Assert chip select
                        sclk_enable_s   <= '1';  -- Enable clock
                    end if;
                    
                when TRANSFER_ST =>
                    -- Sample data on appropriate clock edge
                    if sample_edge_s = '1' then
                        if MSB_FIRST_g then
                            -- MSB first shift operation
                            rx_shift_reg_s <= rx_shift_reg_s(DATA_WIDTH_g-2 downto 0) & spi_miso_i;
                        else
                            -- LSB first shift operation
                            rx_shift_reg_s <= spi_miso_i & rx_shift_reg_s(DATA_WIDTH_g-1 downto 1);
                        end if;
                    end if;
                    
                    -- Shift data on appropriate clock edge
                    if shift_edge_s = '1' then
                        -- Increment bit counter
                        if bit_counter_s = DATA_WIDTH_g-1 then
                            bit_counter_s <= 0;
                            bits_done_s   <= '1';
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
                    
                    -- Move to complete state when all bits are done
                    if bits_done_s = '1' then
                        current_state_s <= COMPLETE_ST;
                        sclk_enable_s   <= '0';  -- Disable clock
                    end if;
                    
                when COMPLETE_ST =>
                    -- Output received data
                    rx_data_o  <= rx_shift_reg_s;
                    rx_valid_o <= '1';
                    cs_n_s     <= '1';  -- Deassert chip select
                    
                    -- Return to idle
                    current_state_s <= IDLE_ST;
                    
            end case;
        end if;
    end process spi_control_proc;
    
    -- SPI clock generation process
    spi_clk_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            sclk_counter_s <= 0;
            sclk_s         <= CPOL_g;
            
        elsif rising_edge(clk_i) then
            if sclk_enable_s = '1' then
                -- Generate SPI clock based on counter
                if sclk_counter_s = CLK_DIV_HALF_c-1 then
                    sclk_s         <= not sclk_s;  -- Toggle clock
                    sclk_counter_s <= 0;
                else
                    sclk_counter_s <= sclk_counter_s + 1;
                end if;
            else
                -- Reset to idle polarity when disabled
                sclk_s         <= CPOL_g;
                sclk_counter_s <= 0;
            end if;
        end if;
    end process spi_clk_proc;

end architecture rtl; 