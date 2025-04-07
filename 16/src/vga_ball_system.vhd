--------------------------------------------------------------------------------
-- File: vga_ball_system.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Top-level module that integrates VGA controller and moving ball module.
-- Provides frame buffer management and system control.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_ball_system is
    generic (
        -- System configuration
        CLK_FREQ_HZ_g     : integer := 50_000_000;  -- System clock frequency
        
        -- VGA configuration
        H_ACTIVE_g        : integer := 640;         -- Horizontal active pixels
        H_FRONT_g        : integer := 16;           -- Horizontal front porch
        H_SYNC_g         : integer := 96;           -- Horizontal sync pulse
        H_BACK_g         : integer := 48;           -- Horizontal back porch
        V_ACTIVE_g       : integer := 480;          -- Vertical active lines
        V_FRONT_g        : integer := 10;           -- Vertical front porch
        V_SYNC_g         : integer := 2;            -- Vertical sync pulse
        V_BACK_g         : integer := 33;           -- Vertical back porch
        
        -- Color configuration
        COLOR_WIDTH_g    : integer := 8;            -- Bits per color channel
        PIXEL_WIDTH_g    : integer := 24;           -- Total bits per pixel
        
        -- Ball configuration
        BALL_RADIUS_g    : integer := 20;           -- Ball radius in pixels
        BALL_COLOR_g     : std_logic_vector(23 downto 0) := x"FF0000"  -- Ball color (RGB)
    );
    port (
        -- Clock and reset
        clk_i            : in  std_logic;
        reset_n_i        : in  std_logic;
        
        -- VGA outputs
        vga_hsync_o      : out std_logic;
        vga_vsync_o      : out std_logic;
        vga_red_o        : out std_logic_vector(COLOR_WIDTH_g-1 downto 0);
        vga_green_o      : out std_logic_vector(COLOR_WIDTH_g-1 downto 0);
        vga_blue_o       : out std_logic_vector(COLOR_WIDTH_g-1 downto 0);
        vga_blank_o      : out std_logic;
        
        -- Status outputs
        ball_x_o         : out std_logic_vector(9 downto 0);
        ball_y_o         : out std_logic_vector(9 downto 0);
        ball_vx_o        : out std_logic_vector(9 downto 0);
        ball_vy_o        : out std_logic_vector(9 downto 0);
        collision_o      : out std_logic;
        frame_done_o     : out std_logic
    );
end entity vga_ball_system;

architecture rtl of vga_ball_system is

    -- Component declarations
    component vga_ball_controller is
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
            PIXEL_WIDTH_g    : integer
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
            fb_rd_clk_o      : out std_logic;
            fb_rd_en_o       : out std_logic;
            fb_rd_addr_o     : out std_logic_vector(19 downto 0);
            fb_rd_data_i     : in  std_logic_vector(PIXEL_WIDTH_g-1 downto 0);
            fb_rd_ready_i    : in  std_logic;
            frame_done_o     : out std_logic;
            vsync_o          : out std_logic;
            hsync_o          : out std_logic;
            pixel_valid_o    : out std_logic;
            pixel_x_o        : out std_logic_vector(9 downto 0);
            pixel_y_o        : out std_logic_vector(9 downto 0)
        );
    end component;

    component frame_buffer is
        generic (
            ADDR_WIDTH_g : integer;
            DATA_WIDTH_g : integer
        );
        port (
            -- Write port
            wr_clk_i     : in  std_logic;
            wr_en_i      : in  std_logic;
            wr_addr_i    : in  std_logic_vector(ADDR_WIDTH_g-1 downto 0);
            wr_data_i    : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
            wr_ready_o   : out std_logic;
            
            -- Read port
            rd_clk_i     : in  std_logic;
            rd_en_i      : in  std_logic;
            rd_addr_i    : in  std_logic_vector(ADDR_WIDTH_g-1 downto 0);
            rd_data_o    : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            rd_ready_o   : out std_logic
        );
    end component;

    component moving_ball is
        generic (
            CLK_FREQ_HZ_g     : integer;
            H_ACTIVE_g        : integer;
            V_ACTIVE_g        : integer;
            BALL_RADIUS_g     : integer;
            BALL_COLOR_g      : std_logic_vector(23 downto 0);
            PIXEL_WIDTH_g     : integer
        );
        port (
            clk_i            : in  std_logic;
            reset_n_i        : in  std_logic;
            fb_wr_clk_o      : out std_logic;
            fb_wr_en_o       : out std_logic;
            fb_wr_addr_o     : out std_logic_vector(19 downto 0);
            fb_wr_data_o     : out std_logic_vector(PIXEL_WIDTH_g-1 downto 0);
            fb_wr_ready_i    : in  std_logic;
            ball_x_o         : out std_logic_vector(9 downto 0);
            ball_y_o         : out std_logic_vector(9 downto 0);
            ball_vx_o        : out std_logic_vector(9 downto 0);
            ball_vy_o        : out std_logic_vector(9 downto 0);
            collision_o      : out std_logic
        );
    end component;

    -- Internal signals
    signal fb_rd_clk      : std_logic;
    signal fb_rd_en       : std_logic;
    signal fb_rd_addr     : std_logic_vector(19 downto 0);
    signal fb_rd_data     : std_logic_vector(PIXEL_WIDTH_g-1 downto 0);
    signal fb_rd_ready    : std_logic;
    
    signal fb_wr_clk      : std_logic;
    signal fb_wr_en       : std_logic;
    signal fb_wr_addr     : std_logic_vector(19 downto 0);
    signal fb_wr_data     : std_logic_vector(PIXEL_WIDTH_g-1 downto 0);
    signal fb_wr_ready    : std_logic;
    
    signal pixel_valid    : std_logic;
    signal pixel_x        : std_logic_vector(9 downto 0);
    signal pixel_y        : std_logic_vector(9 downto 0);
    signal frame_done     : std_logic;

