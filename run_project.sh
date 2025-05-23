#!/usr/bin/env bash
set -e

# assemble
python3 Compiler/compiler.py Compiler/program.asm

# compile & link, override MEMFILE for both instr_mem & data_mem
iverilog -g2012 \
    -P instr_mem.MEMFILE=\"IDM/instr_init.hex\" \
    -P data_mem.MEMFILE=\"IDM/data_init.hex\" \
    -o tb_cpu.vvp \
    TLS/tb_cpu.v TLS/cpu.v \
    IDM/instr_mem.v IDM/data_mem.v \
    IMGEN/imm_gen.v CCU/control.v \
    BPC/pc.v \
    HFU/forward.v HFU/hazard.v \
    PIP/if_id.v PIP/id_ex.v PIP/ex_mem.v PIP/mem_wb.v \
    REG/regfile.v ALU/ALU.v

# run simulation
vvp tb_cpu.vvp