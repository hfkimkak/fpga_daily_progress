--------------------------------------------------------------------------------
-- File: vga_controller.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- VGA controller module that generates VGA signals and manages frame buffer.
-- Supports 640x480 resolution at 60 Hz refresh rate.
-- Implements double buffering for smooth animation.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_ball_controller is
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
        PIXEL_WIDTH_g    : integer := 24            -- Total bits per pixel
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
        
        -- Frame buffer interface
        fb_rd_clk_o      : out std_logic;
        fb_rd_en_o       : out std_logic;
        fb_rd_addr_o     : out std_logic_vector(19 downto 0);
        fb_rd_data_i     : in  std_logic_vector(PIXEL_WIDTH_g-1 downto 0);
        fb_rd_ready_i    : in  std_logic;
        
        -- Status outputs
        frame_done_o     : out std_logic;
        vsync_o          : out std_logic;
        hsync_o          : out std_logic;
        pixel_valid_o    : out std_logic;
        pixel_x_o        : out std_logic_vector(9 downto 0);
        pixel_y_o        : out std_logic_vector(9 downto 0)
    );
end entity vga_ball_controller;

architecture rtl of vga_ball_controller is

    -- Constants for timing
    constant H_TOTAL_c   : integer := H_ACTIVE_g + H_FRONT_g + H_SYNC_g + H_BACK_g;
    constant V_TOTAL_c   : integer := V_ACTIVE_g + V_FRONT_g + V_SYNC_g + V_BACK_g;
    
    -- Counter signals
    signal h_counter    : integer range 0 to H_TOTAL_c-1 := 0;
    signal v_counter    : integer range 0 to V_TOTAL_c-1 := 0;
    
    -- VGA control signals
    signal h_sync       : std_logic;
    signal v_sync       : std_logic;
    signal h_blank      : std_logic;
    signal v_blank      : std_logic;
    signal pixel_valid  : std_logic;
    
    -- Frame buffer signals
    signal fb_rd_addr   : std_logic_vector(19 downto 0);
    signal fb_rd_data   : std_logic_vector(PIXEL_WIDTH_g-1 downto 0);
    
    -- Double buffer control
    signal active_buffer : std_logic := '0';
    signal frame_done    : std_logic;
    
begin

    -- Map internal signals to outputs
    vga_hsync_o <= h_sync;
    vga_vsync_o <= v_sync;
    vga_red_o <= fb_rd_data(PIXEL_WIDTH_g-1 downto 2*COLOR_WIDTH_g);
    vga_green_o <= fb_rd_data(2*COLOR_WIDTH_g-1 downto COLOR_WIDTH_g);
    vga_blue_o <= fb_rd_data(COLOR_WIDTH_g-1 downto 0);
    vga_blank_o <= h_blank or v_blank;
    frame_done_o <= frame_done;
    vsync_o <= v_sync;
    hsync_o <= h_sync;
    pixel_valid_o <= pixel_valid;
    pixel_x_o <= std_logic_vector(to_unsigned(h_counter, 10));
    pixel_y_o <= std_logic_vector(to_unsigned(v_counter, 10));
    
    -- Map frame buffer outputs
    fb_rd_clk_o <= clk_i;
    fb_rd_en_o <= pixel_valid;
    fb_rd_addr_o <= fb_rd_addr;
    fb_rd_data <= fb_rd_data_i;
    
    -- VGA timing process
    vga_timing: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            -- Reset all signals
            h_counter <= 0;
            v_counter <= 0;
            h_sync <= '0';
            v_sync <= '0';
            h_blank <= '0';
            v_blank <= '0';
            pixel_valid <= '0';
            frame_done <= '0';
            active_buffer <= '0';
            
        elsif rising_edge(clk_i) then
            -- Reset frame done signal
            frame_done <= '0';
            
            -- Horizontal counter
            if h_counter = H_TOTAL_c-1 then
                h_counter <= 0;
                
                -- Vertical counter
                if v_counter = V_TOTAL_c-1 then
                    v_counter <= 0;
                    active_buffer <= not active_buffer;
                    frame_done <= '1';
                else
                    v_counter <= v_counter + 1;
                end if;
            else
                h_counter <= h_counter + 1;
            end if;
            
            -- Generate horizontal sync
            if h_counter = H_ACTIVE_g + H_FRONT_g - 1 then
                h_sync <= '1';
            elsif h_counter = H_ACTIVE_g + H_FRONT_g + H_SYNC_g - 1 then
                h_sync <= '0';
            end if;
            
            -- Generate vertical sync
            if v_counter = V_ACTIVE_g + V_FRONT_g - 1 then
                v_sync <= '1';
            elsif v_counter = V_ACTIVE_g + V_FRONT_g + V_SYNC_g - 1 then
                v_sync <= '0';
            end if;
            
            -- Generate blank signals
            h_blank <= '1' when h_counter >= H_ACTIVE_g else '0';
            v_blank <= '1' when v_counter >= V_ACTIVE_g else '0';
            
            -- Generate pixel valid signal
            pixel_valid <= '1' when h_counter < H_ACTIVE_g and v_counter < V_ACTIVE_g else '0';
            
            -- Calculate frame buffer read address
            if pixel_valid = '1' then
                fb_rd_addr <= std_logic_vector(to_unsigned(v_counter * H_ACTIVE_g + h_counter, 20));
            end if;
        end if;
    end process vga_timing;
    
end architecture rtl; 