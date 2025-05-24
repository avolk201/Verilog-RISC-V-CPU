# ELEC2602 Pipelined CPU Project

## Overview
This project implements a simple 4-stage pipelined CPU in Verilog, with support for a small RISC-style ISA (ADD, SUB, LDI, JMP, BEQZ, HALT, STR, LOAD, MOV, JAL, JR, MUL, DIV). It includes:
- Assembler (`Compiler/assembler.py`) that generates hex instruction images.
- Verilog sources for CPU, pipeline registers, hazard and forwarding units.
- Testbench (`TLS/tb_cpu.v`) for simulation and waveform dumping.
- Sample programs (e.g. Fibonacci generator) in `Compiler/`.

## Prerequisites
- Python 3.x
- Icarus Verilog (`iverilog`, `vvp`)
- GNU Make (optional)

## Directory Structure
- `Compiler/` Assembler and ASM programs  
- `IDM/` Instruction & data memory models and init files  
- `PIP/` Pipeline-stage registers (IF/ID, ID/EX, EX/MEM, MEM/WB)  
- `HFU/` Hazard & forward units  
- `CCU/` Control unit  
- `ALU/` Arithmetic Logic Unit  
- `REG/` Register file  
- `TLS/` Testbench  
- `run_project.sh` Automated assemble + simulate script  

## Build & Run

1. Assemble your program (default writes `IDM/instr_init.hex`):
   ```bash
   cd Compiler
   python3 assembler.py program.asm
   ```

2. Compile and simulate:
   ```bash
   cd ..
   chmod +x run_project.sh
   ./run_project.sh
   ```
   - Generates `tb_cpu.vvp` and runs it, producing `tb_cpu.vcd` and `data_mem_out.hex`.
   - Final register values are printed to console.

## Customization
- Edit `Compiler/program.asm` (or any `.asm` under `Compiler/`) and re-run the assembler.
- Override memory init files on compile via `-P instr_mem.MEMFILE=...`.

## File Highlights
- `TLS/tb_cpu.v`: testbench with waveform dump and memory output.
- `PIP/id_ex.v`, `PIP/ex_mem.v`, `PIP/mem_wb.v`: pipeline registers.
- `HFU/hazard.v`, `HFU/forward.v`: handle data hazards and forwarding.
- `CCU/control.v`: opcode→control‐signal mapping.
- `ALU/ALU.v`: supports add, sub, xor, and mult/div operations.
