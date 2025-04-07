--------------------------------------------------------------------------------
-- File: frame_buffer.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Frame buffer module implementing double buffering for smooth animation.
-- Provides independent read and write ports for VGA display and ball drawing.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_buffer is
    generic (
        ADDR_WIDTH_g : integer := 20;  -- Address width for 640x480 resolution
        DATA_WIDTH_g : integer := 24   -- RGB color data width
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
end entity frame_buffer;

architecture rtl of frame_buffer is

    -- Memory type definition
    type mem_type is array (0 to 2**ADDR_WIDTH_g-1) of std_logic_vector(DATA_WIDTH_g-1 downto 0);
    
    -- Shared memory signals
    shared variable mem : mem_type;
    
    -- Process signals
    signal wr_ready : std_logic;
    signal rd_ready : std_logic;

begin

    -- Map internal signals to outputs
    wr_ready_o <= wr_ready;
    rd_ready_o <= rd_ready;
    
    -- Write process
    write_process: process(wr_clk_i)
    begin
        if rising_edge(wr_clk_i) then
            wr_ready <= '0';
            if wr_en_i = '1' then
                mem(to_integer(unsigned(wr_addr_i))) := wr_data_i;
                wr_ready <= '1';
            end if;
        end if;
    end process write_process;
    
    -- Read process
    read_process: process(rd_clk_i)
    begin
        if rising_edge(rd_clk_i) then
            rd_ready <= '0';
            if rd_en_i = '1' then
                rd_data_o <= mem(to_integer(unsigned(rd_addr_i)));
                rd_ready <= '1';
            end if;
        end if;
    end process read_process;

end architecture rtl; 