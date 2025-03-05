# VHDL Logic Gates Implementation

This project contains the implementation of basic logic gates using VHDL. All logic gates are designed in a modular structure and thoroughly tested.

## Project Structure

```
2/
├── src/                    # Source codes
│   ├── and_gate.vhd       # AND gate implementation
│   ├── and_gate_tb.vhd    # AND gate testbench
│   ├── or_gate.vhd        # OR gate implementation
│   ├── or_gate_tb.vhd     # OR gate testbench
│   ├── xor_gate.vhd       # XOR gate implementation
│   ├── xor_gate_tb.vhd    # XOR gate testbench
│   ├── nand_gate.vhd      # NAND gate implementation
│   ├── nand_gate_tb.vhd   # NAND gate testbench
│   ├── nor_gate.vhd       # NOR gate implementation
│   ├── nor_gate_tb.vhd    # NOR gate testbench
│   ├── xnor_gate.vhd      # XNOR gate implementation
│   ├── xnor_gate_tb.vhd   # XNOR gate testbench
│   ├── buffer_gate.vhd    # Buffer gate implementation
│   ├── buffer_gate_tb.vhd # Buffer gate testbench
│   ├── tri_state_buffer.vhd    # Tri-state Buffer implementation
│   ├── tri_state_buffer_tb.vhd # Tri-state Buffer testbench
│   ├── logic_gates_top.vhd     # Top module combining all gates
│   └── logic_gates_top_tb.vhd  # Top module testbench
└── docs/                  # Documentation
```

## Implemented Logic Gates

1. **AND Gate**
   - Two inputs (a, b) and one output (y)
   - Output is the logical AND of inputs

2. **OR Gate**
   - Two inputs (a, b) and one output (y)
   - Output is the logical OR of inputs

3. **XOR Gate**
   - Two inputs (a, b) and one output (y)
   - Output is the logical XOR of inputs

4. **NAND Gate**
   - Two inputs (a, b) and one output (y)
   - Output is the inverse of AND operation

5. **NOR Gate**
   - Two inputs (a, b) and one output (y)
   - Output is the inverse of OR operation

6. **XNOR Gate**
   - Two inputs (a, b) and one output (y)
   - Output is the inverse of XOR operation

7. **NOT Gate**
   - One input (a) and one output (y)
   - Output is the inverse of input

8. **Buffer Gate**
   - One input (a) and one output (y)
   - Output is the same as input

9. **Tri-state Buffer Gate**
   - Two inputs (a, enable) and one output (y)
   - When enable is active, output follows input
   - When enable is inactive, output goes to high impedance (Z) state

## Top Module

The `logic_gates_top.vhd` module combines all logic gates into a single module. This module:

- Takes two input signals (a, b) and one enable signal
- Provides outputs for all logic gates
- Can be used to test the correct operation of each gate

## Testbenches

Separate testbenches have been created for each gate. The testbenches:

- Test all possible input combinations
- Verify expected outputs for each test case
- Provide detailed reporting in case of errors

The top module testbench (`logic_gates_top_tb.vhd`) tests all gates working together and includes the following test cases:

1. a=0, b=0, enable=0
2. a=0, b=1, enable=1
3. a=1, b=0, enable=1
4. a=1, b=1, enable=0

## Simulation

To simulate the project:

1. Create a new project in Vivado
2. Add all source files to the project
3. Select `logic_gates_top_tb.vhd` for simulation
4. Run the simulation

## Usage

1. Use individual gate testbenches to test each gate separately
2. Use `logic_gates_top_tb.vhd` to test all gates together
3. Check simulation results and examine error reports

## Development

To add a new gate:

1. Add the gate's VHDL code to the `src/` directory
2. Create a testbench for the gate
3. Add the new gate to the top module
4. Update the top module testbench 