--------------------------------------------------------------------------------
-- File: multi_square_generator.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Multi-Square Generator module for VGA display.
-- Generates multiple squares with configurable properties.
-- Each square can have different size, color, position, and movement pattern.
-- Supports collision detection between squares and screen boundaries.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity multi_square_generator is
    generic (
        -- Screen resolution
        SCREEN_WIDTH_g    : integer := 640;
        SCREEN_HEIGHT_g   : integer := 480;
        
        -- Number of squares to generate
        NUM_SQUARES_g     : integer := 4;
        
        -- Default square colors (can be overridden via inputs)
        SQUARE_COLORS_g   : std_logic_vector(47 downto 0) := x"F00" & x"0F0" & x"00F" & x"FF0"  -- Red, Green, Blue, Yellow
    );
    port (
        -- Clock and reset
        clk_i             : in  std_logic;
        reset_n_i         : in  std_logic;
        
        -- Current pixel coordinates from VGA controller
        pixel_x_i         : in  integer range 0 to SCREEN_WIDTH_g-1;
        pixel_y_i         : in  integer range 0 to SCREEN_HEIGHT_g-1;
        display_ena_i     : in  std_logic;
        
        -- Frame timing for movement
        frame_tick_i      : in  std_logic;    -- Pulse once per frame (60Hz)
        
        -- Square configurations (for runtime modification)
        square_size_i     : in  integer range 10 to 100 := 50;
        square_speed_i    : in  integer range 1 to 10 := 2;
        
        -- Control inputs for selected square
        square_select_i   : in  integer range 0 to NUM_SQUARES_g-1 := 0;
        move_right_i      : in  std_logic;
        move_left_i       : in  std_logic;
        move_up_i         : in  std_logic;
        move_down_i       : in  std_logic;
        
        -- Output signals
        pixel_color_o     : out std_logic_vector(11 downto 0);   -- RGB color (4 bits per color)
        collision_o       : out std_logic                        -- '1' when any squares collide
    );
end entity multi_square_generator;

architecture rtl of multi_square_generator is

    -- Constants
    constant COLOR_WIDTH_c : integer := 12;  -- 12-bit color (4 bits per channel)
    
    -- Types for arrays of square data
    type position_array_t is array (0 to NUM_SQUARES_g-1) of integer;
    type color_array_t is array (0 to NUM_SQUARES_g-1) of std_logic_vector(COLOR_WIDTH_c-1 downto 0);
    type bool_array_t is array (0 to NUM_SQUARES_g-1) of std_logic;
    
    -- Square parameters
    signal square_x_pos    : position_array_t := (100, 200, 300, 400);  -- Initial X positions
    signal square_y_pos    : position_array_t := (100, 200, 300, 200);  -- Initial Y positions
    signal square_sizes    : position_array_t := (others => 50);        -- Default size for all squares
    signal square_colors   : color_array_t;                             -- Colors from generic
    signal square_on       : bool_array_t := (others => '0');           -- Square active regions
    
    -- Movement parameters
    signal square_dx       : position_array_t := (1, -1, 1, -1);  -- X movement direction (+/-)
    signal square_dy       : position_array_t := (1, 1, -1, -1);  -- Y movement direction (+/-)
    
    -- Collision detection
    signal boundary_collision : bool_array_t := (others => '0');  -- Collisions with screen edges
    signal square_collision  : std_logic := '0';                 -- Collision between squares
    
    -- Color priority for overlapping squares (higher index has priority)
    signal pixel_color     : std_logic_vector(COLOR_WIDTH_c-1 downto 0) := (others => '0');
    
