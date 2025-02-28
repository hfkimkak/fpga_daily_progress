library IEEE;
use IEEE.std_logic_1164.all;

-- Entity declaration for multi-input and gate
-- Enhanced version with configurable inputs, enable and complementary output
entity and_gate is
    generic (
        INPUT_WIDTH : positive := 4  -- Number of inputs (default 4)
    );
    port ( 
        inputs : in  std_logic_vector(INPUT_WIDTH-1 downto 0);  -- Input vector
        en     : in  std_logic;                                 -- Enable input (1: enabled, 0: disabled)
        y      : out std_logic;                                -- Normal output
        y_n    : out std_logic                                 -- Complementary output (inverted)
    );
end entity and_gate;

-- Architecture declaration
architecture behavioral of and_gate is
    -- Internal signals for intermediate results and debugging
    signal and_result : std_logic;  -- Stores the AND operation result
begin
    -- Main process for multi-input AND gate with enable control
    main_process: process(inputs, en)
        variable temp_result : std_logic;
    begin
        -- Initialize with '1' for AND reduction
        temp_result := '1';
        
        -- Perform AND operation on all inputs
        for i in inputs'range loop
            temp_result := temp_result and inputs(i);
        end loop;
        
        -- Enable control: output is forced to '0' when disabled
        if (en = '1') then
            and_result <= temp_result;
        else
            and_result <= '0';
        end if;
    end process main_process;
    
    -- Output assignments
    y   <= and_result;      -- Normal output
    y_n <= not and_result;  -- Complementary (inverted) output
    
end architecture behavioral; 