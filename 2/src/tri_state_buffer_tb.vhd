library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tri_state_buffer_tb is
end tri_state_buffer_tb;

architecture Behavioral of tri_state_buffer_tb is
    -- Component declaration for the Unit Under Test (UUT)
    component tri_state_buffer
        Port ( 
            a      : in  STD_LOGIC;
            enable : in  STD_LOGIC;
            y      : out STD_LOGIC
        );
    end component;
    
    -- Signals to connect to UUT
    signal a      : std_logic := '0';
    signal enable : std_logic := '0';
    signal y      : std_logic;
    
    -- Clock period definition
    constant clk_period : time := 10 ns;
    
begin
    -- Instantiate the Unit Under Test (UUT)
    uut: tri_state_buffer
        port map (
            a      => a,
            enable => enable,
            y      => y
        );
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Test case 1: Enable = 0, Input = 0
        enable <= '0';
        a <= '0';
        wait for clk_period;
        assert y = 'Z' report "Test case 1 failed" severity error;
        
        -- Test case 2: Enable = 0, Input = 1
        enable <= '0';
        a <= '1';
        wait for clk_period;
        assert y = 'Z' report "Test case 2 failed" severity error;
        
        -- Test case 3: Enable = 1, Input = 0
        enable <= '1';
        a <= '0';
        wait for clk_period;
        assert y = '0' report "Test case 3 failed" severity error;
        
        -- Test case 4: Enable = 1, Input = 1
        enable <= '1';
        a <= '1';
        wait for clk_period;
        assert y = '1' report "Test case 4 failed" severity error;
        
        -- Test case 5: Enable changes from 1 to 0
        enable <= '1';
        a <= '1';
        wait for clk_period;
        enable <= '0';
        wait for clk_period;
        assert y = 'Z' report "Test case 5 failed" severity error;
        
        -- Test case 6: Enable changes from 0 to 1
        enable <= '0';
        a <= '1';
        wait for clk_period;
        enable <= '1';
        wait for clk_period;
        assert y = '1' report "Test case 6 failed" severity error;
        
        -- Add a small delay to see the results in simulation
        wait for 100 ns;
        
        -- End simulation
        assert false report "Simulation completed successfully" severity note;
        wait;
    end process;
    
end Behavioral; 