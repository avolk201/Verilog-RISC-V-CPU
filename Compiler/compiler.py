#!/usr/bin/env python3
"""
cd Compiler
python3 compiler.py program.asm
"""

import sys
import argparse

# opcode mapping (4-bit)
OPCODES = {
    'ADD':   0b0000,
    'SUB':   0b0001,
    'LDI':   0b0010,
    'XOR':   0b0011,
    'AND':   0b0100,
    'OR':    0b0101,
    'JMP':   0b0110,
    'HALT':  0b0111,
    'BEQZ':  0b1000,
    'STR':   0b1001,
    'LOAD':  0b1010,
    'MOV':   0b1011,
    'JAL':   0b1100,
    'JR':    0b1101,
    'BNE':   0b1110,
    'MUL':   0b1111,    # <- new
}

def register_number(tok):
    # R0..R7
    if not tok.upper().startswith('R'):
        raise ValueError(f'invalid register {tok}')
    num = int(tok[1:])
    if not 0 <= num < 16:
        raise ValueError(f'register out of range: {tok}')
    return num

def assemble_line(line, labels):
    # remove comments and whitespace
    code = line.split('//',1)[0].strip()
    # skip label-only lines
    if code.endswith(':'):
        return None
    if not code:
        return None
    parts = code.replace(',', ' ').split()
    instr = parts[0].upper()
    if instr == 'LDI':
        if len(parts)!=3:
            raise ValueError(f'LDI takes 2 args: {line}')
        rd = register_number(parts[1])
        imm = int(parts[2].lstrip('#'), 0)
        # sign-extend to 6 bits
        imm6 = imm & 0x3F
        # 4b opcode @ [15:12], 4b rd @ [11:8], 6b imm @ [5:0]
        word = (OPCODES['LDI'] << 12) | (rd << 8) | imm6
    elif instr == 'JMP':
        if len(parts)!=2:
            raise ValueError(f'JMP takes 1 arg: {line}')
        # resolve label or numeric immediate (up to 9 bits)
        tok = parts[1]
        if tok.upper() in labels:
            target = labels[tok.upper()]
        else:
            target = int(tok.lstrip('#'), 0)
        imm9   = target & 0x1FF
        # 4b opcode @ [15:12], 9b target @ [8:0]
        word   = (OPCODES['JMP']<<12) | imm9
    elif instr in ('ADD','SUB','XOR'):
        if len(parts)!=4:
            raise ValueError(f'{instr} takes 3 regs: {line}')
        rd = register_number(parts[1])
        rs = register_number(parts[2])
        rt = register_number(parts[3])
        # 4b opcode @ [15:12], 4b rd @ [11:8], 4b rs @ [7:4], 4b rt @ [3:0]
        word = (OPCODES[instr] << 12) | (rd << 8) | (rs << 4) | rt
    elif instr == 'AND':
        if len(parts)!=4:
            raise ValueError(f'AND takes 3 regs: {line}')
        rd = register_number(parts[1])
        rs = register_number(parts[2])
        rt = register_number(parts[3])
        word = (OPCODES['AND'] << 12) | (rd << 8) | (rs << 4) | rt
    elif instr == 'STR':
        if len(parts)!=3:
            raise ValueError(f'STR takes 2 args: {line}')
        rs = register_number(parts[1])
        # Check if second arg is a register or immediate
        if parts[2].upper().startswith('R'):
            addr_reg = register_number(parts[2])
            # 4b opcode [15:12], 4b rs [11:8], 4b addr_reg [7:4], 4b mode [3:0]=1 for reg-indirect
            word = (OPCODES['STR'] << 12) | (rs << 8) | (addr_reg << 4) | 0x1
        else:
            addr = int(parts[2].lstrip('#'), 0)
            # 4b opcode [15:12], 4b rs [11:8], 8b addr [7:0]
            word = (OPCODES['STR'] << 12) | (rs << 8) | (addr & 0xFF)
    elif instr == 'HALT':
        if len(parts) != 1:
            raise ValueError(f'HALT takes no args: {line}')
        # 4b opcode @ [15:12], rest = 0
        word = (OPCODES['HALT'] << 12)
    elif instr == 'BEQZ':
        if len(parts)!=2:
            raise ValueError(f'BEQZ takes 1 label: {line}')
        target = parts[1]
        if target in labels:
            imm9 = labels[target]
        else:
            imm9 = int(target.lstrip('#'),0)
        word = (OPCODES['BEQZ']<<12) | (imm9 & 0x1FF)

    elif instr == 'LOAD':
        if len(parts) != 3:
            raise ValueError(f'LOAD takes 2 args: {line}')
        rd = register_number(parts[1])
        # Check if the second argument is a register
        if parts[2].upper().startswith('R'):
            addr_reg = register_number(parts[2])
            # 4b opcode [15:12], 4b rd [11:8], 4b addr_reg [7:4], 4b mode [3:0]=1 for reg-indirect
            word = (OPCODES['LOAD'] << 12) | (rd << 8) | (addr_reg << 4) | 0x1
        else:
            addr = int(parts[2].lstrip('#'), 0)
            # 4b opcode [15:12], 4b rd [11:8], 8b addr [7:0]
            word = (OPCODES['LOAD'] << 12) | (rd << 8) | (addr & 0xFF)

    elif instr == 'MOV':
        if len(parts) != 3:
            raise ValueError(f'MOV takes 2 args: {line}')
        rd = register_number(parts[1])
        rs = 0  # Unused
        rt = register_number(parts[2])  # Source register in rt
        # 4b opcode [15:12], 4b rd [11:8], 4b rs [7:4]=0, 4b rt [3:0]=source
        word = (OPCODES['MOV'] << 12) | (rd << 8) | (rs << 4) | rt
    elif instr == 'JAL':
        # JAL <reg>, <target>
        if len(parts) != 3:
            raise ValueError(f'JAL takes 2 args: {line}')
        rd = register_number(parts[1])  # link register
        tok = parts[2]
        if tok.upper() in labels:
            target = labels[tok.upper()]
        else:
            target = int(tok.lstrip('#'), 0)
        imm9 = target & 0x1FF
        word = (OPCODES['JAL'] << 12) | (rd << 8) | imm9
    elif instr == 'JR':
        # JR <reg>
        if len(parts) != 2:
            raise ValueError(f'JR takes 1 reg: {line}')
        rs = register_number(parts[1])
        word = (OPCODES['JR'] << 12) | (rs << 8)
    elif instr == 'BNE':
        if len(parts) != 2:
            raise ValueError(f'BNE takes 1 label: {line}')
        target = parts[1]
        if target.upper() in labels:
            imm9 = labels[target.upper()]
        else:
            imm9 = int(target.lstrip('#'), 0)
        # opcode(4) | imm9
        word = (OPCODES['BNE'] << 12) | (imm9 & 0x1FF)
        return word
    elif instr == 'MUL':
        if len(parts) != 4:
            raise ValueError(f"wrong args for MUL: {parts}")
        rd = register_number(parts[1])
        rs = register_number(parts[2])
        rt = register_number(parts[3])
        # opcode@15:12, rd@11:8, rs@7:4, rt@3:0
        word = (OPCODES['MUL'] << 12) | (rd << 8) | (rs << 4) | rt
    else:
        raise ValueError(f'unknown instruction `{instr}`')
    return word

