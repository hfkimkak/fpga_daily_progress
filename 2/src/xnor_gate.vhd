library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity xnor_gate is
    Port ( 
        a : in  STD_LOGIC;    -- First input
        b : in  STD_LOGIC;    -- Second input
        y : out STD_LOGIC     -- Output (XNOR of inputs)
    );
end xnor_gate;

architecture Behavioral of xnor_gate is
begin
    -- XNOR operation: y = NOT(a XOR b)
    y <= NOT(a XOR b);
end Behavioral; 