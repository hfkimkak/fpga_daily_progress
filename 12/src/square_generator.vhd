--------------------------------------------------------------------------------
-- File: square_generator.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Square Generator module for VGA display.
-- Generates a configurable square at specified coordinates.
-- Supports movement and collision detection with screen borders.
-- Pixel color is selected when current position is within square boundaries.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity square_generator is
    generic (
        -- Screen resolution
        SCREEN_WIDTH_g  : integer := 640;
        SCREEN_HEIGHT_g : integer := 480;
        
        -- Default square parameters
        SQUARE_SIZE_g   : integer := 50;     -- Square size in pixels
        SQUARE_COLOR_g  : std_logic_vector(11 downto 0) := x"0F0";  -- Default color (green)
        
        -- Default position
        SQUARE_X_START_g : integer := 100;    -- Initial X position
        SQUARE_Y_START_g : integer := 100     -- Initial Y position
    );
    port (
        -- Clock and reset
        clk_i           : in  std_logic;
        reset_n_i       : in  std_logic;
        
        -- Current pixel coordinates from VGA controller
        pixel_x_i       : in  integer range 0 to SCREEN_WIDTH_g-1;
        pixel_y_i       : in  integer range 0 to SCREEN_HEIGHT_g-1;
        display_ena_i   : in  std_logic;
        
        -- Control inputs
        move_right_i    : in  std_logic;
        move_left_i     : in  std_logic;
        move_up_i       : in  std_logic;
        move_down_i     : in  std_logic;
        
        -- Movement speed (pixels per frame)
        speed_i         : in  integer range 1 to 10 := 2;
        
        -- Frame timing for movement
        frame_tick_i    : in  std_logic;     -- Pulse once per frame (60Hz)
        
        -- Output signals
        square_on_o     : out std_logic;     -- '1' when current pixel is within square
        square_color_o  : out std_logic_vector(11 downto 0);  -- RGB color (4 bits per color)
        square_x_o      : out integer range 0 to SCREEN_WIDTH_g-1;  -- Current square X position
        square_y_o      : out integer range 0 to SCREEN_HEIGHT_g-1   -- Current square Y position
    );
end entity square_generator;

architecture rtl of square_generator is

    -- Square position signals (top-left corner)
    signal square_x_pos : integer range 0 to SCREEN_WIDTH_g-1 := SQUARE_X_START_g;
    signal square_y_pos : integer range 0 to SCREEN_HEIGHT_g-1 := SQUARE_Y_START_g;
    
    -- Boundary detection signals
    signal hit_left_edge   : std_logic;
    signal hit_right_edge  : std_logic;
    signal hit_top_edge    : std_logic;
    signal hit_bottom_edge : std_logic;
    
    -- Square active region signal
    signal square_on       : std_logic;
    
begin
    
    -- Square position update process
    position_update_proc: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            -- Reset square to initial position
            square_x_pos <= SQUARE_X_START_g;
            square_y_pos <= SQUARE_Y_START_g;
            
        elsif rising_edge(clk_i) then
            -- Only update position on frame tick
            if frame_tick_i = '1' then
                
                -- Horizontal movement
                if move_right_i = '1' and hit_right_edge = '0' then
                    square_x_pos <= square_x_pos + speed_i;
                elsif move_left_i = '1' and hit_left_edge = '0' then
                    square_x_pos <= square_x_pos - speed_i;
                end if;
                
                -- Vertical movement
                if move_down_i = '1' and hit_bottom_edge = '0' then
                    square_y_pos <= square_y_pos + speed_i;
                elsif move_up_i = '1' and hit_top_edge = '0' then
                    square_y_pos <= square_y_pos - speed_i;
                end if;
            end if;
        end if;
    end process position_update_proc;
    
    -- Boundary detection
    hit_left_edge <= '1' when square_x_pos <= 0 else '0';
    hit_right_edge <= '1' when (square_x_pos + SQUARE_SIZE_g) >= SCREEN_WIDTH_g else '0';
    hit_top_edge <= '1' when square_y_pos <= 0 else '0';
    hit_bottom_edge <= '1' when (square_y_pos + SQUARE_SIZE_g) >= SCREEN_HEIGHT_g else '0';
    
    -- Check if current pixel is within square boundaries
    square_on <= '1' when 
                 (pixel_x_i >= square_x_pos) and 
                 (pixel_x_i < square_x_pos + SQUARE_SIZE_g) and 
                 (pixel_y_i >= square_y_pos) and 
                 (pixel_y_i < square_y_pos + SQUARE_SIZE_g) and
                 display_ena_i = '1'
                 else '0';
    
    -- Assign output signals
    square_on_o <= square_on;
    square_color_o <= SQUARE_COLOR_g;
    square_x_o <= square_x_pos;
    square_y_o <= square_y_pos;
    
end architecture rtl; 