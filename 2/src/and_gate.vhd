library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Entity declaration for AND gate
entity and_gate is
    Port ( 
        A : in  STD_LOGIC;    -- First input
        B : in  STD_LOGIC;    -- Second input
        Y : out STD_LOGIC     -- Output
    );
end and_gate;

-- Architecture declaration
architecture Behavioral of and_gate is
begin
    -- Concurrent signal assignment
    Y <= A and B;
    
end Behavioral; 