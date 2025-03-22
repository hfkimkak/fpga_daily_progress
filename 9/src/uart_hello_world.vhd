---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  UART "Hello World" Transmitter
--                - Sends "Hello, World!" string over UART
--                - Uses internal ROM to store the message
--                - Auto-transmits on reset or button press
--                - LED indicators for transmission status
--                - Simple example of UART protocol implementation
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity uart_hello_world is
    generic (
        CLK_FREQ_HZ_g   : integer := 100000000;  --! System clock frequency in Hz
        BAUD_RATE_g     : integer := 9600;       --! UART baud rate
        TX_INTERVAL_MS_g : integer := 1000       --! Time between message transmissions in ms
    );
    port (
        clk_i           : in  std_logic;          --! System clock
        reset_n_i       : in  std_logic;          --! Active low reset
        send_i          : in  std_logic;          --! Send button - starts transmission
        
        -- UART signals
        tx_o            : out std_logic;          --! UART TX output
        rx_i            : in  std_logic;          --! UART RX input (not used in this example)
        
        -- Status LEDs
        busy_led_o      : out std_logic;          --! Transmission in progress
        done_led_o      : out std_logic           --! Transmission completed
    );
end entity uart_hello_world;

architecture rtl of uart_hello_world is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- UART Transmitter component
    component uart_tx is
        generic (
            CLK_FREQ_HZ_g : integer := 100000000;
            BAUD_RATE_g   : integer := 9600
        );
        port (
            clk_i         : in  std_logic;
            reset_n_i     : in  std_logic;
            tx_data_i     : in  std_logic_vector(7 downto 0);
            tx_valid_i    : in  std_logic;
            tx_ready_o    : out std_logic;
            tx_o          : out std_logic
        );
    end component uart_tx;
    
    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- "Hello, World!" message (13 characters + null terminator)
    constant MESSAGE_LEN_c     : integer := 14;
    type message_rom_t is array (0 to MESSAGE_LEN_c-1) of std_logic_vector(7 downto 0);
    constant MESSAGE_ROM_c     : message_rom_t := (
        0  => x"48",  -- H
        1  => x"65",  -- e
        2  => x"6C",  -- l
        3  => x"6C",  -- l
        4  => x"6F",  -- o
        5  => x"2C",  -- ,
        6  => x"20",  -- (space)
        7  => x"57",  -- W
        8  => x"6F",  -- o
        9  => x"72",  -- r
        10 => x"6C",  -- l
        11 => x"64",  -- d
        12 => x"21",  -- !
        13 => x"00"   -- NULL terminator
    );
    
    -- Interval timer values
    constant MS_COUNT_c        : integer := CLK_FREQ_HZ_g / 1000;
    constant TX_INTERVAL_CNT_c : integer := TX_INTERVAL_MS_g;
    
    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Transmitter FSM states
    type tx_fsm_state_t is (
        IDLE_ST,           --! Waiting for trigger
        TRANSMITTING_ST,   --! Sending the message
        WAIT_INTERVAL_ST   --! Waiting between transmissions
    );
    
    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- UART TX signals
    signal tx_data_s       : std_logic_vector(7 downto 0);
    signal tx_valid_s      : std_logic;
    signal tx_ready_s      : std_logic;
    
    -- FSM signals
    signal current_state_s : tx_fsm_state_t := IDLE_ST;
    signal char_index_s    : integer range 0 to MESSAGE_LEN_c-1 := 0;
    
    -- Timing signals
    signal ms_counter_s    : integer range 0 to MS_COUNT_c-1 := 0;
    signal ms_tick_s       : std_logic;
    signal interval_cnt_s  : integer range 0 to TX_INTERVAL_CNT_c-1 := 0;
    
    -- Button debouncing
    signal send_sync_s     : std_logic_vector(1 downto 0);
    signal send_pulse_s    : std_logic;
    
begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT INSTANTIATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- UART transmitter instance
    uart_tx_inst : uart_tx
        generic map (
            CLK_FREQ_HZ_g => CLK_FREQ_HZ_g,
            BAUD_RATE_g   => BAUD_RATE_g
        )
        port map (
            clk_i         => clk_i,
            reset_n_i     => reset_n_i,
            tx_data_i     => tx_data_s,
            tx_valid_i    => tx_valid_s,
            tx_ready_o    => tx_ready_s,
            tx_o          => tx_o
        );
    
    --------------------------------------------------------------------------------------------------------------------
    -- COMBINATIONAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- Status LED output
    busy_led_o <= '1' when current_state_s = TRANSMITTING_ST else '0';
    done_led_o <= '1' when (current_state_s = WAIT_INTERVAL_ST) or 
                            (current_state_s = IDLE_ST and char_index_s > 0) else '0';
    
    -- Button input edge detection
    send_pulse_s <= send_sync_s(0) and not send_sync_s(1);
    
    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL LOGIC
    --------------------------------------------------------------------------------------------------------------------
    
    -- Button input synchronization and debouncing
    sync_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            send_sync_s <= (others => '0');
        elsif rising_edge(clk_i) then
            send_sync_s <= send_sync_s(0) & send_i;
        end if;
    end process sync_proc;
    
    -- Millisecond tick generator for timing
    ms_tick_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            ms_counter_s <= 0;
            ms_tick_s    <= '0';
        elsif rising_edge(clk_i) then
            ms_tick_s <= '0';  -- Default, pulse only for one cycle
            
            if ms_counter_s = MS_COUNT_c-1 then
                ms_counter_s <= 0;
                ms_tick_s    <= '1';
            else
                ms_counter_s <= ms_counter_s + 1;
            end if;
        end if;
    end process ms_tick_proc;
    
    -- Main transmission FSM
    tx_fsm_proc : process(clk_i, reset_n_i) is
    begin
        if reset_n_i = '0' then
            current_state_s <= IDLE_ST;
            char_index_s    <= 0;
            interval_cnt_s  <= 0;
            tx_data_s       <= (others => '0');
            tx_valid_s      <= '0';
            
        elsif rising_edge(clk_i) then
            -- Default values
            tx_valid_s <= '0';
            
            case current_state_s is
                when IDLE_ST =>
                    -- Wait for trigger (reset release or button press)
                    if send_pulse_s = '1' or char_index_s = 0 then
                        current_state_s <= TRANSMITTING_ST;
                        char_index_s    <= 0;
                    end if;
                    
                when TRANSMITTING_ST =>
                    -- Transmit each character of the message
                    if tx_ready_s = '1' and tx_valid_s = '0' then
                        tx_data_s  <= MESSAGE_ROM_c(char_index_s);
                        tx_valid_s <= '1';
                        
                        -- Move to next character or finish
                        if char_index_s = MESSAGE_LEN_c-1 or MESSAGE_ROM_c(char_index_s) = x"00" then
                            char_index_s    <= MESSAGE_LEN_c-1;  -- Stay at last character
                            current_state_s <= WAIT_INTERVAL_ST;
                            interval_cnt_s  <= 0;
                        else
                            char_index_s <= char_index_s + 1;
                        end if;
                    end if;
                    
                when WAIT_INTERVAL_ST =>
                    -- Wait for the specified interval before being ready to transmit again
                    if ms_tick_s = '1' then
                        if interval_cnt_s = TX_INTERVAL_CNT_c-1 then
                            current_state_s <= IDLE_ST;
                        else
                            interval_cnt_s <= interval_cnt_s + 1;
                        end if;
                    end if;
                    
            end case;
        end if;
    end process tx_fsm_proc;

end architecture rtl; 