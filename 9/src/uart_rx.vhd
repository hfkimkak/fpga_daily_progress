---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  UART Receiver Module
--                - Configurable baud rate
--                - 8-bit data, 1 start bit, 1 stop bit, no parity
--                - Reset input
--                - Oversampling for robust reception
--                - Data ready flag
--                - Standard UART protocol deserializer
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity uart_rx is
    generic (
        CLK_FREQ_HZ_g : integer := 100000000;  --! System clock frequency in Hz
        BAUD_RATE_g   : integer := 9600         --! UART baud rate
    );
    port (
        clk_i         : in  std_logic;          --! System clock
        reset_n_i     : in  std_logic;          --! Active low reset
        rx_i          : in  std_logic;          --! Serial data input
        rx_data_o     : out std_logic_vector(7 downto 0); --! Received data
        rx_valid_o    : out std_logic;          --! Data valid - high for one clock when data received
        rx_error_o    : out std_logic           --! Framing error detected
    );
end entity uart_rx;

architecture rtl of uart_rx is

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Calculate the number of clock cycles per bit for the given baud rate
    constant CYCLES_PER_BIT_c    : integer := CLK_FREQ_HZ_g / BAUD_RATE_g;
    
    -- Use 16x oversampling for better noise immunity
    constant OVERSAMPLE_RATE_c   : integer := 16;
    constant OVERSAMPLE_COUNT_c  : integer := CYCLES_PER_BIT_c / OVERSAMPLE_RATE_c;
    
    -- Middle sample point (used for reading data bits)
    constant SAMPLE_POINT_c      : integer := OVERSAMPLE_RATE_c / 2;
    
    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- FSM state definition
    type rx_state_t is (
        IDLE_ST,      --! Idle state - waiting for start bit
        START_BIT_ST, --! Verifying start bit
        DATA_BITS_ST, --! Receiving 8 data bits (LSB first)
        STOP_BIT_ST   --! Verifying stop bit
    );
    
    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Input synchronization registers to prevent metastability
    signal rx_sync1_s      : std_logic;
    signal rx_sync2_s      : std_logic;  -- Synchronized rx input
    
    -- FSM signals
    signal current_state_s : rx_state_t := IDLE_ST;
    signal next_state_s    : rx_state_t;
    
    -- Bit counter and data registers
    signal bit_counter_s   : integer range 0 to 7 := 0;
    signal oversample_cnt_s : integer range 0 to OVERSAMPLE_RATE_c - 1 := 0;
    signal bit_timer_s     : integer range 0 to OVERSAMPLE_COUNT_c - 1 := 0;
    signal shift_reg_s     : std_logic_vector(7 downto 0);
    
    -- Control signals
    signal sample_point_s  : std_logic;
    signal bit_done_s      : std_logic;
    
begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- FSM next state and output logic
    rx_proc : process(current_state_s, rx_sync2_s, bit_counter_s, sample_point_s, bit_done_s, shift_reg_s) is
    begin
        -- Default assignments
        next_state_s <= current_state_s;
        rx_valid_o   <= '0';
        rx_error_o   <= '0';
        
        case current_state_s is
            when IDLE_ST =>
                -- Look for start bit (falling edge)
                if rx_sync2_s = '0' then
                    next_state_s <= START_BIT_ST;
                end if;
                
            when START_BIT_ST =>
                -- Verify start bit at sample point
                if sample_point_s = '1' then
                    if rx_sync2_s = '0' then
                        -- Valid start bit
                        next_state_s <= DATA_BITS_ST;
                    else
                        -- Invalid start bit, go back to idle
                        next_state_s <= IDLE_ST;
                    end if;
                end if;
                
            when DATA_BITS_ST =>
                -- Sample each data bit at the sample point
                if bit_done_s = '1' then
                    if bit_counter_s = 7 then
                        next_state_s <= STOP_BIT_ST;
                    end if;
                end if;
                
            when STOP_BIT_ST =>
                -- Verify stop bit at sample point
                if sample_point_s = '1' then
                    if rx_sync2_s = '1' then
                        -- Valid stop bit - output data
                        rx_valid_o <= '1';
                    else
                        -- Invalid stop bit - framing error
                        rx_error_o <= '1';
                    end if;
                    next_state_s <= IDLE_ST;
                end if;
                
        end case;
    end process rx_proc;
    
    -- Output assignment
    rx_data_o <= shift_reg_s;
    
    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- Input synchronization to prevent metastability
    sync_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            rx_sync1_s <= '1';  -- Default idle state is high
            rx_sync2_s <= '1';
        elsif rising_edge(clk_i) then
            rx_sync1_s <= rx_i;
            rx_sync2_s <= rx_sync1_s;
        end if;
    end process sync_proc;
    
    -- FSM state register and data handling
    fsm_reg_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            current_state_s  <= IDLE_ST;
            bit_counter_s    <= 0;
            oversample_cnt_s <= 0;
            bit_timer_s      <= 0;
            shift_reg_s      <= (others => '0');
            sample_point_s   <= '0';
            bit_done_s       <= '0';
            
        elsif rising_edge(clk_i) then
            -- Default values
            sample_point_s <= '0';
            bit_done_s     <= '0';
            
            -- State register update
            current_state_s <= next_state_s;
            
            -- Oversampling counter and bit timer
            case current_state_s is
                when IDLE_ST =>
                    -- Reset counters when idle
                    oversample_cnt_s <= 0;
                    bit_timer_s      <= 0;
                    bit_counter_s    <= 0;
                    
                    -- If going to START_BIT state, initialize oversample counter to middle
                    if next_state_s = START_BIT_ST then
                        oversample_cnt_s <= OVERSAMPLE_RATE_c / 4;  -- Start at 1/4 bit time for better centering
                    end if;
                    
                when others =>
                    -- In all other states, run the oversampling counter
                    if bit_timer_s = OVERSAMPLE_COUNT_c - 1 then
                        bit_timer_s <= 0;
                        
                        if oversample_cnt_s = OVERSAMPLE_RATE_c - 1 then
                            oversample_cnt_s <= 0;
                            bit_done_s <= '1';
                            
                            -- Increment bit counter in DATA_BITS state
                            if current_state_s = DATA_BITS_ST then
                                if bit_counter_s = 7 then
                                    bit_counter_s <= 0;
                                else
                                    bit_counter_s <= bit_counter_s + 1;
                                end if;
                            end if;
                        else
                            oversample_cnt_s <= oversample_cnt_s + 1;
                            
                            -- Set sample point flag at the middle of the bit
                            if oversample_cnt_s = SAMPLE_POINT_c then
                                sample_point_s <= '1';
                                
                                -- In DATA_BITS state, shift in the received bit
                                if current_state_s = DATA_BITS_ST then
                                    shift_reg_s <= rx_sync2_s & shift_reg_s(7 downto 1);  -- LSB first
                                end if;
                            end if;
                        end if;
                    else
                        bit_timer_s <= bit_timer_s + 1;
                    end if;
            end case;
        end if;
    end process fsm_reg_proc;

end architecture rtl; 