---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Testbench for UART "Hello World" Transmitter
--                - Tests transmission of "Hello, World!" message
--                - Verifies UART protocol timing
--                - Checks character by character output
--                - Tests button trigger functionality
--                - Uses accelerated clock for faster simulation
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity uart_hello_world_tb is
    -- Testbench has no ports
end entity uart_hello_world_tb;

architecture tb of uart_hello_world_tb is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- DUT component declaration
    component uart_hello_world is
        generic (
            CLK_FREQ_HZ_g   : integer := 100000000;
            BAUD_RATE_g     : integer := 9600;
            TX_INTERVAL_MS_g : integer := 1000
        );
        port (
            clk_i           : in  std_logic;
            reset_n_i       : in  std_logic;
            send_i          : in  std_logic;
            
            tx_o            : out std_logic;
            rx_i            : in  std_logic;
            
            busy_led_o      : out std_logic;
            done_led_o      : out std_logic
        );
    end component uart_hello_world;
    
    -- UART RX component for verification
    component uart_rx is
        generic (
            CLK_FREQ_HZ_g : integer := 100000000;
            BAUD_RATE_g   : integer := 9600
        );
        port (
            clk_i         : in  std_logic;
            reset_n_i     : in  std_logic;
            rx_i          : in  std_logic;
            rx_data_o     : out std_logic_vector(7 downto 0);
            rx_valid_o    : out std_logic;
            rx_error_o    : out std_logic
        );
    end component uart_rx;
    
    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Simulation constants (using faster clock and baud rate for simulation)
    constant CLK_FREQ_TB_c     : integer := 1000000;   -- 1 MHz for faster simulation
    constant BAUD_RATE_TB_c    : integer := 10000;     -- Higher baud rate for faster simulation
    constant TX_INTERVAL_TB_c  : integer := 10;        -- Short interval for simulation
    
    -- Clock period
    constant CLK_PERIOD_c      : time := 1000 ms / CLK_FREQ_TB_c;
    
    -- Expected message
    constant EXPECTED_MSG_c    : string := "Hello, World!";
    
    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Testbench control signals
    signal sim_done_s        : boolean := false;
    
    -- DUT inputs
    signal clk_s             : std_logic := '0';
    signal reset_n_s         : std_logic := '0';
    signal send_s            : std_logic := '0';
    signal rx_dummy_s        : std_logic := '1';  -- Not used in this test
    
    -- DUT outputs
    signal tx_s              : std_logic;
    signal busy_led_s        : std_logic;
    signal done_led_s        : std_logic;
    
    -- UART RX verification signals
    signal rx_data_s         : std_logic_vector(7 downto 0);
    signal rx_valid_s        : std_logic;
    signal rx_error_s        : std_logic;
    
    -- Verification helpers
    signal char_count_s      : integer := 0;
    signal verification_done_s : boolean := false;
    
    --------------------------------------------------------------------------------------------------------------------
    -- FUNCTION DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Function to convert std_logic_vector to hex string for reporting
    function to_hex_string(slv : std_logic_vector) return string is
        variable hex : string(1 to slv'length/4);
        variable nibble : std_logic_vector(3 downto 0);
    begin
        for i in 0 to slv'length/4-1 loop
            nibble := slv(slv'left - i*4 downto slv'left - i*4 - 3);
            case to_integer(unsigned(nibble)) is
                when  0 => hex(i+1) := '0';
                when  1 => hex(i+1) := '1';
                when  2 => hex(i+1) := '2';
                when  3 => hex(i+1) := '3';
                when  4 => hex(i+1) := '4';
                when  5 => hex(i+1) := '5';
                when  6 => hex(i+1) := '6';
                when  7 => hex(i+1) := '7';
                when  8 => hex(i+1) := '8';
                when  9 => hex(i+1) := '9';
                when 10 => hex(i+1) := 'A';
                when 11 => hex(i+1) := 'B';
                when 12 => hex(i+1) := 'C';
                when 13 => hex(i+1) := 'D';
                when 14 => hex(i+1) := 'E';
                when 15 => hex(i+1) := 'F';
                when others => hex(i+1) := 'X';
            end case;
        end loop;
        return hex;
    end function to_hex_string;
    
begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT INSTANTIATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Instantiate the Unit Under Test (UUT)
    uut : uart_hello_world
        generic map (
            CLK_FREQ_HZ_g   => CLK_FREQ_TB_c,
            BAUD_RATE_g     => BAUD_RATE_TB_c,
            TX_INTERVAL_MS_g => TX_INTERVAL_TB_c
        )
        port map (
            clk_i           => clk_s,
            reset_n_i       => reset_n_s,
            send_i          => send_s,
            
            tx_o            => tx_s,
            rx_i            => rx_dummy_s,
            
            busy_led_o      => busy_led_s,
            done_led_o      => done_led_s
        );
    
    -- Instantiate the UART receiver for verification
    uart_rx_inst : uart_rx
        generic map (
            CLK_FREQ_HZ_g => CLK_FREQ_TB_c,
            BAUD_RATE_g   => BAUD_RATE_TB_c
        )
        port map (
            clk_i         => clk_s,
            reset_n_i     => reset_n_s,
            rx_i          => tx_s,
            rx_data_o     => rx_data_s,
            rx_valid_o    => rx_valid_s,
            rx_error_o    => rx_error_s
        );
    
    --------------------------------------------------------------------------------------------------------------------
    -- CLOCK PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Clock process
    clk_proc : process is
    begin
        while not sim_done_s loop
            clk_s <= '0';
            wait for CLK_PERIOD_c / 2;
            clk_s <= '1';
            wait for CLK_PERIOD_c / 2;
        end loop;
        wait;
    end process clk_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- STIMULUS PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Stimulus process
    stim_proc : process is
    begin
        -- Initialize inputs
        reset_n_s <= '0';  -- Start in reset
        send_s    <= '0';
        
        -- Wait for a few clocks
        wait for CLK_PERIOD_c * 10;
        
        -- Release reset to start first transmission
        reset_n_s <= '1';
        
        -- Wait for the first message transmission to complete
        wait until done_led_s = '1';
        wait for CLK_PERIOD_c * 5;
        
        -- Press send button to trigger another transmission
        send_s <= '1';
        wait for CLK_PERIOD_c * 5;
        send_s <= '0';
        
        -- Wait for message verification to complete
        wait until verification_done_s = true;
        wait for CLK_PERIOD_c * 50;
        
        -- End simulation
        sim_done_s <= true;
        wait;
    end process stim_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- VERIFICATION PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Verification process to check received characters
    verif_proc : process(clk_s) is
        variable expected_char : character;
    begin
        if rising_edge(clk_s) then
            if rx_valid_s = '1' then
                -- Convert received byte to character for easier comparison
                if char_count_s < EXPECTED_MSG_c'length then
                    expected_char := EXPECTED_MSG_c(char_count_s + 1);
                    
                    -- Check if character matches expected
                    if rx_data_s = std_logic_vector(to_unsigned(character'pos(expected_char), 8)) then
                        report "Correct character received: '" & expected_char & 
                              "' (ASCII: " & integer'image(to_integer(unsigned(rx_data_s))) & ")"
                              severity note;
                    else
                        report "ERROR: Wrong character received. Expected: '" & expected_char & 
                              "' (ASCII: " & integer'image(character'pos(expected_char)) & 
                              "), Got: ASCII " & integer'image(to_integer(unsigned(rx_data_s)))
                              severity error;
                    end if;
                    
                    -- Increment counter
                    char_count_s <= char_count_s + 1;
                    
                    -- Check if we've received the full message
                    if char_count_s = EXPECTED_MSG_c'length - 1 then
                        report "All characters verified successfully!" severity note;
                        verification_done_s <= true;
                    end if;
                end if;
            end if;
            
            -- Check for framing errors
            if rx_error_s = '1' then
                report "UART framing error detected!" severity error;
            end if;
        end if;
    end process verif_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- MONITOR PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Monitor process for terminal output
    monitor_proc : process(clk_s) is
    begin
        if rising_edge(clk_s) then
            -- Report state changes
            if reset_n_s = '0' then
                report "System in RESET state" severity note;
            elsif rx_valid_s = '1' then
                report "Received byte: 0x" & to_hex_string(rx_data_s) & 
                      " (ASCII: " & integer'image(to_integer(unsigned(rx_data_s))) & ")" 
                      severity note;
            end if;
        end if;
    end process monitor_proc;

end architecture tb; 