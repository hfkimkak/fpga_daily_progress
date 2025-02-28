library IEEE;
use IEEE.std_logic_1164.all;

-- Entity declaration for and gate
entity and_gate is
    port ( 
        a : in  std_logic;    -- First input
        b : in  std_logic;    -- Second input
        y : out std_logic     -- Output
    );
end and_gate;

-- Architecture declaration
architecture behavioral of and_gate is
begin
    -- Concurrent signal assignment
    y <= a and b;
    
end behavioral; 