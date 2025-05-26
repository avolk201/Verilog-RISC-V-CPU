#!/usr/bin/env python3
"""
cd Compiler
python3 compiler.py program.asm
"""

import sys
import argparse
import re

# opcode mapping (4-bit)
OPCODES = {
    'ADD':   0b0000,
    'SUB':   0b0001,
    'LDI':   0b0010,
    'XOR':   0b0011,
    'AND':   0b0100,
    'DIV':   0b0101,      # ← reuse the '0101' slot
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

def collect_aliases(raw_lines):
    aliases = {}
    alias_pattern = re.compile(r'^\s*(?:\.alias|EQU)\s+(\w+)\s+(R\d+)\s*$', re.IGNORECASE)
    for ln in raw_lines:
        m = alias_pattern.match(strip_comment(ln))
        if m:
            alias, reg = m.group(1).upper(), m.group(2).upper()
            aliases[alias] = reg
    return aliases

def register_number(tok, aliases=None):
    tok = tok.upper()
    if aliases and tok in aliases:
        tok = aliases[tok]
    if not tok.startswith('R'):
        raise ValueError(f'invalid register {tok}')
    num = int(tok[1:])
    if not 0 <= num < 16:
        raise ValueError(f'register out of range: {tok}')
    return num

def strip_comment(line):
    # Remove comments starting with //, ;, or #
    # But only if # is not part of an immediate value (e.g., LDI R1, #5)
    # We'll treat # as a comment only if it's at the start or after whitespace
    return re.split(r'//|;|(?<!\S)#', line, maxsplit=1)[0]

def parse_number(tok):
    # Accept raw ints, or optionally 0x/0b prefixed
    try:
        return int(tok, 0)
    except ValueError:
        raise ValueError(f"Invalid number: {tok}")

def assemble_line(line, labels, aliases, line_num=None):
    code = strip_comment(line).strip()
    # skip label-only lines
    if code.endswith(':') or not code or code.startswith('.alias') or 'EQU' in code:
        return None
    parts = code.replace(',', ' ').split()
    instr = parts[0].upper()
    try:
        if instr == 'LDI':
            if len(parts)!=3:
                raise ValueError(f'LDI takes 2 args: {line}')
            rd = register_number(parts[1], aliases)
            imm = parse_number(parts[2])
            imm6 = imm & 0x3F
            word = (OPCODES['LDI'] << 12) | (rd << 8) | imm6
        elif instr == 'JMP':
            if len(parts)!=2:
                raise ValueError(f'JMP takes 1 arg: {line}')
            # resolve label or numeric immediate (up to 9 bits)
            tok = parts[1]
            if tok.upper() in labels:
                target = labels[tok.upper()]
            else:
                target = parse_number(tok)
            imm9   = target & 0x1FF
            # 4b opcode @ [15:12], 9b target @ [8:0]
            word   = (OPCODES['JMP']<<12) | imm9
        elif instr in ('ADD','SUB','XOR'):
            if len(parts)!=4:
                raise ValueError(f'{instr} takes 3 regs: {line}')
            rd = register_number(parts[1], aliases)
            rs = register_number(parts[2], aliases)
            rt = register_number(parts[3], aliases)
            # 4b opcode @ [15:12], 4b rd @ [11:8], 4b rs @ [7:4], 4b rt @ [3:0]
            word = (OPCODES[instr] << 12) | (rd << 8) | (rs << 4) | rt
        elif instr == 'AND':
            if len(parts)!=4:
                raise ValueError(f'AND takes 3 regs: {line}')
            rd = register_number(parts[1], aliases)
            rs = register_number(parts[2], aliases)
            rt = register_number(parts[3], aliases)
            word = (OPCODES['AND'] << 12) | (rd << 8) | (rs << 4) | rt
        elif instr == 'STR':
            if len(parts)!=3:
                raise ValueError(f'STR takes 2 args: {line}')
            rs = register_number(parts[1], aliases)
            try:
                addr_reg = register_number(parts[2], aliases)
                # 4b opcode [15:12], 4b rs [11:8], 4b addr_reg [7:4], 4b mode [3:0]=1 for reg-indirect
                word = (OPCODES['STR'] << 12) | (rs << 8) | (addr_reg << 4) | 0x1
            except Exception:
                addr = parse_number(parts[2])
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
            tok = parts[1].upper()              # uppercase the token
            if tok in labels:
                imm9 = labels[tok]
            else:
                imm9 = parse_number(parts[1])
            word = (OPCODES['BEQZ']<<12) | (imm9 & 0x1FF)

        elif instr == 'LOAD':
            if len(parts) != 3:
                raise ValueError(f'LOAD takes 2 args: {line}')
            rd = register_number(parts[1], aliases)
            try:
                addr_reg = register_number(parts[2], aliases)
                # 4b opcode [15:12], 4b rd [11:8], 4b addr_reg [7:4], 4b mode [3:0]=1 for reg-indirect
                word = (OPCODES['LOAD'] << 12) | (rd << 8) | (addr_reg << 4) | 0x1
            except Exception:
                addr = parse_number(parts[2])
                # 4b opcode [15:12], 4b rd [11:8], 8b addr [7:0]
                word = (OPCODES['LOAD'] << 12) | (rd << 8) | (addr & 0xFF)

        elif instr == 'MOV':
            if len(parts) != 3:
                raise ValueError(f'MOV takes 2 args: {line}')
            rd = register_number(parts[1], aliases)
            rs = 0  # Unused
            rt = register_number(parts[2], aliases)  # Source register in rt
            # 4b opcode [15:12], 4b rd [11:8], 4b rs [7:4]=0, 4b rt [3:0]=source
            word = (OPCODES['MOV'] << 12) | (rd << 8) | (rs << 4) | rt
        elif instr == 'JAL':
            # JAL <reg>, <target>
            if len(parts) != 3:
                raise ValueError(f'JAL takes 2 args: {line}')
            rd = register_number(parts[1], aliases)  # link register
            tok = parts[2]
            if tok.upper() in labels:
                target = labels[tok.upper()]
            else:
                target = parse_number(tok)
            imm9 = target & 0x1FF
            word = (OPCODES['JAL'] << 12) | (rd << 8) | imm9
        elif instr == 'JR':
            # JR <reg>
            if len(parts) != 2:
                raise ValueError(f'JR takes 1 reg: {line}')
            rs = register_number(parts[1], aliases)
            word = (OPCODES['JR'] << 12) | (rs << 8)
        elif instr == 'BNE':
            if len(parts) != 2:
                raise ValueError(f'BNE takes 1 label: {line}')
            target = parts[1]
            if target.upper() in labels:
                imm9 = labels[target.upper()]
            else:
                imm9 = parse_number(target)
            # opcode(4) | imm9
            word = (OPCODES['BNE'] << 12) | (imm9 & 0x1FF)
            return word
        elif instr == 'MUL':
            if len(parts) != 4:
                raise ValueError(f"wrong args for MUL: {parts}")
            rd = register_number(parts[1], aliases)
            rs = register_number(parts[2], aliases)
            rt = register_number(parts[3], aliases)
            # opcode@15:12, rd@11:8, rs@7:4, rt@3:0
            word = (OPCODES['MUL'] << 12) | (rd << 8) | (rs << 4) | rt
        elif instr == 'DIV':
            if len(parts)!=4:
                raise ValueError(f"DIV takes 3 regs: {line}")
            rd = register_number(parts[1], aliases)
            rs = register_number(parts[2], aliases)
            rt = register_number(parts[3], aliases)
            word = (OPCODES['DIV'] << 12) | (rd<<8) | (rs<<4) | rt
            return word
        else:
            raise ValueError(f'unknown instruction `{instr}`')
        return word
    except Exception as e:
        # Attach line number to the error if available
        if line_num is not None:
            raise type(e)(f"[Line {line_num}] {e}") from e
        else:
            raise

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

    aliases = collect_aliases(raw)

    # --- pass 1: collect labels ---
    labels = {}
    pc = 0
    for ln in raw:
        code = strip_comment(ln).strip()
        if not code or code.startswith('.alias') or 'EQU' in code:
            continue
        if code.endswith(':'):
            labels[code[:-1].upper()] = pc
        else:
            pc += 1

    # --- pass 2: assemble ---
    words = []
    for idx, ln in enumerate(raw, 1):  # Line numbers start at 1
        try:
            w = assemble_line(ln, labels, aliases, line_num=idx)
        except Exception as e:
            sys.exit(f'Error on line {idx} (`{ln.strip()}`): {e}')
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