def main():
    ap = argparse.ArgumentParser(description='Simple 15-bit assembler → hex')
    ap.add_argument('src', help='assembly source file')
    ap.add_argument('-o','--out', default='IDM/instr_init.hex',
                    help='output hex file (default: %(default)s)')
    ap.add_argument('-d','--depth', type=int, default=256,
                    help='total memory depth (pad with NOPs up to this many words)')
    args = ap.parse_args()

    # read all lines
    with open(args.src) as f:
        raw = f.readlines()

    # --- pass 1: collect labels ---
    labels = {}
    pc = 0
    for ln in raw:
        code = ln.split('//',1)[0].strip()
        if not code:
            continue
        if code.endswith(':'):
            labels[code[:-1].upper()] = pc
        else:
            pc += 1

    # --- pass 2: assemble ---
    words = []
    for ln in raw:
        try:
            w = assemble_line(ln, labels)
        except Exception as e:
            sys.exit(f'Error on line `{ln.strip()}`: {e}')
        if w is not None:
            words.append(w)

    # pad with NOPs (0) up to requested depth
    if len(words) < args.depth:
        words.extend([0] * (args.depth - len(words)))

    # write hex, one 4-digit word per line
    with open(args.out, 'w') as f:
        for w in words:
            f.write(f"{w:04X}\n")

    print(f"wrote {len(words)} instructions to {args.out}")

if __name__ == '__main__':
    main()