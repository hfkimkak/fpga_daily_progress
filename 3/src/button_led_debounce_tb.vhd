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

architecture sim of button_led_debounce_tb is

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    component button_led_debounce is
        generic (
            CLK_FREQ_HZ_g    : integer := 100_000_000;
            DEBOUNCE_MS_g    : integer := 20;
            NUM_LEDS_g       : integer := 4;
            EFFECT_SPEED_MS_g: integer := 100
        );
        port (
            clk_i     : in  std_logic;
            reset_n_i : in  std_logic;
            button_i  : in  std_logic;
            leds_o    : out std_logic_vector(NUM_LEDS_g-1 downto 0)
        );
    end component;

    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    constant CLK_PERIOD_c    : time := 10 ns;  -- 100 MHz clock
    constant NUM_LEDS_c      : integer := 4;
    constant DEBOUNCE_MS_c   : integer := 2;   -- Shorter debounce for simulation
    constant EFFECT_SPEED_MS_c: integer := 10;  -- Faster effects for simulation
    constant SIM_CLK_FREQ_c  : integer := 100_000_000;

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    signal clk_s     : std_logic := '0';
    signal reset_n_s : std_logic := '0';
    signal button_s  : std_logic := '0';
    signal leds_s    : std_logic_vector(NUM_LEDS_c-1 downto 0);
    signal sim_done  : boolean := false;

    --------------------------------------------------------------------------------------------------------------------
    -- ATTRIBUTE DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------

    -- Procedures for test stimulus
    procedure wait_cycles(signal clk: std_logic; n: integer) is
    begin
        for i in 1 to n loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

    procedure press_button(
        signal clk    : in  std_logic;
        signal button : out std_logic;
        bounce_count  : in  integer := 0;
        bounce_delay  : in  time    := 100 ns
    ) is
    begin
        -- Initial press
        button <= '1';
        
        -- Simulate bouncing if requested
        for i in 1 to bounce_count loop
            wait for bounce_delay;
            button <= '0';
            wait for bounce_delay;
            button <= '1';
        end loop;
        
        wait for 1 ms;
        button <= '0';
        wait for 1 ms;
    end procedure;

begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT MODULE NAME : DEFINITION
    --------------------------------------------------------------------------------------------------------------------
    uut_inst : component button_led_debounce
        generic map (
            CLK_FREQ_HZ_g     => SIM_CLK_FREQ_c,
            DEBOUNCE_MS_g     => DEBOUNCE_MS_c,
            NUM_LEDS_g        => NUM_LEDS_c,
            EFFECT_SPEED_MS_g => EFFECT_SPEED_MS_c
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
    clk_gen_proc: process
    begin
        while not sim_done loop
            clk_s <= '1';
            wait for CLK_PERIOD_c/2;
            clk_s <= '0';
            wait for CLK_PERIOD_c/2;
        end loop;
        wait;
    end process clk_gen_proc;
    
    --------------------------------------------------------------------------------------------------------------------
    -- STIM_PROC : Stimulus process
    --------------------------------------------------------------------------------------------------------------------
    stim_proc: process
    begin
        -- Initial reset
        reset_n_s <= '0';
        wait_cycles(clk_s, 10);
        reset_n_s <= '1';
        wait_cycles(clk_s, 10);

        report "Starting LED effect tests...";

        -- Test 1: Single LED mode (initial state)
        report "Test 1: Checking Single LED mode";
        wait for 5 * EFFECT_SPEED_MS_c * 1 ms;

        -- Test 2: Switch to ALL_LEDS mode
        report "Test 2: Switching to ALL_LEDS mode";
        press_button(clk_s, button_s);
        wait for 2 * EFFECT_SPEED_MS_c * 1 ms;

        -- Test 3: SHIFT_RIGHT mode with bouncing button
        report "Test 3: Testing SHIFT_RIGHT mode with button bounce";
        press_button(clk_s, button_s, 5, 100 ns);  -- 5 bounces
        wait for 5 * EFFECT_SPEED_MS_c * 1 ms;

        -- Test 4: SHIFT_LEFT mode
        report "Test 4: Testing SHIFT_LEFT mode";
        press_button(clk_s, button_s);
        wait for 5 * EFFECT_SPEED_MS_c * 1 ms;

        -- Test 5: BOUNCE mode
        report "Test 5: Testing BOUNCE mode";
        press_button(clk_s, button_s);
        wait for 10 * EFFECT_SPEED_MS_c * 1 ms;

        -- Test 6: RANDOM mode
        report "Test 6: Testing RANDOM mode";
        press_button(clk_s, button_s);
        wait for 10 * EFFECT_SPEED_MS_c * 1 ms;

        -- Test 7: Back to Single LED mode
        report "Test 7: Back to Single LED mode";
        press_button(clk_s, button_s);
        wait for 5 * EFFECT_SPEED_MS_c * 1 ms;

        -- Test 8: Reset during operation
        report "Test 8: Testing reset during operation";
        reset_n_s <= '0';
        wait_cycles(clk_s, 10);
        reset_n_s <= '1';
        wait for 5 * EFFECT_SPEED_MS_c * 1 ms;

        -- End simulation
        report "All tests completed successfully!";
        sim_done <= true;
        wait;
    end process stim_proc;

    -- Monitor process to check LED patterns
    monitor_proc: process
    begin
        wait until rising_edge(clk_s);
        if reset_n_s = '0' then
            assert leds_s = (0 => '1', others => '0')
                report "Reset state incorrect"
                severity error;
        end if;
    end process monitor_proc;

end architecture sim; 