# VHDL Style Guide and Linting Rules

This document defines the VHDL coding style and linting rules to be followed for all VHDL code in this project.

## General Formatting

1. **Indentation**: Use 4 spaces for indentation (no tabs).
2. **Line Length**: Keep lines under 120 characters when possible.
3. **File Structure**: Follow the consistent template structure for all VHDL files.
4. **Comments**: Use `--` for single-line comments and `--!` for documentation comments.
5. **Blank Lines**: Use blank lines to separate logical sections of code.

## Naming Conventions

1. **Entity Names**: Use lowercase with underscore separators (`entity_name`).
2. **Architecture Names**: Use descriptive names like `rtl`, `behavioral`, `structural`.
3. **Signal Names**: Use lowercase with underscore separators and `_s` suffix (`signal_name_s`).
4. **Constant Names**: Use uppercase with underscore separators and `_c` suffix (`CONSTANT_NAME_C`).
5. **Generic Names**: Use uppercase with underscore separators and `_g` suffix (`GENERIC_NAME_G`).
6. **Port Names**: Use lowercase with underscore separators and `_i` suffix for inputs, `_o` suffix for outputs, and `_io` suffix for bidirectional ports.
7. **Type Names**: Use lowercase with underscore separators and `_t` suffix (`type_name_t`).

## Code Organization

1. **Entity Declaration**: Place generics before ports.
2. **Architecture Sections**: Organize in the following order:
   - Component declarations
   - Type declarations
   - Constant declarations
   - Signal declarations
   - Attribute declarations
   - Begin section
   - Combinational logic
   - Sequential logic
   - Component instantiations

3. **Process Organization**: Each process should have a single purpose.

## Process Style

1. **Process Sensitivity List**: Include all signals read inside the process.
2. **Process Names**: Give descriptive names to all processes followed by `_proc`.
3. **Reset Handling**: Reset should be the first condition in any synchronized process.
4. **Process Declaration**: Always use `is` keyword in process declaration.

## Signal Assignments

1. **Signal Initialization**: Initialize all signals at declaration when appropriate.
2. **Conditional Signal Assignment**: Use parentheses for clarity in complex expressions.

## Best Practices

1. **Constants Over Magic Numbers**: Use constants instead of hard-coded values.
2. **Signal vs. Variable**: Prefer signals over variables when appropriate.
3. **Synchronous Design**: Use synchronous design principles.
4. **Reset Strategy**: Use asynchronous reset, synchronous release.
5. **Clock Domain Crossing**: Handle clock domain crossings properly.
6. **Documentation**: Document all entities, ports, generics, signals, and functions.
7. **Comments**: Add descriptive comments for non-obvious logic.

## Example

```vhdl
---------------------------------------------------------------------------------------------------
-- Author      : John Doe
-- Description : Example VHDL file showing style guidelines
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity example_entity is
    generic (
        GENERIC_PARAM_g : integer := 8 --! Documentation comment
    );
    port (
        clk_i     : in  std_logic;                              --! System clock
        reset_n_i : in  std_logic;                              --! Active low reset
        data_i    : in  std_logic_vector(GENERIC_PARAM_g-1 downto 0); --! Input data
        valid_i   : in  std_logic;                              --! Input valid signal
        data_o    : out std_logic_vector(GENERIC_PARAM_g-1 downto 0); --! Output data
        valid_o   : out std_logic                               --! Output valid signal
    );
end entity example_entity;

architecture rtl of example_entity is

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLERATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    signal data_reg_s  : std_logic_vector(GENERIC_PARAM_g-1 downto 0); --! Data register
    signal valid_reg_s : std_logic;                                     --! Valid register

begin

    --------------------------------------------------------------------------------------------------------------------
    -- PROCESS_NAME_PROC : Process description
    --------------------------------------------------------------------------------------------------------------------
    process_name_proc : process(clk_i, reset_n_i) is
    begin
        if (reset_n_i = '0') then
            data_reg_s  <= (others => '0');
            valid_reg_s <= '0';
        elsif (rising_edge(clk_i)) then
            if (valid_i = '1') then
                data_reg_s  <= data_i;
                valid_reg_s <= '1';
            else
                valid_reg_s <= '0';
            end if;
        end if;
    end process process_name_proc;
    
    -- Output assignment
    data_o  <= data_reg_s;
    valid_o <= valid_reg_s;

end architecture rtl; 