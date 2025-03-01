library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity xor_gate_tb is
    -- Testbench doesn't have ports
end entity xor_gate_tb;

architecture testbench of xor_gate_tb is
    -- Constants for test configuration
    constant INPUT_WIDTH : positive := 4;  -- Testing with 4 inputs
    constant CLK_PERIOD : time := 10 ns;
    constant SETUP_TIME : time := 2 ns;
    constant HOLD_TIME  : time := 2 ns;
    
    -- Component declaration for Device Under Test (DUT)
    component xor_gate is
        generic (
            INPUT_WIDTH : positive
        );
        port ( 
            inputs : in  std_logic_vector(INPUT_WIDTH-1 downto 0);
            en     : in  std_logic;
            y      : out std_logic;
            y_n    : out std_logic
        );
    end component;
    
    -- Signal declarations
    signal inputs     : std_logic_vector(INPUT_WIDTH-1 downto 0) := (others => '0');
    signal enable     : std_logic := '0';
    signal output     : std_logic;
    signal output_n   : std_logic;
    signal expected   : std_logic;
    signal test_pass  : boolean := true;
    
begin
    -- Instantiate the Device Under Test (DUT)
    DUT: xor_gate 
        generic map (
            INPUT_WIDTH => INPUT_WIDTH
        )
        port map (
            inputs => inputs,
            en     => enable,
            y      => output,
            y_n    => output_n
        );
        
    -- Expected output calculation process
    expected_proc: process(inputs, enable)
        variable temp : std_logic;
    begin
        temp := '0';
        if enable = '1' then
            for i in inputs'range loop
                temp := temp xor inputs(i);
            end loop;
        else
            temp := '0';
        end if;
        expected <= temp;
    end process;
    
    -- Main test process
    test_proc: process
        -- Procedure for checking outputs
        procedure check_outputs(msg : string) is
        begin
            wait for SETUP_TIME;  -- Wait for outputs to stabilize
            
            -- Check normal output
            assert output = expected
                report "Test failed for " & msg & 
                      ". Expected Y = " & std_logic'image(expected) & 
                      ", got " & std_logic'image(output)
                severity error;
                
            -- Check complementary output
            assert output_n = not expected
                report "Test failed for " & msg & 
                      ". Expected Y_N = " & std_logic'image(not expected) & 
                      ", got " & std_logic'image(output_n)
                severity error;
                
            if (output /= expected) or (output_n /= not expected) then
                test_pass <= false;
            end if;
            
            wait for HOLD_TIME;
        end procedure;
        
    begin
        -- Test Case 1: All inputs 0, enable 0
        report "Test Case 1: All inputs 0, enable 0";
        inputs <= (others => '0');
        enable <= '0';
        check_outputs("all inputs 0, disabled");
        wait for CLK_PERIOD;
        
        -- Test Case 2: All inputs 1, enable 0
        report "Test Case 2: All inputs 1, enable 0";
        inputs <= (others => '1');
        enable <= '0';
        check_outputs("all inputs 1, disabled");
        wait for CLK_PERIOD;
        
        -- Test Case 3: All inputs 1, enable 1
        report "Test Case 3: All inputs 1, enable 1";
        inputs <= (others => '1');
        enable <= '1';
        check_outputs("all inputs 1, enabled");
        wait for CLK_PERIOD;
        
        -- Test Case 4: Mixed inputs, enable 1
        report "Test Case 4: Mixed inputs, enable 1";
        inputs <= "1010";  -- Alternating pattern
        enable <= '1';
        check_outputs("mixed inputs, enabled");
        wait for CLK_PERIOD;
        
        -- Test Case 5: Single bit changes
        report "Test Case 5: Single bit changes";
        enable <= '1';
        inputs <= "0000";
        for i in inputs'range loop
            inputs(i) <= '1';
            check_outputs("single bit 1 at position " & integer'image(i));
            wait for CLK_PERIOD;
        end loop;
        
        -- Test Case 6: Odd number of 1s
        report "Test Case 6: Odd number of 1s";
        enable <= '1';
        inputs <= "1110"; -- 3 ones
        check_outputs("three ones");
        wait for CLK_PERIOD;
        inputs <= "1000"; -- 1 one
        check_outputs("one one");
        wait for CLK_PERIOD;
        
        -- Test Case 7: Even number of 1s
        report "Test Case 7: Even number of 1s";
        enable <= '1';
        inputs <= "1100"; -- 2 ones
        check_outputs("two ones");
        wait for CLK_PERIOD;
        inputs <= "1111"; -- 4 ones
        check_outputs("four ones");
        wait for CLK_PERIOD;
        
        -- Test Case 8: Enable toggling
        report "Test Case 8: Enable toggling";
        inputs <= "1010";
        enable <= '1';
        check_outputs("enable high");
        wait for CLK_PERIOD;
        enable <= '0';
        check_outputs("enable low");
        wait for CLK_PERIOD;
        
        -- End of test reporting
        if test_pass then
            report "All tests passed successfully!"
                severity note;
        else
            report "Some tests failed!"
                severity error;
        end if;
        
        wait;  -- End simulation
    end process;
    
end architecture testbench; 