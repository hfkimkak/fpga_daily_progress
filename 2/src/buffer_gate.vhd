library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity buffer_gate is
    Port ( 
        a : in  STD_LOGIC;    -- Input
        y : out STD_LOGIC     -- Output (Buffer of input)
    );
end buffer_gate;

architecture Behavioral of buffer_gate is
begin
    -- Buffer operation: y = a (direct connection)
    y <= a;
end Behavioral; 