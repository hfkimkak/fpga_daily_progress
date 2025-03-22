---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  UART Transmitter Module
--                - Configurable baud rate
--                - 8-bit data, 1 start bit, 1 stop bit, no parity
--                - Reset input
--                - Standard UART protocol serializer
--                - FIFO interface ready (though not implemented here)
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity uart_tx is
    generic (
        CLK_FREQ_HZ_g : integer := 100000000;  --! System clock frequency in Hz
        BAUD_RATE_g   : integer := 9600         --! UART baud rate
    );
    port (
        clk_i         : in  std_logic;          --! System clock
        reset_n_i     : in  std_logic;          --! Active low reset
        tx_data_i     : in  std_logic_vector(7 downto 0); --! Data to transmit
        tx_valid_i    : in  std_logic;          --! Data valid - initiates transmission when high
        tx_ready_o    : out std_logic;          --! Transmitter ready for next byte
        tx_o          : out std_logic           --! Serial data output
    );
end entity uart_tx;

architecture rtl of uart_tx is

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Calculate the number of clock cycles per bit for the given baud rate
    constant CYCLES_PER_BIT_c : integer := CLK_FREQ_HZ_g / BAUD_RATE_g;
    
    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- FSM state definition
    type tx_state_t is (
        IDLE_ST,      --! Idle state - waiting for data
        START_BIT_ST, --! Sending start bit (logic '0')
        DATA_BITS_ST, --! Sending 8 data bits (LSB first)
        STOP_BIT_ST   --! Sending stop bit (logic '1')
    );
    
    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- FSM signals
    signal current_state_s : tx_state_t := IDLE_ST;
    signal next_state_s    : tx_state_t;
    
    -- Bit counter and data registers
    signal bit_counter_s   : integer range 0 to 7 := 0;
    signal bit_timer_s     : integer range 0 to CYCLES_PER_BIT_c - 1 := 0;
    signal shift_reg_s     : std_logic_vector(7 downto 0);
    
    -- Control signals
    signal load_data_s     : std_logic;
    signal shift_data_s    : std_logic;
    signal bit_done_s      : std_logic;
    
begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- Output assignments
    tx_ready_o <= '1' when current_state_s = IDLE_ST else '0';
    
    -- FSM next state and output logic
    tx_proc : process(current_state_s, tx_valid_i, bit_counter_s, bit_done_s, shift_reg_s) is
    begin
        -- Default assignments
        next_state_s <= current_state_s;
        load_data_s  <= '0';
        shift_data_s <= '0';
        tx_o         <= '1';  -- Idle state is high
        
        case current_state_s is
            when IDLE_ST =>
                tx_o <= '1';  -- Idle state - line high
                
                if tx_valid_i = '1' then
                    next_state_s <= START_BIT_ST;
                    load_data_s  <= '1';  -- Load data for transmission
                end if;
                
            when START_BIT_ST =>
                tx_o <= '0';  -- Start bit - line low
                
                if bit_done_s = '1' then
                    next_state_s <= DATA_BITS_ST;
                end if;
                
            when DATA_BITS_ST =>
                tx_o <= shift_reg_s(0);  -- LSB first
                
                if bit_done_s = '1' then
                    shift_data_s <= '1';  -- Shift data for next bit
                    
                    if bit_counter_s = 7 then
                        next_state_s <= STOP_BIT_ST;
                    end if;
                end if;
                
            when STOP_BIT_ST =>
                tx_o <= '1';  -- Stop bit - line high
                
                if bit_done_s = '1' then
                    next_state_s <= IDLE_ST;
                end if;
                
        end case;
    end process tx_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- FSM state register and data handling
    fsm_reg_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            current_state_s <= IDLE_ST;
            bit_counter_s   <= 0;
            bit_timer_s     <= 0;
            shift_reg_s     <= (others => '0');
            bit_done_s      <= '0';
            
        elsif rising_edge(clk_i) then
            -- Default value
            bit_done_s <= '0';
            
            -- State register update
            current_state_s <= next_state_s;
            
            -- Load data when requested
            if load_data_s = '1' then
                shift_reg_s <= tx_data_i;
            end if;
            
            -- Bit timer
            if current_state_s = IDLE_ST then
                bit_timer_s <= 0;
            elsif bit_timer_s = CYCLES_PER_BIT_c - 1 then
                bit_timer_s <= 0;
                bit_done_s  <= '1';
                
                -- Handle bit counter
                if current_state_s = DATA_BITS_ST then
                    if bit_counter_s = 7 then
                        bit_counter_s <= 0;
                    else
                        bit_counter_s <= bit_counter_s + 1;
                    end if;
                else
                    bit_counter_s <= 0;
                end if;
                
                -- Shift register
                if shift_data_s = '1' then
                    shift_reg_s <= '0' & shift_reg_s(7 downto 1);  -- Shift right, LSB first
                end if;
            else
                bit_timer_s <= bit_timer_s + 1;
            end if;
        end if;
    end process fsm_reg_proc;

end architecture rtl; 