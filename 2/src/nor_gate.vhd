library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity nor_gate is
    Port ( 
        a : in  STD_LOGIC;    -- First input
        b : in  STD_LOGIC;    -- Second input
        y : out STD_LOGIC     -- Output (NOR of inputs)
    );
end nor_gate;

architecture Behavioral of nor_gate is
begin
    -- NOR operation: y = NOT(a OR b)
    y <= NOT(a OR b);
end Behavioral; 