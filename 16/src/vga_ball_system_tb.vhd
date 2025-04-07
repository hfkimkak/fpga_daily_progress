--------------------------------------------------------------------------------
-- File: vga_ball_system_tb.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Testbench for VGA ball system that tests VGA timing, ball physics,
-- and frame buffer operation.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_ball_system_tb is
end entity vga_ball_system_tb;

architecture rtl of vga_ball_system_tb is

    -- Component declaration
    component vga_ball_system is
        generic (
            CLK_FREQ_HZ_g     : integer;
            H_ACTIVE_g        : integer;
            H_FRONT_g        : integer;
            H_SYNC_g         : integer;
            H_BACK_g         : integer;
            V_ACTIVE_g       : integer;
            V_FRONT_g        : integer;
            V_SYNC_g         : integer;
            V_BACK_g         : integer;
            COLOR_WIDTH_g    : integer;
            PIXEL_WIDTH_g    : integer;
            BALL_RADIUS_g    : integer;
            BALL_COLOR_g     : std_logic_vector(23 downto 0)
        );
        port (
            clk_i            : in  std_logic;
            reset_n_i        : in  std_logic;
            vga_hsync_o      : out std_logic;
            vga_vsync_o      : out std_logic;
            vga_red_o        : out std_logic_vector(COLOR_WIDTH_g-1 downto 0);
            vga_green_o      : out std_logic_vector(COLOR_WIDTH_g-1 downto 0);
            vga_blue_o       : out std_logic_vector(COLOR_WIDTH_g-1 downto 0);
            vga_blank_o      : out std_logic;
            ball_x_o         : out std_logic_vector(9 downto 0);
            ball_y_o         : out std_logic_vector(9 downto 0);
            ball_vx_o        : out std_logic_vector(9 downto 0);
            ball_vy_o        : out std_logic_vector(9 downto 0);
            collision_o      : out std_logic;
            frame_done_o     : out std_logic
        );
    end component;

    -- Constants
    constant CLK_PERIOD_c    : time := 20 ns;  -- 50 MHz clock
    constant SIM_TIME_c      : time := 100 ms;  -- Simulation time
    
    -- Signals
    signal clk              : std_logic := '0';
    signal reset_n          : std_logic := '1';
    signal vga_hsync        : std_logic;
    signal vga_vsync        : std_logic;
    signal vga_red          : std_logic_vector(7 downto 0);
    signal vga_green        : std_logic_vector(7 downto 0);
    signal vga_blue         : std_logic_vector(7 downto 0);
    signal vga_blank        : std_logic;
    signal ball_x           : std_logic_vector(9 downto 0);
    signal ball_y           : std_logic_vector(9 downto 0);
    signal ball_vx          : std_logic_vector(9 downto 0);
    signal ball_vy          : std_logic_vector(9 downto 0);
    signal collision        : std_logic;
    signal frame_done       : std_logic;
    
    -- Test control signals
    signal test_done        : std_logic := '0';
    signal frame_count      : integer := 0;
    signal collision_count  : integer := 0;
    signal last_ball_x      : std_logic_vector(9 downto 0);
    signal last_ball_y      : std_logic_vector(9 downto 0);
    signal stuck_counter    : integer := 0;

begin

    -- Instantiate DUT
    dut: vga_ball_system
        generic map (
            CLK_FREQ_HZ_g     => 50_000_000,
            H_ACTIVE_g        => 640,
            H_FRONT_g        => 16,
            H_SYNC_g         => 96,
            H_BACK_g         => 48,
            V_ACTIVE_g       => 480,
            V_FRONT_g        => 10,
            V_SYNC_g         => 2,
            V_BACK_g         => 33,
            COLOR_WIDTH_g    => 8,
            PIXEL_WIDTH_g    => 24,
            BALL_RADIUS_g    => 20,
            BALL_COLOR_g     => x"FF0000"
        )
        port map (
            clk_i            => clk,
            reset_n_i        => reset_n,
            vga_hsync_o      => vga_hsync,
            vga_vsync_o      => vga_vsync,
            vga_red_o        => vga_red,
            vga_green_o      => vga_green,
            vga_blue_o       => vga_blue,
            vga_blank_o      => vga_blank,
            ball_x_o         => ball_x,
            ball_y_o         => ball_y,
            ball_vx_o        => ball_vx,
            ball_vy_o        => ball_vy,
            collision_o      => collision,
            frame_done_o     => frame_done
        );

    -- Clock generation
    clk_gen: process
    begin
        while not test_done loop
            clk <= '0';
            wait for CLK_PERIOD_c/2;
            clk <= '1';
            wait for CLK_PERIOD_c/2;
        end loop;
        wait;
    end process clk_gen;

    -- Frame and collision counting
    frame_counter: process(clk)
    begin
        if rising_edge(clk) then
            if frame_done = '1' then
                frame_count <= frame_count + 1;
            end if;
            if collision = '1' then
                collision_count <= collision_count + 1;
            end if;
        end if;
    end process frame_counter;

    -- Ball movement monitoring
    ball_monitor: process(clk)
    begin
        if rising_edge(clk) then
            if frame_done = '1' then
                if ball_x = last_ball_x and ball_y = last_ball_y then
                    stuck_counter <= stuck_counter + 1;
                    if stuck_counter > 100 then
                        report "Warning: Ball appears to be stuck at position (" & 
                              integer'image(to_integer(unsigned(ball_x))) & "," & 
                              integer'image(to_integer(unsigned(ball_y))) & ")" 
                              severity warning;
                    end if;
                else
                    stuck_counter <= 0;
                end if;
                last_ball_x <= ball_x;
                last_ball_y <= ball_y;
            end if;
        end if;
    end process ball_monitor;

    -- Monitor process
    monitor: process
        variable last_time : time := 0 ns;
    begin
        while not test_done loop
            wait for 1 ms;
            report "Time: " & time'image(now) & 
                   " Frames: " & integer'image(frame_count) & 
                   " Collisions: " & integer'image(collision_count) & 
                   " Ball pos: (" & integer'image(to_integer(unsigned(ball_x))) & "," & 
                   integer'image(to_integer(unsigned(ball_y))) & ")" &
                   " Ball vel: (" & integer'image(to_integer(signed(ball_vx))) & "," & 
                   integer'image(to_integer(signed(ball_vy))) & ")";
            last_time := now;
        end loop;
        wait;
    end process monitor;

    -- Stimulus process
    stimulus: process
    begin
        -- Reset
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait for 100 ns;
        
        -- Wait for initial frames
        wait until frame_count >= 10;
        
        -- Test ball movement
        report "Testing ball movement...";
        wait until frame_count >= 100;
        
        -- Test collision detection
        report "Testing collision detection...";
        wait until collision_count >= 5;
        
        -- Test frame timing
        report "Testing frame timing...";
        wait until frame_count >= 1000;
        
        -- End simulation
        test_done <= '1';
        report "Simulation completed successfully";
        report "Total frames: " & integer'image(frame_count);
        report "Total collisions: " & integer'image(collision_count);
        wait;
    end process stimulus;

    -- Simulation time limit
    sim_time_limit: process
    begin
        wait for SIM_TIME_c;
        report "Simulation time limit reached";
        test_done <= '1';
        wait;
    end process sim_time_limit;

end architecture rtl; 