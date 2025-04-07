--------------------------------------------------------------------------------
-- File: moving_ball.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Module that handles physics calculations and collision detection for a ball
-- moving on a VGA screen. Implements gravity, bounce, and friction effects.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity moving_ball is
    generic (
        -- System configuration
        CLK_FREQ_HZ_g     : integer := 50_000_000;  -- System clock frequency
        
        -- Screen configuration
        H_ACTIVE_g        : integer := 640;         -- Horizontal active pixels
        V_ACTIVE_g        : integer := 480;         -- Vertical active lines
        
        -- Ball configuration
        BALL_RADIUS_g     : integer := 20;          -- Ball radius in pixels
        BALL_COLOR_g      : std_logic_vector(23 downto 0) := x"FF0000";  -- Ball color (RGB)
        
        -- Frame buffer configuration
        PIXEL_WIDTH_g     : integer := 24           -- Total bits per pixel
    );
    port (
        -- Clock and reset
        clk_i            : in  std_logic;
        reset_n_i        : in  std_logic;
        
        -- Frame buffer interface
        fb_wr_clk_o      : out std_logic;
        fb_wr_en_o       : out std_logic;
        fb_wr_addr_o     : out std_logic_vector(19 downto 0);
        fb_wr_data_o     : out std_logic_vector(PIXEL_WIDTH_g-1 downto 0);
        fb_wr_ready_i    : in  std_logic;
        
        -- Status outputs
        ball_x_o         : out std_logic_vector(9 downto 0);
        ball_y_o         : out std_logic_vector(9 downto 0);
        ball_vx_o        : out std_logic_vector(9 downto 0);
        ball_vy_o        : out std_logic_vector(9 downto 0);
        collision_o      : out std_logic
    );
end entity moving_ball;

architecture rtl of moving_ball is

    -- Constants for physics
    constant GRAVITY_c        : integer := 1;        -- Gravity acceleration (pixels/frame^2)
    constant BOUNCE_c         : integer := 80;       -- Bounce coefficient (percentage)
    constant FRICTION_c       : integer := 95;       -- Friction coefficient (percentage)
    constant MAX_SPEED_c      : integer := 20;       -- Maximum speed (pixels/frame)
    
    -- Internal signals for ball state
    signal ball_x            : unsigned(9 downto 0) := to_unsigned(H_ACTIVE_g/2, 10);
    signal ball_y            : unsigned(9 downto 0) := to_unsigned(V_ACTIVE_g/2, 10);
    signal ball_vx           : signed(9 downto 0) := (others => '0');
    signal ball_vy           : signed(9 downto 0) := (others => '0');
    signal collision         : std_logic;
    
    -- Frame buffer control signals
    signal fb_wr_clk         : std_logic;
    signal fb_wr_en          : std_logic;
    signal fb_wr_addr        : std_logic_vector(19 downto 0);
    signal fb_wr_data        : std_logic_vector(PIXEL_WIDTH_g-1 downto 0);
    
    -- Drawing control signals
    signal draw_x            : unsigned(9 downto 0);
    signal draw_y            : unsigned(9 downto 0);
    signal draw_active       : std_logic;
    signal draw_done         : std_logic;
    
    -- Update counter for physics
    signal update_counter    : unsigned(7 downto 0) := (others => '0');

