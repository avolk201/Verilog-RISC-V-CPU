#!/usr/bin/env python3
"""
cd Compiler
python3 compiler.py program.asm
"""

import sys
import argparse

# opcode mapping (3-bit)
OPCODES = {
    'ADD': 0b000,
    'SUB': 0b001,   # control.v expects SUB=3'b001
    'XOR': 0b011,   # control.v expects XOR=3'b011
    'LDI': 0b010,   # control.v expects LDI=3'b010
    'JMP': 0b101,
    'HALT': 0b110,    # was CMP
    'BEQZ': 0b111,   # new
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
        # 3b opcode @ [14:12], 4b rd @ [11:8], 6b imm @ [5:0]
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
        # 3b opcode @ [14:12], 9b target @ [8:0]
        word   = (OPCODES['JMP']<<12) | imm9
    elif instr in ('ADD','SUB','XOR'):
        if len(parts)!=4:
            raise ValueError(f'{instr} takes 3 regs: {line}')
        rd = register_number(parts[1])
        rs = register_number(parts[2])
        rt = register_number(parts[3])
        # 3b opcode @ [14:12], 4b rd @ [11:8], 4b rs @ [7:4], 4b rt @ [3:0]
        word = (OPCODES[instr] << 12) | (rd << 8) | (rs << 4) | rt
    elif instr == 'HALT':
        if len(parts) != 1:
            raise ValueError(f'HALT takes no args: {line}')
        # 3b opcode @ [14:12], rest = 0
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