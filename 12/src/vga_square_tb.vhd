--------------------------------------------------------------------------------
-- File: vga_square_tb.vhd
-- Author: FPGA Tutorial
-- Date: 2023
--
-- Description:
-- Testbench for VGA Square Drawing project.
-- Simulates VGA timing and square generation.
-- Tests basic functionality of VGA controller and square generator.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_square_tb is
    -- Empty entity for testbench
end entity vga_square_tb;

architecture sim of vga_square_tb is
    
    -- Clock and reset signals
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz system clock
    signal clk          : std_logic := '0';
    signal reset_n      : std_logic := '0';
    
    -- User control signals
    signal btn_up       : std_logic := '0';
    signal btn_down     : std_logic := '0';
    signal btn_left     : std_logic := '0';
    signal btn_right    : std_logic := '0';
    signal mode_select  : std_logic_vector(1 downto 0) := "00";
    signal square_select: std_logic_vector(1 downto 0) := "00";
    
    -- VGA output signals
    signal vga_hsync    : std_logic;
    signal vga_vsync    : std_logic;
    signal vga_red      : std_logic_vector(3 downto 0);
    signal vga_green    : std_logic_vector(3 downto 0);
    signal vga_blue     : std_logic_vector(3 downto 0);
    
    -- Status output
    signal led_collision: std_logic;
    
    -- Simulation control
    signal sim_done     : boolean := false;
    
    -- Component declarations
    component vga_square_top is
        port (
            clk_i           : in  std_logic;
            reset_n_i       : in  std_logic;
            btn_up_i        : in  std_logic;
            btn_down_i      : in  std_logic;
            btn_left_i      : in  std_logic;
            btn_right_i     : in  std_logic;
            mode_select_i   : in  std_logic_vector(1 downto 0);
            square_select_i : in  std_logic_vector(1 downto 0);
            vga_hsync_o     : out std_logic;
            vga_vsync_o     : out std_logic;
            vga_red_o       : out std_logic_vector(3 downto 0);
            vga_green_o     : out std_logic_vector(3 downto 0);
            vga_blue_o      : out std_logic_vector(3 downto 0);
            led_collision_o : out std_logic
        );
    end component;
    
begin
    
    -- Clock generation
    clk <= not clk after CLK_PERIOD/2 when not sim_done else '0';
    
    -- Device Under Test (DUT)
    dut: vga_square_top
        port map (
            clk_i           => clk,
            reset_n_i       => reset_n,
            btn_up_i        => btn_up,
            btn_down_i      => btn_down,
            btn_left_i      => btn_left,
            btn_right_i     => btn_right,
            mode_select_i   => mode_select,
            square_select_i => square_select,
            vga_hsync_o     => vga_hsync,
            vga_vsync_o     => vga_vsync,
            vga_red_o       => vga_red,
            vga_green_o     => vga_green,
            vga_blue_o      => vga_blue,
            led_collision_o => led_collision
        );
    
    -- Stimulus process
    stimulus: process
    begin
        -- Initialize with reset
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait for 100 ns;
        
        -- Wait for a few frames to stabilize
        wait for 50 ms;
        
        -- Test mode selection
        mode_select <= "01";  -- Switch to mode 1 (smaller squares, faster)
        wait for 10 ms;
        
        -- Test different square selection
        square_select <= "01";  -- Select square 1
        wait for 10 ms;
        
        -- Test movement
        -- Move right for a bit
        btn_right <= '1';
        wait for 20 ms;
        btn_right <= '0';
        wait for 10 ms;
        
        -- Move down for a bit
        btn_down <= '1';
        wait for 20 ms;
        btn_down <= '0';
        wait for 10 ms;
        
        -- Move left for a bit
        btn_left <= '1';
        wait for 20 ms;
        btn_left <= '0';
        wait for 10 ms;
        
        -- Move up for a bit
        btn_up <= '1';
        wait for 20 ms;
        btn_up <= '0';
        wait for 10 ms;
        
        -- Test another mode
        mode_select <= "10";  -- Switch to mode 2 (larger squares, slower)
        square_select <= "10";  -- Select square 2
        wait for 30 ms;
        
        -- Move in a diagonal pattern (right and down simultaneously)
        btn_right <= '1';
        btn_down <= '1';
        wait for 30 ms;
        btn_right <= '0';
        btn_down <= '0';
        wait for 10 ms;
        
        -- Check collision detection (squares should be moving automatically as well)
        wait for 100 ms;
        
        -- End simulation
        report "Simulation complete";
        sim_done <= true;
        wait;
    end process stimulus;
    
    -- VGA synchronization monitoring process
    sync_monitor: process
        variable hsync_count : integer := 0;
        variable vsync_count : integer := 0;
        variable frame_count : integer := 0;
    begin
        wait until rising_edge(clk);
        
        -- Count horizontal sync pulses
        if vga_hsync = '0' then
            hsync_count := hsync_count + 1;
        end if;
        
        -- Detect vertical sync falling edge (start of new frame)
        if vga_vsync'event and vga_vsync = '0' then
            vsync_count := vsync_count + 1;
            frame_count := frame_count + 1;
            
            -- Report frame progress every 10 frames
            if frame_count mod 10 = 0 then
                report "Completed " & integer'image(frame_count) & " frames";
            end if;
        end if;
        
        -- End process when simulation is done
        if sim_done then
            wait;
        end if;
    end process sync_monitor;
    
    -- Collision detection monitor
    collision_monitor: process
    begin
        wait until led_collision = '1';
        report "Square collision detected!";
        
        -- Wait until collision is over
        wait until led_collision = '0';
        report "Collision ended";
        
        -- End process when simulation is done
        if sim_done then
            wait;
        end if;
    end process collision_monitor;
    
end architecture sim; 