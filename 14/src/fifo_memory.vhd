--------------------------------------------------------------------------------
-- File: fifo_memory.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- FIFO (First-In-First-Out) memory module with configurable data width and depth.
-- Implements write and read pointer management, full and empty condition detection,
-- and provides status signals for monitoring FIFO state.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_memory is
    generic (
        -- FIFO configuration
        DATA_WIDTH_g    : integer := 8;     -- Width of data words
        FIFO_DEPTH_g    : integer := 16;    -- Number of words in FIFO (must be power of 2)
        
        -- Timing parameters
        CLK_FREQ_HZ_g   : integer := 50_000_000  -- System clock frequency (Hz)
    );
    port (
        -- Clock and reset
        clk_i           : in  std_logic;
        reset_n_i       : in  std_logic;
        
        -- Write interface
        write_en_i      : in  std_logic;
        write_data_i    : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
        full_o          : out std_logic;
        almost_full_o   : out std_logic;
        
        -- Read interface
        read_en_i       : in  std_logic;
        read_data_o     : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
        empty_o         : out std_logic;
        almost_empty_o  : out std_logic;
        
        -- Status outputs
        fifo_count_o    : out integer range 0 to FIFO_DEPTH_g;
        overflow_o      : out std_logic;
        underflow_o     : out std_logic;
        
        -- Debug outputs
        write_ptr_o     : out integer range 0 to FIFO_DEPTH_g-1;
        read_ptr_o      : out integer range 0 to FIFO_DEPTH_g-1
    );
end entity fifo_memory;

architecture rtl of fifo_memory is

    -- Memory array type and signal
    type memory_array_t is array(0 to FIFO_DEPTH_g-1) of std_logic_vector(DATA_WIDTH_g-1 downto 0);
    signal memory : memory_array_t;
    
    -- Pointer signals
    signal write_ptr : integer range 0 to FIFO_DEPTH_g-1 := 0;
    signal read_ptr  : integer range 0 to FIFO_DEPTH_g-1 := 0;
    
    -- Counter for number of words in FIFO
    signal fifo_count : integer range 0 to FIFO_DEPTH_g := 0;
    
    -- Status signals
    signal full : std_logic;
    signal empty : std_logic;
    signal almost_full : std_logic;
    signal almost_empty : std_logic;
    signal overflow : std_logic;
    signal underflow : std_logic;
    
    -- Constants for almost full/empty thresholds
    constant ALMOST_FULL_THRESHOLD  : integer := FIFO_DEPTH_g - 2;  -- 2 words from full
    constant ALMOST_EMPTY_THRESHOLD : integer := 2;                 -- 2 words from empty
    
begin

    -- Map internal signals to outputs
    full_o <= full;
    empty_o <= empty;
    almost_full_o <= almost_full;
    almost_empty_o <= almost_empty;
    fifo_count_o <= fifo_count;
    overflow_o <= overflow;
    underflow_o <= underflow;
    write_ptr_o <= write_ptr;
    read_ptr_o <= read_ptr;
    
    -- Status signal generation
    full <= '1' when fifo_count = FIFO_DEPTH_g else '0';
    empty <= '1' when fifo_count = 0 else '0';
    almost_full <= '1' when fifo_count >= ALMOST_FULL_THRESHOLD else '0';
    almost_empty <= '1' when fifo_count <= ALMOST_EMPTY_THRESHOLD else '0';
    
    -- Main FIFO operation process
    fifo_operation: process(clk_i, reset_n_i)
        variable write_enabled : boolean;
        variable read_enabled : boolean;
    begin
        if reset_n_i = '0' then
            -- Reset all signals
            memory <= (others => (others => '0'));
            write_ptr <= 0;
            read_ptr <= 0;
            fifo_count <= 0;
            read_data_o <= (others => '0');
            overflow <= '0';
            underflow <= '0';
            
        elsif rising_edge(clk_i) then
            -- Reset error flags
            overflow <= '0';
            underflow <= '0';
            
            -- Determine if write and read are enabled
            write_enabled := (write_en_i = '1') and (full = '0');
            read_enabled := (read_en_i = '1') and (empty = '0');
            
            -- Handle write operation
            if write_enabled then
                memory(write_ptr) <= write_data_i;
                if write_ptr = FIFO_DEPTH_g-1 then
                    write_ptr <= 0;
                else
                    write_ptr <= write_ptr + 1;
                end if;
                fifo_count <= fifo_count + 1;
            else
                overflow <= write_en_i and full;
            end if;
            
            -- Handle read operation
            if read_enabled then
                read_data_o <= memory(read_ptr);
                if read_ptr = FIFO_DEPTH_g-1 then
                    read_ptr <= 0;
                else
                    read_ptr <= read_ptr + 1;
                end if;
                fifo_count <= fifo_count - 1;
            else
                underflow <= read_en_i and empty;
            end if;
            
            -- Handle simultaneous read and write
            if write_enabled and read_enabled then
                fifo_count <= fifo_count;  -- Count remains unchanged
            end if;
        end if;
    end process fifo_operation;
    
end architecture rtl; 