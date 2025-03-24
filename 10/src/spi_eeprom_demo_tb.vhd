---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Testbench for SPI EEPROM Demo
--                - Tests the SPI EEPROM Demo module in various scenarios
--                - Simulates button presses to initiate read/write operations
--                - Verifies LED outputs for operation status
--                - Monitors SPI signals for correctness
--                - Automatically checks success of operations
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity spi_eeprom_demo_tb is
end entity spi_eeprom_demo_tb;

architecture sim of spi_eeprom_demo_tb is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    component spi_eeprom_demo is
        generic (
            CLK_FREQ_HZ_g       : integer := 100000000;  -- System clock frequency in Hz
            SPI_CLK_FREQ_HZ_g   : integer := 1000000;    -- SPI clock frequency in Hz
            MEM_SIZE_BYTES_g    : integer := 128;        -- EEPROM size in bytes
            ADDRESS_WIDTH_g     : integer := 7;          -- EEPROM address width
            DATA_WIDTH_g        : integer := 8           -- Data width (8 bits for EEPROM)
        );
        port (
            clk_i               : in  std_logic;         -- System clock
            reset_n_i           : in  std_logic;         -- Active low reset
            
            -- User interface
            btn_write_i         : in  std_logic;         -- Button to initiate write operation
            btn_read_i          : in  std_logic;         -- Button to initiate read operation
            
            -- Status LEDs
            led_busy_o          : out std_logic;         -- Operation in progress
            led_success_o       : out std_logic;         -- Operation completed successfully
            led_error_o         : out std_logic;         -- Error occurred
            
            -- SPI pins (connection to external EEPROM)
            spi_sclk_o          : out std_logic;         -- SPI clock
            spi_mosi_o          : out std_logic;         -- Master Out Slave In
            spi_miso_i          : in  std_logic;         -- Master In Slave Out
            spi_cs_n_o          : out std_logic          -- Chip select (active low)
        );
    end component spi_eeprom_demo;
    
    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Clock and reset parameters
    constant CLK_PERIOD_c     : time := 10 ns;  -- 100 MHz system clock
    constant RESET_DURATION_c : time := 100 ns; -- Initial reset duration
    
    -- Test parameters (using reduced frequencies for faster simulation)
    constant TB_CLK_FREQ_HZ_c   : integer := 100000000; -- 100 MHz
    constant TB_SPI_CLK_FREQ_HZ_c : integer := 10000000; -- 10 MHz for faster simulation
    
    -- Button control
    constant BTN_PULSE_DURATION_c : time := 50 ns;  -- Duration of button press
    constant BTN_WAIT_DURATION_c  : time := 100 ns; -- Wait time after button release
    
    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Clock and reset
    signal clk_s           : std_logic := '0';
    signal reset_n_s       : std_logic := '0';
    signal simulation_done_s : boolean := false;
    
    -- User interface
    signal btn_write_s     : std_logic := '0';
    signal btn_read_s      : std_logic := '0';
    
    -- Status LEDs
    signal led_busy_s      : std_logic;
    signal led_success_s   : std_logic;
    signal led_error_s     : std_logic;
    
    -- SPI signals
    signal spi_sclk_s      : std_logic;
    signal spi_mosi_s      : std_logic;
    signal spi_miso_s      : std_logic := '0';
    signal spi_cs_n_s      : std_logic;
    
    -- Test control
    signal test_phase_s    : integer := 0;
    signal test_success_s  : boolean := true;
    
    -- For monitoring transactions
    signal monitoring_active_s : boolean := false;
    
begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT INSTANTIATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- DUT: SPI EEPROM Demo
    uut : spi_eeprom_demo
        generic map (
            CLK_FREQ_HZ_g     => TB_CLK_FREQ_HZ_c,
            SPI_CLK_FREQ_HZ_g => TB_SPI_CLK_FREQ_HZ_c,
            MEM_SIZE_BYTES_g  => 128,
            ADDRESS_WIDTH_g   => 7,
            DATA_WIDTH_g      => 8
        )
        port map (
            clk_i         => clk_s,
            reset_n_i     => reset_n_s,
            btn_write_i   => btn_write_s,
            btn_read_i    => btn_read_s,
            led_busy_o    => led_busy_s,
            led_success_o => led_success_s,
            led_error_o   => led_error_s,
            spi_sclk_o    => spi_sclk_s,
            spi_mosi_o    => spi_mosi_s,
            spi_miso_i    => spi_miso_s,
            spi_cs_n_o    => spi_cs_n_s
        );
    
    --------------------------------------------------------------------------------------------------------------------
    -- CLOCK AND RESET GENERATION
    --------------------------------------------------------------------------------------------------------------------
    
    -- Clock generation process
    clk_gen_proc : process
    begin
        while not simulation_done_s loop
            clk_s <= '0';
            wait for CLK_PERIOD_c / 2;
            clk_s <= '1';
            wait for CLK_PERIOD_c / 2;
        end loop;
        wait;
    end process clk_gen_proc;
    
    -- Reset generation process
    reset_gen_proc : process
    begin
        reset_n_s <= '0';
        wait for RESET_DURATION_c;
        reset_n_s <= '1';
        wait;
    end process reset_gen_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- STIMULUS PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Main test sequence
    stim_proc : process
    begin
        -- Wait for reset to complete
        wait until reset_n_s = '1';
        wait for 100 ns;
        
        -- Test Phase 1: EEPROM write operation
        test_phase_s <= 1;
        report "Starting Test Phase 1: EEPROM Write Operation";
        
        -- Press write button
        wait for 500 ns;
        btn_write_s <= '1';
        wait for BTN_PULSE_DURATION_c;
        btn_write_s <= '0';
        
        -- Wait for operation to complete (busy LED goes off)
        wait until led_busy_s = '0' and led_success_s = '1';
        wait for BTN_WAIT_DURATION_c;
        
        -- Verify success LED
        assert led_success_s = '1' report "Test Phase 1 Failed: Write operation unsuccessful" severity error;
        assert led_error_s = '0' report "Test Phase 1 Failed: Error LED should be off after successful write" severity error;
        
        -- Test Phase 2: EEPROM read operation
        test_phase_s <= 2;
        report "Starting Test Phase 2: EEPROM Read Operation";
        
        -- Press read button
        wait for 500 ns;
        btn_read_s <= '1';
        wait for BTN_PULSE_DURATION_c;
        btn_read_s <= '0';
        
        -- Wait for operation to complete (busy LED goes off)
        wait until led_busy_s = '0';
        wait for BTN_WAIT_DURATION_c;
        
        -- Verify success LED
        assert led_success_s = '1' report "Test Phase 2 Failed: Read operation unsuccessful" severity error;
        assert led_error_s = '0' report "Test Phase 2 Failed: Error LED should be off after successful read" severity error;
        
        -- Test Phase 3: Verify a full write + read cycle with monitoring
        test_phase_s <= 3;
        report "Starting Test Phase 3: Full Write/Read Cycle with Monitoring";
        
        -- Enable SPI transaction monitoring
        monitoring_active_s <= true;
        
        -- Press write button
        wait for 500 ns;
        btn_write_s <= '1';
        wait for BTN_PULSE_DURATION_c;
        btn_write_s <= '0';
        
        -- Wait for operation to complete
        wait until led_busy_s = '0';
        wait for BTN_WAIT_DURATION_c;
        
        -- Press read button
        wait for 500 ns;
        btn_read_s <= '1';
        wait for BTN_PULSE_DURATION_c;
        btn_read_s <= '0';
        
        -- Wait for operation to complete
        wait until led_busy_s = '0';
        wait for BTN_WAIT_DURATION_c;
        
        -- Disable SPI transaction monitoring
        monitoring_active_s <= false;
        
        -- Verify success LED
        assert led_success_s = '1' report "Test Phase 3 Failed: Full cycle unsuccessful" severity error;
        
        -- Final wait and end simulation
        wait for 1 us;
        report "All tests completed. Test " & 
               -- (if test_success_s then "PASSED" else "FAILED") & 
               " at time " & time'image(now);
        
        simulation_done_s <= true;
        wait;
    end process stim_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- MONITORING PROCESSES
    --------------------------------------------------------------------------------------------------------------------
    
    -- SPI transaction monitoring
    spi_monitor_proc : process
        variable start_time : time;
        variable end_time : time;
        variable byte_count : integer := 0;
    begin
        loop
            wait until falling_edge(spi_cs_n_s) or simulation_done_s;
            
            if simulation_done_s then
                exit;
            end if;
            
            -- Check if monitoring is active
            if monitoring_active_s then
                start_time := now;
                report "SPI Transaction Started at " & time'image(now);
                byte_count := 0;
                
                -- Monitor transaction
                while spi_cs_n_s = '0' and not simulation_done_s loop
                    -- Count bytes by detecting 8 clock cycles
                    for i in 1 to 8 loop
                        wait until rising_edge(spi_sclk_s) or rising_edge(spi_cs_n_s) or simulation_done_s;
                        if spi_cs_n_s = '1' or simulation_done_s then
                            exit;
                        end if;
                    end loop;
                    
                    if spi_cs_n_s = '0' then
                        byte_count := byte_count + 1;
                    end if;
                    
                    if simulation_done_s then
                        exit;
                    end if;
                end loop;
                
                end_time := now;
                report "SPI Transaction Ended at " & time'image(now);
                report "Transaction duration: " & time'image(end_time - start_time);
                report "Bytes transferred: " & integer'image(byte_count);
            end if;
            
            if simulation_done_s then
                exit;
            end if;
        end loop;
        
        wait;
    end process spi_monitor_proc;
    
    -- LED status monitoring (for debug purposes)
    led_monitor_proc : process(clk_s)
    begin
        if rising_edge(clk_s) then
            if led_busy_s = '1' then
                -- Operation in progress
            elsif led_success_s = '1' and led_error_s = '0' then
                -- Successful operation
            elsif led_success_s = '0' and led_error_s = '1' then
                -- Failed operation - flag as test failure
                test_success_s <= false;
            end if;
        end if;
    end process led_monitor_proc;
    
    -- Test summary at the end
    final_report_proc : process
    begin
        wait until simulation_done_s;
        if test_success_s then
            report "TEST SUMMARY: All tests PASSED successfully!" severity note;
        else
            report "TEST SUMMARY: At least one test FAILED!" severity error;
        end if;
        wait;
    end process final_report_proc;

end architecture sim; 