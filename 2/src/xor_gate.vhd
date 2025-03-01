library IEEE;
use IEEE.std_logic_1164.all;

-- Entity declaration for multi-input xor gate
-- Enhanced version with configurable inputs, enable and complementary output
entity xor_gate is
    generic (
        INPUT_WIDTH : positive := 4  -- Number of inputs (default 4)
    );
    port ( 
        inputs : in  std_logic_vector(INPUT_WIDTH-1 downto 0);  -- Input vector
        en     : in  std_logic;                                 -- Enable input (1: enabled, 0: disabled)
        y      : out std_logic;                                -- Normal output
        y_n    : out std_logic                                 -- Complementary output (inverted)
    );
end entity xor_gate;

-- Architecture declaration
architecture behavioral of xor_gate is
    -- Internal signals for intermediate results and debugging
    signal xor_result : std_logic;  -- Stores the XOR operation result
begin
    -- Main process for multi-input XOR gate with enable control
    main_process: process(inputs, en)
        variable temp_result : std_logic;
    begin
        -- Initialize with '0' for XOR reduction
        temp_result := '0';
        
        -- Perform XOR operation on all inputs
        for i in inputs'range loop
            temp_result := temp_result xor inputs(i);
        end loop;
        
        -- Enable control: output is forced to '0' when disabled
        if (en = '1') then
            xor_result <= temp_result;
        else
            xor_result <= '0';
        end if;
    end process main_process;
    
    -- Output assignments
    y   <= xor_result;       -- Normal output
    y_n <= not xor_result;   -- Complementary (inverted) output
    
end architecture behavioral; 