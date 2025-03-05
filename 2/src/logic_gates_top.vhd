library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity logic_gates_top is
    Port ( 
        -- Inputs
        a      : in  STD_LOGIC;    -- First input for gates
        b      : in  STD_LOGIC;    -- Second input for gates
        enable : in  STD_LOGIC;    -- Enable for tri-state buffer
        
        -- Outputs for each gate
        and_out  : out STD_LOGIC;  -- AND gate output
        or_out   : out STD_LOGIC;  -- OR gate output
        xor_out  : out STD_LOGIC;  -- XOR gate output
        nand_out : out STD_LOGIC;  -- NAND gate output
        nor_out  : out STD_LOGIC;  -- NOR gate output
        xnor_out : out STD_LOGIC;  -- XNOR gate output
        not_a    : out STD_LOGIC;  -- NOT gate output for input a
        not_b    : out STD_LOGIC;  -- NOT gate output for input b
        buffer_out : out STD_LOGIC; -- Buffer output
        tri_state_out : out STD_LOGIC -- Tri-state buffer output
    );
end logic_gates_top;

architecture Behavioral of logic_gates_top is
    -- Component declarations
    component and_gate
        Port ( 
            a : in  STD_LOGIC;
            b : in  STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;
    
    component or_gate
        Port ( 
            a : in  STD_LOGIC;
            b : in  STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;
    
    component xor_gate
        Port ( 
            a : in  STD_LOGIC;
            b : in  STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;
    
    component nand_gate
        Port ( 
            a : in  STD_LOGIC;
            b : in  STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;
    
    component nor_gate
        Port ( 
            a : in  STD_LOGIC;
            b : in  STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;
    
    component xnor_gate
        Port ( 
            a : in  STD_LOGIC;
            b : in  STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;
    
    component buffer_gate
        Port ( 
            a : in  STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;
    
    component tri_state_buffer
        Port ( 
            a      : in  STD_LOGIC;
            enable : in  STD_LOGIC;
            y      : out STD_LOGIC
        );
    end component;
    
begin
    -- Instantiate all gates
    and_gate_inst: and_gate
        port map (
            a => a,
            b => b,
            y => and_out
        );
    
    or_gate_inst: or_gate
        port map (
            a => a,
            b => b,
            y => or_out
        );
    
    xor_gate_inst: xor_gate
        port map (
            a => a,
            b => b,
            y => xor_out
        );
    
    nand_gate_inst: nand_gate
        port map (
            a => a,
            b => b,
            y => nand_out
        );
    
    nor_gate_inst: nor_gate
        port map (
            a => a,
            b => b,
            y => nor_out
        );
    
    xnor_gate_inst: xnor_gate
        port map (
            a => a,
            b => b,
            y => xnor_out
        );
    
    -- NOT gates are implemented using NAND gates with same input
    not_a <= NOT a;
    not_b <= NOT b;
    
    -- Buffer gate
    buffer_gate_inst: buffer_gate
        port map (
            a => a,
            y => buffer_out
        );
    
    -- Tri-state buffer
    tri_state_buffer_inst: tri_state_buffer
        port map (
            a      => a,
            enable => enable,
            y      => tri_state_out
        );
    
end Behavioral; 