begin

    -- Map internal signals to outputs
    ball_x_o <= pixel_x;
    ball_y_o <= pixel_y;
    frame_done_o <= frame_done;
    
    -- Instantiate VGA controller
    vga_ctrl: vga_ball_controller
        generic map (
            CLK_FREQ_HZ_g     => CLK_FREQ_HZ_g,
            H_ACTIVE_g        => H_ACTIVE_g,
            H_FRONT_g        => H_FRONT_g,
            H_SYNC_g         => H_SYNC_g,
            H_BACK_g         => H_BACK_g,
            V_ACTIVE_g       => V_ACTIVE_g,
            V_FRONT_g        => V_FRONT_g,
            V_SYNC_g         => V_SYNC_g,
            V_BACK_g         => V_BACK_g,
            COLOR_WIDTH_g    => COLOR_WIDTH_g,
            PIXEL_WIDTH_g    => PIXEL_WIDTH_g
        )
        port map (
            clk_i            => clk_i,
            reset_n_i        => reset_n_i,
            vga_hsync_o      => vga_hsync_o,
            vga_vsync_o      => vga_vsync_o,
            vga_red_o        => vga_red_o,
            vga_green_o      => vga_green_o,
            vga_blue_o       => vga_blue_o,
            vga_blank_o      => vga_blank_o,
            fb_rd_clk_o      => fb_rd_clk,
            fb_rd_en_o       => fb_rd_en,
            fb_rd_addr_o     => fb_rd_addr,
            fb_rd_data_i     => fb_rd_data,
            fb_rd_ready_i    => fb_rd_ready,
            frame_done_o     => frame_done,
            vsync_o          => open,
            hsync_o          => open,
            pixel_valid_o    => pixel_valid,
            pixel_x_o        => pixel_x,
            pixel_y_o        => pixel_y
        );
    
    -- Instantiate frame buffer
    fb: frame_buffer
        generic map (
            ADDR_WIDTH_g => 20,
            DATA_WIDTH_g => PIXEL_WIDTH_g
        )
        port map (
            wr_clk_i     => fb_wr_clk,
            wr_en_i      => fb_wr_en,
            wr_addr_i    => fb_wr_addr,
            wr_data_i    => fb_wr_data,
            wr_ready_o   => fb_wr_ready,
            rd_clk_i     => fb_rd_clk,
            rd_en_i      => fb_rd_en,
            rd_addr_i    => fb_rd_addr,
            rd_data_o    => fb_rd_data,
            rd_ready_o   => fb_rd_ready
        );
    
    -- Instantiate moving ball
    ball: moving_ball
        generic map (
            CLK_FREQ_HZ_g     => CLK_FREQ_HZ_g,
            H_ACTIVE_g        => H_ACTIVE_g,
            V_ACTIVE_g        => V_ACTIVE_g,
            BALL_RADIUS_g     => BALL_RADIUS_g,
            BALL_COLOR_g      => BALL_COLOR_g,
            PIXEL_WIDTH_g     => PIXEL_WIDTH_g
        )
        port map (
            clk_i            => clk_i,
            reset_n_i        => reset_n_i,
            fb_wr_clk_o      => fb_wr_clk,
            fb_wr_en_o       => fb_wr_en,
            fb_wr_addr_o     => fb_wr_addr,
            fb_wr_data_o     => fb_wr_data,
            fb_wr_ready_i    => fb_wr_ready,
            ball_x_o         => ball_x_o,
            ball_y_o         => ball_y_o,
            ball_vx_o        => ball_vx_o,
            ball_vy_o        => ball_vy_o,
            collision_o      => collision_o
        );

end architecture rtl; 