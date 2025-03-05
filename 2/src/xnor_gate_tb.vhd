library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity xnor_gate_tb is
end xnor_gate_tb;

architecture Behavioral of xnor_gate_tb is
    -- Component declaration for the Unit Under Test (UUT)
    component xnor_gate
        Port ( 
            a : in  STD_LOGIC;
            b : in  STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;
    
    -- Signals to connect to UUT
    signal a : std_logic := '0';
    signal b : std_logic := '0';
    signal y : std_logic;
    
    -- Clock period definition
    constant clk_period : time := 10 ns;
    
begin
    -- Instantiate the Unit Under Test (UUT)
    uut: xnor_gate
        port map (
            a => a,
            b => b,
            y => y
        );
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Test case 1: 0 XNOR 0 = 1
        a <= '0'; b <= '0';
        wait for clk_period;
        assert y = '1' report "Test case 1 failed" severity error;
        
        -- Test case 2: 0 XNOR 1 = 0
        a <= '0'; b <= '1';
        wait for clk_period;
        assert y = '0' report "Test case 2 failed" severity error;
        
        -- Test case 3: 1 XNOR 0 = 0
        a <= '1'; b <= '0';
        wait for clk_period;
        assert y = '0' report "Test case 3 failed" severity error;
        
        -- Test case 4: 1 XNOR 1 = 1
        a <= '1'; b <= '1';
        wait for clk_period;
        assert y = '1' report "Test case 4 failed" severity error;
        
        -- Add a small delay to see the results in simulation
        wait for 100 ns;
        
        -- End simulation
        assert false report "Simulation completed successfully" severity note;
        wait;
    end process;
    
end Behavioral; 