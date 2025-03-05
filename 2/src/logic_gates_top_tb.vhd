library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity logic_gates_top_tb is
end logic_gates_top_tb;

architecture Behavioral of logic_gates_top_tb is
    -- Component declaration for the Unit Under Test (UUT)
    component logic_gates_top
        Port ( 
            a      : in  STD_LOGIC;
            b      : in  STD_LOGIC;
            enable : in  STD_LOGIC;
            and_out  : out STD_LOGIC;
            or_out   : out STD_LOGIC;
            xor_out  : out STD_LOGIC;
            nand_out : out STD_LOGIC;
            nor_out  : out STD_LOGIC;
            xnor_out : out STD_LOGIC;
            not_a    : out STD_LOGIC;
            not_b    : out STD_LOGIC;
            buffer_out : out STD_LOGIC;
            tri_state_out : out STD_LOGIC
        );
    end component;
    
    -- Signals to connect to UUT
    signal a      : std_logic := '0';
    signal b      : std_logic := '0';
    signal enable : std_logic := '0';
    signal and_out  : std_logic;
    signal or_out   : std_logic;
    signal xor_out  : std_logic;
    signal nand_out : std_logic;
    signal nor_out  : std_logic;
    signal xnor_out : std_logic;
    signal not_a    : std_logic;
    signal not_b    : std_logic;
    signal buffer_out : std_logic;
    signal tri_state_out : std_logic;
    
    -- Clock period definition
    constant clk_period : time := 10 ns;
    
begin
    -- Instantiate the Unit Under Test (UUT)
    uut: logic_gates_top
        port map (
            a      => a,
            b      => b,
            enable => enable,
            and_out  => and_out,
            or_out   => or_out,
            xor_out  => xor_out,
            nand_out => nand_out,
            nor_out  => nor_out,
            xnor_out => xnor_out,
            not_a    => not_a,
            not_b    => not_b,
            buffer_out => buffer_out,
            tri_state_out => tri_state_out
        );
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Test case 1: a=0, b=0, enable=0
        a <= '0'; b <= '0'; enable <= '0';
        wait for clk_period;
        
        -- Check all gate outputs
        assert and_out = '0' report "AND gate test case 1 failed" severity error;
        assert or_out = '0' report "OR gate test case 1 failed" severity error;
        assert xor_out = '0' report "XOR gate test case 1 failed" severity error;
        assert nand_out = '1' report "NAND gate test case 1 failed" severity error;
        assert nor_out = '1' report "NOR gate test case 1 failed" severity error;
        assert xnor_out = '1' report "XNOR gate test case 1 failed" severity error;
        assert not_a = '1' report "NOT A gate test case 1 failed" severity error;
        assert not_b = '1' report "NOT B gate test case 1 failed" severity error;
        assert buffer_out = '0' report "Buffer gate test case 1 failed" severity error;
        assert tri_state_out = 'Z' report "Tri-state buffer test case 1 failed" severity error;
        
        -- Test case 2: a=0, b=1, enable=1
        a <= '0'; b <= '1'; enable <= '1';
        wait for clk_period;
        
        -- Check all gate outputs
        assert and_out = '0' report "AND gate test case 2 failed" severity error;
        assert or_out = '1' report "OR gate test case 2 failed" severity error;
        assert xor_out = '1' report "XOR gate test case 2 failed" severity error;
        assert nand_out = '1' report "NAND gate test case 2 failed" severity error;
        assert nor_out = '0' report "NOR gate test case 2 failed" severity error;
        assert xnor_out = '0' report "XNOR gate test case 2 failed" severity error;
        assert not_a = '1' report "NOT A gate test case 2 failed" severity error;
        assert not_b = '0' report "NOT B gate test case 2 failed" severity error;
        assert buffer_out = '0' report "Buffer gate test case 2 failed" severity error;
        assert tri_state_out = '0' report "Tri-state buffer test case 2 failed" severity error;
        
        -- Test case 3: a=1, b=0, enable=1
        a <= '1'; b <= '0'; enable <= '1';
        wait for clk_period;
        
        -- Check all gate outputs
        assert and_out = '0' report "AND gate test case 3 failed" severity error;
        assert or_out = '1' report "OR gate test case 3 failed" severity error;
        assert xor_out = '1' report "XOR gate test case 3 failed" severity error;
        assert nand_out = '1' report "NAND gate test case 3 failed" severity error;
        assert nor_out = '0' report "NOR gate test case 3 failed" severity error;
        assert xnor_out = '0' report "XNOR gate test case 3 failed" severity error;
        assert not_a = '0' report "NOT A gate test case 3 failed" severity error;
        assert not_b = '1' report "NOT B gate test case 3 failed" severity error;
        assert buffer_out = '1' report "Buffer gate test case 3 failed" severity error;
        assert tri_state_out = '1' report "Tri-state buffer test case 3 failed" severity error;
        
        -- Test case 4: a=1, b=1, enable=0
        a <= '1'; b <= '1'; enable <= '0';
        wait for clk_period;
        
        -- Check all gate outputs
        assert and_out = '1' report "AND gate test case 4 failed" severity error;
        assert or_out = '1' report "OR gate test case 4 failed" severity error;
        assert xor_out = '0' report "XOR gate test case 4 failed" severity error;
        assert nand_out = '0' report "NAND gate test case 4 failed" severity error;
        assert nor_out = '0' report "NOR gate test case 4 failed" severity error;
        assert xnor_out = '1' report "XNOR gate test case 4 failed" severity error;
        assert not_a = '0' report "NOT A gate test case 4 failed" severity error;
        assert not_b = '0' report "NOT B gate test case 4 failed" severity error;
        assert buffer_out = '1' report "Buffer gate test case 4 failed" severity error;
        assert tri_state_out = 'Z' report "Tri-state buffer test case 4 failed" severity error;
        
        -- Add a small delay to see the results in simulation
        wait for 100 ns;
        
        -- End simulation
        assert false report "Simulation completed successfully" severity note;
        wait;
    end process;
    
end Behavioral; 