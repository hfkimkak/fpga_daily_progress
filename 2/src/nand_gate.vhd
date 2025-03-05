library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity nand_gate is
    Port ( 
        a : in  STD_LOGIC;    -- First input
        b : in  STD_LOGIC;    -- Second input
        y : out STD_LOGIC     -- Output (NAND of inputs)
    );
end nand_gate;

architecture Behavioral of nand_gate is
begin
    -- NAND operation: y = NOT(a AND b)
    y <= NOT(a AND b);
end Behavioral; 