begin

    -- Map internal signals to outputs
    ball_x_o <= std_logic_vector(ball_x);
    ball_y_o <= std_logic_vector(ball_y);
    ball_vx_o <= std_logic_vector(ball_vx);
    ball_vy_o <= std_logic_vector(ball_vy);
    collision_o <= collision;
    
    fb_wr_clk_o <= fb_wr_clk;
    fb_wr_en_o <= fb_wr_en;
    fb_wr_addr_o <= fb_wr_addr;
    fb_wr_data_o <= fb_wr_data;
    
    -- Physics update process
    physics_update: process(clk_i, reset_n_i)
        variable next_x, next_y : unsigned(9 downto 0);
        variable next_vx, next_vy : signed(9 downto 0);
        variable collision_x, collision_y : std_logic;
    begin
        if reset_n_i = '0' then
            -- Reset ball state
            ball_x <= to_unsigned(H_ACTIVE_g/2, 10);
            ball_y <= to_unsigned(V_ACTIVE_g/2, 10);
            ball_vx <= (others => '0');
            ball_vy <= (others => '0');
            collision <= '0';
            update_counter <= (others => '0');
            
        elsif rising_edge(clk_i) then
            -- Reset collision flag
            collision <= '0';
            
            -- Update physics every 4 frames (60 Hz update rate)
            if update_counter = 0 then
                -- Calculate next position
                next_x := ball_x + unsigned(std_logic_vector(ball_vx));
                next_y := ball_y + unsigned(std_logic_vector(ball_vy));
                
                -- Apply gravity
                next_vy := ball_vy + to_signed(GRAVITY_c, 10);
                
                -- Check for collisions with walls
                collision_x := '0';
                collision_y := '0';
                
                -- Left wall collision
                if next_x < to_unsigned(BALL_RADIUS_g, 10) then
                    next_x := to_unsigned(BALL_RADIUS_g, 10);
                    next_vx := -ball_vx * to_signed(BOUNCE_c, 10) / 100;
                    collision_x := '1';
                end if;
                
                -- Right wall collision
                if next_x > to_unsigned(H_ACTIVE_g - BALL_RADIUS_g, 10) then
                    next_x := to_unsigned(H_ACTIVE_g - BALL_RADIUS_g, 10);
                    next_vx := -ball_vx * to_signed(BOUNCE_c, 10) / 100;
                    collision_x := '1';
                end if;
                
                -- Top wall collision
                if next_y < to_unsigned(BALL_RADIUS_g, 10) then
                    next_y := to_unsigned(BALL_RADIUS_g, 10);
                    next_vy := -ball_vy * to_signed(BOUNCE_c, 10) / 100;
                    collision_y := '1';
                end if;
                
                -- Bottom wall collision
                if next_y > to_unsigned(V_ACTIVE_g - BALL_RADIUS_g, 10) then
                    next_y := to_unsigned(V_ACTIVE_g - BALL_RADIUS_g, 10);
                    next_vy := -ball_vy * to_signed(BOUNCE_c, 10) / 100;
                    collision_y := '1';
                end if;
                
                -- Apply friction
                if not collision_x then
                    next_vx := next_vx * to_signed(FRICTION_c, 10) / 100;
                end if;
                if not collision_y then
                    next_vy := next_vy * to_signed(FRICTION_c, 10) / 100;
                end if;
                
                -- Limit speed
                if next_vx > to_signed(MAX_SPEED_c, 10) then
                    next_vx := to_signed(MAX_SPEED_c, 10);
                elsif next_vx < -to_signed(MAX_SPEED_c, 10) then
                    next_vx := -to_signed(MAX_SPEED_c, 10);
                end if;
                
                if next_vy > to_signed(MAX_SPEED_c, 10) then
                    next_vy := to_signed(MAX_SPEED_c, 10);
                elsif next_vy < -to_signed(MAX_SPEED_c, 10) then
                    next_vy := -to_signed(MAX_SPEED_c, 10);
                end if;
                
                -- Update ball state
                ball_x <= next_x;
                ball_y <= next_y;
                ball_vx <= next_vx;
                ball_vy <= next_vy;
                collision <= collision_x or collision_y;
                
                -- Increment update counter
                update_counter <= update_counter + 1;
            else
                update_counter <= update_counter + 1;
            end if;
        end if;
    end process physics_update;
    
    -- Drawing process
    drawing: process(clk_i, reset_n_i)
        variable dx, dy : signed(10 downto 0);
        variable dist_sq : unsigned(19 downto 0);
    begin
        if reset_n_i = '0' then
            -- Reset drawing state
            draw_x <= (others => '0');
            draw_y <= (others => '0');
            draw_active <= '0';
            draw_done <= '0';
            fb_wr_clk <= '0';
            fb_wr_en <= '0';
            fb_wr_addr <= (others => '0');
            fb_wr_data <= (others => '0');
            
        elsif rising_edge(clk_i) then
            -- Reset control signals
            fb_wr_en <= '0';
            draw_done <= '0';
            
            -- Start drawing when physics update is complete
            if update_counter = 0 and draw_active = '0' then
                draw_active <= '1';
                draw_x <= (others => '0');
                draw_y <= (others => '0');
            end if;
            
            -- Draw ball
            if draw_active then
                -- Calculate distance from ball center
                dx := signed('0' & draw_x) - signed('0' & ball_x);
                dy := signed('0' & draw_y) - signed('0' & ball_y);
                dist_sq := unsigned(dx * dx + dy * dy);
                
                -- Check if pixel is inside ball
                if dist_sq < to_unsigned(BALL_RADIUS_g * BALL_RADIUS_g, 20) then
                    -- Write ball color to frame buffer
                    fb_wr_en <= '1';
                    fb_wr_addr <= std_logic_vector(draw_y * H_ACTIVE_g + draw_x);
                    fb_wr_data <= BALL_COLOR_g;
                end if;
                
                -- Move to next pixel
                if draw_x = H_ACTIVE_g - 1 then
                    draw_x <= (others => '0');
                    if draw_y = V_ACTIVE_g - 1 then
                        draw_y <= (others => '0');
                        draw_active <= '0';
                        draw_done <= '1';
                    else
                        draw_y <= draw_y + 1;
                    end if;
                else
                    draw_x <= draw_x + 1;
                end if;
            end if;
        end if;
    end process drawing;

end architecture rtl; 