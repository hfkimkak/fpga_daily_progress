--------------------------------------------------------------------------------
-- File: vga_controller.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- VGA Controller module generating standard VGA timing signals.
-- Supports 640x480@60Hz resolution with 25MHz pixel clock.
-- Provides horizontal and vertical synchronization signals as well as
-- coordinates for current pixel position.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_controller is
    generic (
        -- VGA 640x480@60Hz timing parameters
        H_ACTIVE_g     : integer := 640;    -- Horizontal active pixels
        H_FRONT_PORCH_g: integer := 16;     -- Horizontal front porch
        H_SYNC_PULSE_g : integer := 96;     -- Horizontal sync pulse
        H_BACK_PORCH_g : integer := 48;     -- Horizontal back porch
        H_TOTAL_g      : integer := 800;    -- Total horizontal pixels
        
        V_ACTIVE_g     : integer := 480;    -- Vertical active lines
        V_FRONT_PORCH_g: integer := 10;     -- Vertical front porch
        V_SYNC_PULSE_g : integer := 2;      -- Vertical sync pulse
        V_BACK_PORCH_g : integer := 33;     -- Vertical back porch
        V_TOTAL_g      : integer := 525     -- Total vertical lines
    );
    port (
        -- Clock and reset
        clk_i          : in  std_logic;     -- Pixel clock (25 MHz for 640x480@60Hz)
        reset_n_i      : in  std_logic;     -- Active low reset
        
        -- VGA signals
        hsync_o        : out std_logic;     -- Horizontal sync
        vsync_o        : out std_logic;     -- Vertical sync
        display_ena_o  : out std_logic;     -- Display enable (active region)
        
        -- Pixel coordinates
        column_o       : out integer range 0 to H_ACTIVE_g-1;  -- Current pixel column
        row_o          : out integer range 0 to V_ACTIVE_g-1   -- Current pixel row
    );
end entity vga_controller;

architecture rtl of vga_controller is

    -- Timing counters
    signal h_count     : integer range 0 to H_TOTAL_g-1 := 0;
    signal v_count     : integer range 0 to V_TOTAL_g-1 := 0;
    
    -- Active video region flag
    signal h_active    : std_logic := '0';
    signal v_active    : std_logic := '0';
    
    -- Video sync signals
    signal h_sync      : std_logic := '1';
    signal v_sync      : std_logic := '1';
    
begin

    -- Horizontal counter process
    h_counter_proc: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            h_count <= 0;
        elsif rising_edge(clk_i) then
            if h_count = H_TOTAL_g-1 then
                h_count <= 0;
            else
                h_count <= h_count + 1;
            end if;
        end if;
    end process h_counter_proc;
    
    -- Vertical counter process
    v_counter_proc: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            v_count <= 0;
        elsif rising_edge(clk_i) then
            if h_count = H_TOTAL_g-1 then
                if v_count = V_TOTAL_g-1 then
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
                end if;
            end if;
        end if;
    end process v_counter_proc;
    
    -- Horizontal sync generation
    h_sync_proc: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            h_sync <= '1';
        elsif rising_edge(clk_i) then
            -- H_SYNC is active low
            if h_count >= H_ACTIVE_g + H_FRONT_PORCH_g and h_count < H_ACTIVE_g + H_FRONT_PORCH_g + H_SYNC_PULSE_g then
                h_sync <= '0';
            else
                h_sync <= '1';
            end if;
        end if;
    end process h_sync_proc;
    
    -- Vertical sync generation
    v_sync_proc: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            v_sync <= '1';
        elsif rising_edge(clk_i) then
            -- V_SYNC is active low
            if v_count >= V_ACTIVE_g + V_FRONT_PORCH_g and v_count < V_ACTIVE_g + V_FRONT_PORCH_g + V_SYNC_PULSE_g then
                v_sync <= '0';
            else
                v_sync <= '1';
            end if;
        end if;
    end process v_sync_proc;
    
    -- Active video region flags
    h_active <= '1' when h_count < H_ACTIVE_g else '0';
    v_active <= '1' when v_count < V_ACTIVE_g else '0';
    
    -- Assign output signals
    hsync_o <= h_sync;
    vsync_o <= v_sync;
    display_ena_o <= '1' when (h_active = '1' and v_active = '1') else '0';
    
    -- Assign current pixel coordinates (only valid when display_ena_o is active)
    column_o <= h_count when h_count < H_ACTIVE_g else 0;
    row_o <= v_count when v_count < V_ACTIVE_g else 0;

end architecture rtl; 