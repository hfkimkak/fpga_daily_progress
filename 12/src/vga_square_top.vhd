--------------------------------------------------------------------------------
-- File: vga_square_top.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Top-level module for VGA Square Drawing project.
-- Integrates VGA controller with square generator modules.
-- Takes inputs from buttons/switches and outputs to VGA display.
-- Generates a 25MHz pixel clock from the system clock.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_square_top is
    port (
        -- System signals
        clk_i           : in  std_logic;     -- System clock (expected to be 50 or 100 MHz)
        reset_n_i       : in  std_logic;     -- Active low reset
        
        -- User controls
        btn_up_i        : in  std_logic;     -- Up button
        btn_down_i      : in  std_logic;     -- Down button
        btn_left_i      : in  std_logic;     -- Left button
        btn_right_i     : in  std_logic;     -- Right button
        mode_select_i   : in  std_logic_vector(1 downto 0);  -- Mode selection
        square_select_i : in  std_logic_vector(1 downto 0);  -- Square selection
        
        -- VGA outputs
        vga_hsync_o     : out std_logic;     -- Horizontal sync
        vga_vsync_o     : out std_logic;     -- Vertical sync
        vga_red_o       : out std_logic_vector(3 downto 0);  -- Red channel
        vga_green_o     : out std_logic_vector(3 downto 0);  -- Green channel
        vga_blue_o      : out std_logic_vector(3 downto 0);  -- Blue channel
        
        -- Status outputs
        led_collision_o : out std_logic      -- Collision indicator LED
    );
end entity vga_square_top;

architecture rtl of vga_square_top is

    -- Component declarations
    component vga_controller is
        generic (
            H_ACTIVE_g      : integer := 640;
            H_FRONT_PORCH_g : integer := 16;
            H_SYNC_PULSE_g  : integer := 96;
            H_BACK_PORCH_g  : integer := 48;
            H_TOTAL_g       : integer := 800;
            V_ACTIVE_g      : integer := 480;
            V_FRONT_PORCH_g : integer := 10;
            V_SYNC_PULSE_g  : integer := 2;
            V_BACK_PORCH_g  : integer := 33;
            V_TOTAL_g       : integer := 525
        );
        port (
            clk_i           : in  std_logic;
            reset_n_i       : in  std_logic;
            hsync_o         : out std_logic;
            vsync_o         : out std_logic;
            display_ena_o   : out std_logic;
            column_o        : out integer range 0 to 639;
            row_o           : out integer range 0 to 479
        );
    end component;
    
    component multi_square_generator is
        generic (
            SCREEN_WIDTH_g  : integer := 640;
            SCREEN_HEIGHT_g : integer := 480;
            NUM_SQUARES_g   : integer := 4;
            SQUARE_COLORS_g : std_logic_vector(47 downto 0) := x"F00" & x"0F0" & x"00F" & x"FF0"
        );
        port (
            clk_i           : in  std_logic;
            reset_n_i       : in  std_logic;
            pixel_x_i       : in  integer range 0 to 639;
            pixel_y_i       : in  integer range 0 to 479;
            display_ena_i   : in  std_logic;
            frame_tick_i    : in  std_logic;
            square_size_i   : in  integer range 10 to 100 := 50;
            square_speed_i  : in  integer range 1 to 10 := 2;
            square_select_i : in  integer range 0 to 3 := 0;
            move_right_i    : in  std_logic;
            move_left_i     : in  std_logic;
            move_up_i       : in  std_logic;
            move_down_i     : in  std_logic;
            pixel_color_o   : out std_logic_vector(11 downto 0);
            collision_o     : out std_logic
        );
    end component;
    
    -- Clock signals
    signal pixel_clk        : std_logic := '0';
    signal pixel_clk_enable : std_logic := '0';
    
    -- VGA controller signals
    signal vga_hsync        : std_logic;
    signal vga_vsync        : std_logic;
    signal display_enable   : std_logic;
    signal pixel_column     : integer range 0 to 639;
    signal pixel_row        : integer range 0 to 479;
    
    -- Frame timing
    signal frame_tick       : std_logic := '0';
    signal frame_counter    : integer range 0 to 833333 := 0;  -- For 60Hz frame rate
    
    -- Square generator signals
    signal pixel_color      : std_logic_vector(11 downto 0);
    signal collision        : std_logic;
    
    -- Configuration signals
    signal square_size      : integer range 10 to 100 := 50;
    signal square_speed     : integer range 1 to 10 := 2;
    signal square_select    : integer range 0 to 3 := 0;
    
    -- Button debounce signals
    signal btn_up           : std_logic := '0';
    signal btn_down         : std_logic := '0';
    signal btn_left         : std_logic := '0';
    signal btn_right        : std_logic := '0';
    