begin
    
    -- Unpack colors from generic into array
    unpack_colors: process(all)
    begin
        for i in 0 to NUM_SQUARES_g-1 loop
            if i < 4 then  -- Only unpack for valid squares
                square_colors(i) <= SQUARE_COLORS_g((i+1)*COLOR_WIDTH_c-1 downto i*COLOR_WIDTH_c);
            else
                -- Default color for additional squares if needed
                square_colors(i) <= x"FFF";  -- White
            end if;
        end loop;
    end process unpack_colors;
    
    -- Update square positions based on movement pattern or user input
    update_positions: process(clk_i, reset_n_i)
        variable x_new, y_new : integer;
    begin
        if reset_n_i = '0' then
            -- Reset to initial positions
            square_x_pos <= (100, 200, 300, 400);
            square_y_pos <= (100, 200, 300, 200);
            square_sizes <= (others => 50);
            
        elsif rising_edge(clk_i) then
            -- Update square sizes from input
            square_sizes(square_select_i) <= square_size_i;
            
            -- Only update position on frame tick
            if frame_tick_i = '1' then
                for i in 0 to NUM_SQUARES_g-1 loop
                    if i = square_select_i then
                        -- User-controlled square
                        if move_right_i = '1' and (square_x_pos(i) + square_sizes(i)) < SCREEN_WIDTH_g then
                            square_x_pos(i) <= square_x_pos(i) + square_speed_i;
                        elsif move_left_i = '1' and square_x_pos(i) > 0 then
                            square_x_pos(i) <= square_x_pos(i) - square_speed_i;
                        end if;
                        
                        if move_down_i = '1' and (square_y_pos(i) + square_sizes(i)) < SCREEN_HEIGHT_g then
                            square_y_pos(i) <= square_y_pos(i) + square_speed_i;
                        elsif move_up_i = '1' and square_y_pos(i) > 0 then
                            square_y_pos(i) <= square_y_pos(i) - square_speed_i;
                        end if;
                    else
                        -- Auto-moving squares
                        -- Calculate next position
                        x_new := square_x_pos(i) + (square_dx(i) * square_speed_i);
                        y_new := square_y_pos(i) + (square_dy(i) * square_speed_i);
                        
                        -- Check for boundary collisions and update direction
                        if x_new <= 0 or (x_new + square_sizes(i)) >= SCREEN_WIDTH_g then
                            square_dx(i) <= -square_dx(i);
                            boundary_collision(i) <= '1';
                        else
                            square_x_pos(i) <= x_new;
                            boundary_collision(i) <= '0';
                        end if;
                        
                        if y_new <= 0 or (y_new + square_sizes(i)) >= SCREEN_HEIGHT_g then
                            square_dy(i) <= -square_dy(i);
                            boundary_collision(i) <= '1';
                        else
                            square_y_pos(i) <= y_new;
                            boundary_collision(i) <= '0';
                        end if;
                    end if;
                end loop;
            end if;
        end if;
    end process update_positions;
    
    -- Check which squares include the current pixel
    check_pixel_in_squares: process(all)
    begin
        -- Default all to '0'
        for i in 0 to NUM_SQUARES_g-1 loop
            square_on(i) <= '0';
        end loop;
        
        -- Check if current pixel is within each square
        if display_ena_i = '1' then
            for i in 0 to NUM_SQUARES_g-1 loop
                if pixel_x_i >= square_x_pos(i) and
                   pixel_x_i < (square_x_pos(i) + square_sizes(i)) and
                   pixel_y_i >= square_y_pos(i) and
                   pixel_y_i < (square_y_pos(i) + square_sizes(i)) then
                    square_on(i) <= '1';
                end if;
            end loop;
        end if;
    end process check_pixel_in_squares;
    
    -- Determine pixel color using priority scheme (higher index has priority)
    determine_color: process(all)
        variable color_temp : std_logic_vector(COLOR_WIDTH_c-1 downto 0);
    begin
        -- Background color (black)
        color_temp := (others => '0');
        
        -- Assign color from highest priority square that includes this pixel
        for i in 0 to NUM_SQUARES_g-1 loop
            if square_on(i) = '1' then
                color_temp := square_colors(i);
            end if;
        end loop;
        
        -- Output final color
        pixel_color <= color_temp;
    end process determine_color;
    
    -- Check for collisions between squares
    check_collisions: process(all)
        variable collision_detected : std_logic;
    begin
        collision_detected := '0';
        
        -- Check all pairs of squares for collisions
        for i in 0 to NUM_SQUARES_g-2 loop
            for j in i+1 to NUM_SQUARES_g-1 loop
                if (square_x_pos(i) < square_x_pos(j) + square_sizes(j)) and
                   (square_x_pos(i) + square_sizes(i) > square_x_pos(j)) and
                   (square_y_pos(i) < square_y_pos(j) + square_sizes(j)) and
                   (square_y_pos(i) + square_sizes(i) > square_y_pos(j)) then
                    collision_detected := '1';
                end if;
            end loop;
        end loop;
        
        square_collision <= collision_detected;
    end process check_collisions;
    
    -- Assign output signals
    pixel_color_o <= pixel_color;
    collision_o <= square_collision;
    
end architecture rtl; 