library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tri_state_buffer is
    Port ( 
        a      : in  STD_LOGIC;    -- Input
        enable : in  STD_LOGIC;    -- Enable control
        y      : out STD_LOGIC     -- Output (Tri-state buffer of input)
    );
end tri_state_buffer;

architecture Behavioral of tri_state_buffer is
begin
    -- Tri-state buffer operation:
    -- When enable = '1': y = a
    -- When enable = '0': y = 'Z' (high impedance)
    y <= a when enable = '1' else 'Z';
end Behavioral; 