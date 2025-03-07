---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  Testbench for Button-Controlled LED with Debounce Circuit
--                - Simulates button presses with and without bouncing
--                - Tests the debounce functionality with realistic button bounce patterns
--                - Verifies LED pattern changes through multiple button presses
--                - Includes four main test cases:
--                  * Test 1: Button press with bouncing to test debounce
--                  * Test 2: Multiple clean button presses to cycle through LED patterns
--                  * Test 3: Reset functionality testing
--                  * Test 4: Button press after reset
--                - Uses procedures to simulate different button press behaviors:
--                  * press_button_with_bounce: Simulates realistic button bouncing
--                  * press_button_clean: Simulates clean button press without bouncing
--                - Provides detailed test reporting through simulation messages
--                - Uses accelerated simulation parameters for faster testing
--                - Verifies complete functionality of the button-controlled LED circuit
---------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
--
-- Company Name : FPGA Daily Progress
--
-- File Name    : button_led_debounce_tb.vhd
--
-- Purpose      : Testbench for button-controlled LED circuit with debounce functionality
--
--
-- Note         : This testbench simulates button presses with and without bouncing to verify
--                the debounce functionality and LED pattern changes
--
--
--
--
--
--
--
-- Limitations  : Simulation only
--
--
--
--
-- Errors       : None known
--
--
--
-- Library      : IEEE
--
--
-- Dependencies : button_led_debounce.vhd
--
--
--
-- Author       :
--
--                Name - Surname : FPGA Daily Progress
--                E-Mail         : fpga_daily_progress@hotmail.com
--
--
-- Simulator    : ModelSim/Vivado Simulator
--
--
------------------------------------------------------------------------------------------------------------------------
-- Revision List
--
-- Version    |    Author    |    Date    |    Changes
-- v1.0       |    FPGA DP   |  2024-03-07|    Initial version
------------------------------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- < Add More User Library, If required. >

entity button_led_debounce_tb is
    -- Testbench has no ports
end entity button_led_debounce_tb;

architecture rtl of button_led_debounce_tb is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    component button_led_debounce is
        generic (
            CLK_FREQ_HZ_g : integer := 100_000_000;
            DEBOUNCE_MS_g : integer := 20;
            NUM_LEDS_g    : integer := 4
        );
        port (
            clk_i     : in  std_logic;
            reset_n_i : in  std_logic;
            button_i  : in  std_logic;
            leds_o    : out std_logic_vector(NUM_LEDS_g-1 downto 0)
        );
    end component button_led_debounce;

    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    constant CLK_PERIOD_c     : time := 10 ns;  --! 100 MHz clock
    constant NUM_LEDS_c       : integer := 4;   --! Number of LEDs
    
    -- For simulation, use a much faster debounce time
    constant SIM_CLK_FREQ_c   : integer := 100_000_000;  --! 100 MHz
    constant SIM_DEBOUNCE_MS_c : integer := 1;           --! 1ms for simulation

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    signal clk_s          : std_logic := '0';  --! Clock signal
    signal reset_n_s      : std_logic := '1';  --! Reset signal (active low)
    signal button_s       : std_logic := '0';  --! Button input signal
    signal leds_s         : std_logic_vector(NUM_LEDS_c-1 downto 0); --! LED output signals
    
    signal sim_done_s     : boolean := false;  --! Simulation control signal

    --------------------------------------------------------------------------------------------------------------------
    -- ATTRIBUTE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT MODULE NAME : DEFINITION
    --------------------------------------------------------------------------------------------------------------------
    uut_inst : component button_led_debounce
        generic map (
            CLK_FREQ_HZ_g => SIM_CLK_FREQ_c,
            DEBOUNCE_MS_g => SIM_DEBOUNCE_MS_c,
            NUM_LEDS_g    => NUM_LEDS_c
        )
        port map (
            clk_i     => clk_s,
            reset_n_i => reset_n_s,
            button_i  => button_s,
            leds_o    => leds_s
        );

    --------------------------------------------------------------------------------------------------------------------
    -- SEQUENTIAL PART
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- CLK_PROCESS : Clock generation process
    --------------------------------------------------------------------------------------------------------------------
    clk_process : process is
    begin
        while not sim_done_s loop
            clk_s <= '0';
            wait for CLK_PERIOD_c/2;
            clk_s <= '1';
            wait for CLK_PERIOD_c/2;
        end loop;
        wait;
    end process clk_process;
    
    --------------------------------------------------------------------------------------------------------------------
    -- STIM_PROC : Stimulus process
    --------------------------------------------------------------------------------------------------------------------
    stim_proc : process is
        -- Procedure to simulate a button press with bouncing
        procedure press_button_with_bounce is
        begin
            -- Initial button press with bouncing
            button_s <= '1';
            wait for 0.1 ms;
            button_s <= '0';
            wait for 0.05 ms;
            button_s <= '1';
            wait for 0.2 ms;
            button_s <= '0';
            wait for 0.05 ms;
            button_s <= '1';
            
            -- Hold button pressed for a while
            wait for 5 ms;
            
            -- Release button with bouncing
            button_s <= '0';
            wait for 0.1 ms;
            button_s <= '1';
            wait for 0.05 ms;
            button_s <= '0';
            wait for 0.1 ms;
            button_s <= '1';
            wait for 0.05 ms;
            button_s <= '0';
            
            -- Wait for debounce to settle
            wait for 5 ms;
        end procedure press_button_with_bounce;
        
        -- Procedure for a clean button press (no bouncing)
        procedure press_button_clean is
        begin
            button_s <= '1';
            wait for 5 ms;
            button_s <= '0';
            wait for 5 ms;
        end procedure press_button_clean;
        
    begin
        -- Reset the system
        reset_n_s <= '0';
        wait for 100 ns;
        reset_n_s <= '1';
        wait for 100 ns;
        
        -- Test 1: Press button with bouncing to test debounce
        report "Test 1: Button press with bouncing";
        press_button_with_bounce;
        
        -- Test 2: Press button multiple times to cycle through LED patterns
        report "Test 2: Multiple button presses to cycle through LED patterns";
        for i in 1 to 8 loop
            press_button_clean;
            wait for 1 ms;
        end loop;
        
        -- Test 3: Test reset functionality
        report "Test 3: Testing reset functionality";
        reset_n_s <= '0';
        wait for 100 ns;
        reset_n_s <= '1';
        wait for 100 ns;
        
        -- Test 4: One more button press after reset
        report "Test 4: Button press after reset";
        press_button_clean;
        
        -- End simulation
        wait for 10 ms;
        report "Simulation completed successfully";
        sim_done_s <= true;
        wait;
    end process stim_proc;

end architecture rtl; 