--------------------------------------------------------------------------------
-- File: fifo_memory_tb.vhd
-- Author: Halil Furkan KIMKAK
-- 
-- Description:
-- Testbench for the FIFO memory module.
-- Tests various FIFO operations including write, read, overflow, underflow,
-- and simultaneous read/write operations.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_memory_tb is
    -- Testbench has no ports
end entity fifo_memory_tb;

architecture sim of fifo_memory_tb is

    -- Component declaration for Unit Under Test (UUT)
    component fifo_memory is
        generic (
            DATA_WIDTH_g    : integer := 8;
            FIFO_DEPTH_g    : integer := 16;
            CLK_FREQ_HZ_g   : integer := 50_000_000
        );
        port (
            clk_i           : in  std_logic;
            reset_n_i       : in  std_logic;
            write_en_i      : in  std_logic;
            write_data_i    : in  std_logic_vector(DATA_WIDTH_g-1 downto 0);
            full_o          : out std_logic;
            almost_full_o   : out std_logic;
            read_en_i       : in  std_logic;
            read_data_o     : out std_logic_vector(DATA_WIDTH_g-1 downto 0);
            empty_o         : out std_logic;
            almost_empty_o  : out std_logic;
            fifo_count_o    : out integer range 0 to FIFO_DEPTH_g;
            overflow_o      : out std_logic;
            underflow_o     : out std_logic;
            write_ptr_o     : out integer range 0 to FIFO_DEPTH_g-1;
            read_ptr_o      : out integer range 0 to FIFO_DEPTH_g-1
        );
    end component;
    
    -- Constants
    constant CLK_PERIOD      : time := 20 ns;  -- 50MHz clock
    constant SIMULATION_TIME : time := 100 ms; -- Total simulation time
    constant DATA_WIDTH      : integer := 8;
    constant FIFO_DEPTH      : integer := 16;
    
    -- Clock and reset signals
    signal clk              : std_logic := '0';
    signal reset_n          : std_logic := '0';
    signal simulation_done  : boolean := false;
    
    -- Stimulus signals
    signal write_en         : std_logic := '0';
    signal write_data       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal read_en          : std_logic := '0';
    
    -- Output observation signals
    signal full             : std_logic;
    signal almost_full      : std_logic;
    signal read_data        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal empty            : std_logic;
    signal almost_empty     : std_logic;
    signal fifo_count       : integer range 0 to FIFO_DEPTH;
    signal overflow         : std_logic;
    signal underflow        : std_logic;
    signal write_ptr        : integer range 0 to FIFO_DEPTH-1;
    signal read_ptr         : integer range 0 to FIFO_DEPTH-1;
    
    -- Helper procedure for writing data to FIFO
    procedure write_to_fifo (
        signal write_en : out std_logic;
        signal write_data : out std_logic_vector;
        constant data : in integer;
        constant duration : in time := 10 ns
    ) is
    begin
        write_data <= std_logic_vector(to_unsigned(data, write_data'length));
        write_en <= '1';
        wait for duration;
        write_en <= '0';
        wait for 5 ns;
    end procedure;
    
    -- Helper procedure for reading data from FIFO
    procedure read_from_fifo (
        signal read_en : out std_logic;
        constant duration : in time := 10 ns
    ) is
    begin
        read_en <= '1';
        wait for duration;
        read_en <= '0';
        wait for 5 ns;
    end procedure;
    
begin

    -- Instantiate the Unit Under Test (UUT)
    uut: fifo_memory
        generic map (
            DATA_WIDTH_g    => DATA_WIDTH,
            FIFO_DEPTH_g    => FIFO_DEPTH,
            CLK_FREQ_HZ_g   => 50_000_000
        )
        port map (
            clk_i           => clk,
            reset_n_i       => reset_n,
            write_en_i      => write_en,
            write_data_i    => write_data,
            full_o          => full,
            almost_full_o   => almost_full,
            read_en_i       => read_en,
            read_data_o     => read_data,
            empty_o         => empty,
            almost_empty_o  => almost_empty,
            fifo_count_o    => fifo_count,
            overflow_o      => overflow,
            underflow_o     => underflow,
            write_ptr_o     => write_ptr,
            read_ptr_o      => read_ptr
        );
    
    -- Clock generation process
    clk_gen: process
    begin
        while not simulation_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process clk_gen;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Initialize with reset
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait for 1 us;
        
        -- Test Case 1: Basic Write and Read
        report "Test Case 1: Basic Write and Read";
        
        -- Write some data
        for i in 0 to 5 loop
            write_to_fifo(write_en, write_data, i);
            wait for 10 ns;
        end loop;
        
        -- Read the data
        for i in 0 to 5 loop
            read_from_fifo(read_en);
            wait for 10 ns;
            assert read_data = std_logic_vector(to_unsigned(i, DATA_WIDTH))
                report "Read data mismatch at index " & integer'image(i)
                severity error;
        end loop;
        
        -- Test Case 2: FIFO Full Condition
        report "Test Case 2: FIFO Full Condition";
        
        -- Fill the FIFO
        for i in 0 to FIFO_DEPTH-1 loop
            write_to_fifo(write_en, write_data, i);
            wait for 10 ns;
        end loop;
        
        -- Verify full condition
        assert full = '1' report "FIFO should be full" severity error;
        
        -- Try to write when full
        write_to_fifo(write_en, write_data, 255);
        wait for 10 ns;
        assert overflow = '1' report "Overflow should be detected" severity error;
        
        -- Test Case 3: FIFO Empty Condition
        report "Test Case 3: FIFO Empty Condition";
        
        -- Empty the FIFO
        for i in 0 to FIFO_DEPTH-1 loop
            read_from_fifo(read_en);
            wait for 10 ns;
        end loop;
        
        -- Verify empty condition
        assert empty = '1' report "FIFO should be empty" severity error;
        
        -- Try to read when empty
        read_from_fifo(read_en);
        wait for 10 ns;
        assert underflow = '1' report "Underflow should be detected" severity error;
        
        -- Test Case 4: Almost Full/Empty Conditions
        report "Test Case 4: Almost Full/Empty Conditions";
        
        -- Fill FIFO to almost full
        for i in 0 to FIFO_DEPTH-3 loop
            write_to_fifo(write_en, write_data, i);
            wait for 10 ns;
        end loop;
        
        -- Verify almost full condition
        assert almost_full = '1' report "FIFO should be almost full" severity error;
        
        -- Empty FIFO to almost empty
        for i in 0 to FIFO_DEPTH-3 loop
            read_from_fifo(read_en);
            wait for 10 ns;
        end loop;
        
        -- Verify almost empty condition
        assert almost_empty = '1' report "FIFO should be almost empty" severity error;
        
        -- Test Case 5: Simultaneous Read and Write
        report "Test Case 5: Simultaneous Read and Write";
        
        -- Write some data
        for i in 0 to 3 loop
            write_to_fifo(write_en, write_data, i);
            wait for 10 ns;
        end loop;
        
        -- Perform simultaneous read and write
        for i in 4 to 7 loop
            write_to_fifo(write_en, write_data, i);
            read_from_fifo(read_en);
            wait for 10 ns;
            assert read_data = std_logic_vector(to_unsigned(i-4, DATA_WIDTH))
                report "Read data mismatch during simultaneous operation"
                severity error;
        end loop;
        
        -- Verify FIFO count remains unchanged
        assert fifo_count = 4 report "FIFO count should remain at 4" severity error;
        
        -- End simulation
        wait for 10 ms;
        report "Simulation completed successfully";
        simulation_done <= true;
        wait;
    end process stim_proc;
    
    -- Monitor FIFO state
    monitor_proc: process
    begin
        wait for 1 ms;
        
        while not simulation_done loop
            -- Log current state every 5ms
            wait for 5 ms;
            
            report "Current FIFO state: " &
                   "Count=" & integer'image(fifo_count) &
                   " Full=" & std_logic'image(full) &
                   " Empty=" & std_logic'image(empty) &
                   " WritePtr=" & integer'image(write_ptr) &
                   " ReadPtr=" & integer'image(read_ptr);
        end loop;
        
        wait;
    end process monitor_proc;
    
    -- Simulation time limit
    sim_limit: process
    begin
        wait for SIMULATION_TIME;
        report "Simulation time limit reached";
        simulation_done <= true;
        wait;
    end process sim_limit;
    
end architecture sim; 