begin

    -- Clock divider for 25MHz pixel clock from 50MHz or 100MHz system clock
    -- For 50MHz: divide by 2
    -- For 100MHz: divide by 4
    clk_divider: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            pixel_clk <= '0';
            pixel_clk_enable <= '0';
        elsif rising_edge(clk_i) then
            pixel_clk_enable <= not pixel_clk_enable;  -- Toggle every cycle (for 50MHz input)
            
            if pixel_clk_enable = '1' then
                pixel_clk <= not pixel_clk;
            end if;
        end if;
    end process clk_divider;

    -- Configure parameters based on mode selection
    config_params: process(mode_select_i)
    begin
        case mode_select_i is
            when "00" =>
                square_size <= 50;
                square_speed <= 2;
            when "01" =>
                square_size <= 30;
                square_speed <= 3;
            when "10" =>
                square_size <= 70;
                square_speed <= 1;
            when "11" =>
                square_size <= 20;
                square_speed <= 5;
            when others =>
                square_size <= 50;
                square_speed <= 2;
        end case;
    end process config_params;
    
    -- Map square selection to integer
    square_select <= to_integer(unsigned(square_select_i));
    
    -- Generate frame tick at 60Hz (for smooth animation)
    frame_tick_gen: process(pixel_clk, reset_n_i)
    begin
        if reset_n_i = '0' then
            frame_tick <= '0';
            frame_counter <= 0;
        elsif rising_edge(pixel_clk) then
            frame_tick <= '0';  -- Default to 0
            
            if frame_counter = 833333 then  -- 25,000,000 Hz / 60 Hz = 416,667 cycles (adjust as needed)
                frame_tick <= '1';
                frame_counter <= 0;
            else
                frame_counter <= frame_counter + 1;
            end if;
        end if;
    end process frame_tick_gen;
    
    -- Simple button debounce
    debounce: process(pixel_clk, reset_n_i)
    begin
        if reset_n_i = '0' then
            btn_up <= '0';
            btn_down <= '0';
            btn_left <= '0';
            btn_right <= '0';
        elsif rising_edge(pixel_clk) then
            -- Only sample buttons on frame tick to reduce speed
            if frame_tick = '1' then
                btn_up <= btn_up_i;
                btn_down <= btn_down_i;
                btn_left <= btn_left_i;
                btn_right <= btn_right_i;
            end if;
        end if;
    end process debounce;
    
    -- VGA controller instantiation
    vga_ctrl_inst: vga_controller
        port map (
            clk_i         => pixel_clk,
            reset_n_i     => reset_n_i,
            hsync_o       => vga_hsync,
            vsync_o       => vga_vsync,
            display_ena_o => display_enable,
            column_o      => pixel_column,
            row_o         => pixel_row
        );
    
    -- Multi-square generator instantiation
    square_gen_inst: multi_square_generator
        port map (
            clk_i           => pixel_clk,
            reset_n_i       => reset_n_i,
            pixel_x_i       => pixel_column,
            pixel_y_i       => pixel_row,
            display_ena_i   => display_enable,
            frame_tick_i    => frame_tick,
            square_size_i   => square_size,
            square_speed_i  => square_speed,
            square_select_i => square_select,
            move_right_i    => btn_right,
            move_left_i     => btn_left,
            move_up_i       => btn_up,
            move_down_i     => btn_down,
            pixel_color_o   => pixel_color,
            collision_o     => collision
        );
    
    -- Connect VGA outputs
    vga_hsync_o <= vga_hsync;
    vga_vsync_o <= vga_vsync;
    
    -- Assign RGB colors from pixel_color when display is enabled
    color_output: process(display_enable, pixel_color)
    begin
        if display_enable = '1' then
            vga_red_o <= pixel_color(11 downto 8);
            vga_green_o <= pixel_color(7 downto 4);
            vga_blue_o <= pixel_color(3 downto 0);
        else
            -- Black during blanking periods
            vga_red_o <= (others => '0');
            vga_green_o <= (others => '0');
            vga_blue_o <= (others => '0');
        end if;
    end process color_output;
    
    -- Connect collision output to LED
    led_collision_o <= collision;
    
end architecture rtl; 