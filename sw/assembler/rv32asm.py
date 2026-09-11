#!/usr/bin/env python3
"""
rv32asm.py - A small, self-contained RV32IMAC assembler.

Produces $readmemh-compatible hex images for the SoC's boot ROM (text) and
SRAM (data). No external RISC-V toolchain is required.

Supported:
  * Full RV32I (R/I/S/B/U/J), M extension, A extension (.W atomics)
  * CSR instructions and the common machine-mode CSR names
  * ECALL / EBREAK / MRET / WFI / FENCE
  * Pseudo-ops: nop, li, la, mv, j, jr, ret, not, neg, seqz/snez/sltz/sgtz,
    beqz/bnez/blez/bgez/bltz/bgtz, call, tail
  * Directives: .text .data .org .align .word .half .byte .space .globl
    .equ/.set, labels, and ';'/'#'/'//' comments

Usage:
  python3 rv32asm.py input.S -o program.rom.hex [--ram program.ram.hex]
"""

import sys
import re
import argparse

# --------------------------------------------------------------------------
# Memory regions (must match soc_top address map)
# --------------------------------------------------------------------------
TEXT_BASE = 0x8000_0000
DATA_BASE = 0x8001_0000
NOP = 0x0000_0013  # addi x0, x0, 0

# --------------------------------------------------------------------------
# Register name -> number
# --------------------------------------------------------------------------
REGS = {}
for i in range(32):
    REGS[f"x{i}"] = i
ABI = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
    "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6",
]
for i, n in enumerate(ABI):
    REGS[n] = i
REGS["fp"] = REGS["s0"]

CSRS = {
    "mstatus": 0x300, "misa": 0x301, "mie": 0x304, "mtvec": 0x305,
    "mscratch": 0x340, "mepc": 0x341, "mcause": 0x342, "mtval": 0x343,
    "mip": 0x344, "mcycle": 0xB00, "minstret": 0xB02, "mcycleh": 0xB80,
    "minstreth": 0xB82, "cycle": 0xC00, "time": 0xC01, "instret": 0xC02,
    "mhartid": 0xF14,
}

# --------------------------------------------------------------------------
# Opcode / funct fields
# --------------------------------------------------------------------------
OP_LUI    = 0b0110111
OP_AUIPC  = 0b0010111
OP_JAL    = 0b1101111
OP_JALR   = 0b1100111
OP_BRANCH = 0b1100011
OP_LOAD   = 0b0000011
OP_OPIMM  = 0b0010011
OP_STORE  = 0b0100011
OP_OP     = 0b0110011
OP_MISC   = 0b0001111
OP_SYSTEM = 0b1110011
OP_AMO    = 0b0101111


class AsmError(Exception):
    pass


# --------------------------------------------------------------------------
# Encoding helpers
# --------------------------------------------------------------------------
def r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7F) << 25) | ((rs2 & 31) << 20) | ((rs1 & 31) << 15) | \
           ((funct3 & 7) << 12) | ((rd & 31) << 7) | (opcode & 0x7F)


def i_type(imm, rs1, funct3, rd, opcode, signed=True):
    if signed and not (-2048 <= imm <= 2047):
        raise AsmError(f"I-type immediate out of range: {imm}")
    return ((imm & 0xFFF) << 20) | ((rs1 & 31) << 15) | ((funct3 & 7) << 12) | \
           ((rd & 31) << 7) | (opcode & 0x7F)


def s_type(imm, rs2, rs1, funct3, opcode):
    if not (-2048 <= imm <= 2047):
        raise AsmError(f"S-type immediate out of range: {imm}")
    imm &= 0xFFF
    return (((imm >> 5) & 0x7F) << 25) | ((rs2 & 31) << 20) | ((rs1 & 31) << 15) | \
           ((funct3 & 7) << 12) | ((imm & 0x1F) << 7) | (opcode & 0x7F)


def b_type(imm, rs2, rs1, funct3, opcode):
    if imm & 1:
        raise AsmError(f"branch target must be 2-byte aligned: {imm}")
    if not (-4096 <= imm <= 4095):
        raise AsmError(f"B-type immediate out of range: {imm}")
    b = imm & 0x1FFF
    return (((b >> 12) & 1) << 31) | (((b >> 5) & 0x3F) << 25) | ((rs2 & 31) << 20) | \
           ((rs1 & 31) << 15) | ((funct3 & 7) << 12) | (((b >> 1) & 0xF) << 8) | \
           (((b >> 11) & 1) << 7) | (opcode & 0x7F)


def u_type(imm, rd, opcode):
    return (imm & 0xFFFFF000) | ((rd & 31) << 7) | (opcode & 0x7F)


def j_type(imm, rd, opcode):
    if imm & 1:
        raise AsmError(f"jump target must be 2-byte aligned: {imm}")
    if not (-1048576 <= imm <= 1048575):
        raise AsmError(f"J-type immediate out of range: {imm}")
    b = imm & 0x1FFFFF
    return (((b >> 20) & 1) << 31) | (((b >> 1) & 0x3FF) << 21) | \
           (((b >> 11) & 1) << 20) | (((b >> 12) & 0xFF) << 12) | \
           ((rd & 31) << 7) | (opcode & 0x7F)


def amo(funct5, aq, rl, rs2, rs1, rd):
    return ((funct5 & 0x1F) << 27) | ((aq & 1) << 26) | ((rl & 1) << 25) | \
           ((rs2 & 31) << 20) | ((rs1 & 31) << 15) | (0b010 << 12) | \
           ((rd & 31) << 7) | OP_AMO


# --------------------------------------------------------------------------
# Operand parsers
# --------------------------------------------------------------------------
def reg(tok):
    tok = tok.strip().lower()
    if tok not in REGS:
        raise AsmError(f"unknown register '{tok}'")
    return REGS[tok]


def is_reg(tok):
    return tok.strip().lower() in REGS


class Assembler:
    def __init__(self):
        self.symbols = {}      # name -> absolute address
        self.equs = {}         # name -> integer constant
        self.text = {}         # byte address -> word value (text region)
        self.data = {}         # byte address -> byte value (data region)
        self.text_hi = TEXT_BASE
        self.data_hi = DATA_BASE

    # -- value/symbol resolution -----------------------------------------
    def _subst(self, tok):
        """Replace symbol/.equ identifiers with their numeric values so the
        remaining string is a pure arithmetic expression."""
        def repl(m):
            name = m.group(0)
            if name in self.symbols:            # labels are case-sensitive
                return str(self.symbols[name])
            if name.lower() in self.equs:        # .equ names are case-insensitive
                return str(self.equs[name.lower()])
            return name
        # identifiers not preceded by a hex-digit/`.` (so 0x.. literals survive)
        return re.sub(r"(?<![0-9a-fA-FxX._$])[A-Za-z_.$][\w.$]*", repl, tok)

    def resolve(self, tok, pc=None):
        """Resolve an operand to an integer: numbers, symbols, .equ names, and
        arithmetic expressions over them, plus %hi()/%lo()."""
        tok = tok.strip()
        m = re.match(r"^%hi\((.+)\)$", tok)
        if m:
            v = self.resolve(m.group(1), pc) & 0xFFFFFFFF
            return ((v + 0x1000) >> 12) & 0xFFFFF
        m = re.match(r"^%lo\((.+)\)$", tok)
        if m:
            return self.resolve(m.group(1), pc) & 0xFFF
        expr = self._subst(tok)
        if re.fullmatch(r"[0-9a-fA-FxXoObB+\-*/%()&|^~<> \t]+", expr):
            try:
                return int(eval(expr, {"__builtins__": {}}, {}))
            except Exception:
                raise AsmError(f"cannot evaluate expression '{tok}'")
        raise AsmError(f"cannot resolve '{tok}'")

    # -- instruction encode (pass 2) ---------------------------------------
    def encode(self, mnem, ops, pc):
        m = mnem
        o = ops

        def imm(tok):
            return self.resolve(tok, pc)

        def rel(tok):
            v = self.resolve(tok, pc)
            # If the token is a plain small integer, treat as relative offset;
            # otherwise (symbol) it's absolute -> make PC-relative.
            return v - pc

        # ---- pseudo / base ----
        if m == "nop":
            return NOP
        if m == "li":
            rd = reg(o[0]); v = imm(o[1]) & 0xFFFFFFFF
            return self._li(rd, v, pc, single=True)
        if m == "la":
            rd = reg(o[0]); v = imm(o[1]) & 0xFFFFFFFF
            return self._la_single(rd, v)
        if m == "mv":
            return i_type(0, reg(o[1]), 0b000, reg(o[0]), OP_OPIMM)  # addi rd,rs,0
        if m == "not":
            return i_type(-1, reg(o[1]), 0b100, reg(o[0]), OP_OPIMM)  # xori rd,rs,-1
        if m == "neg":
            return r_type(0x20, reg(o[1]), 0, 0b000, reg(o[0]), OP_OP) # sub rd,x0,rs
        if m == "seqz":
            return i_type(1, reg(o[1]), 0b010, reg(o[0]), OP_OPIMM)    # slti rd,rs,1
        if m == "snez":
            return r_type(0, reg(o[1]), 0, 0b011, reg(o[0]), OP_OP)     # sltu rd,x0,rs
        if m == "sltz":
            return r_type(0, 0, reg(o[1]), 0b010, reg(o[0]), OP_OP)     # slt rd,rs,x0
        if m == "sgtz":
            return r_type(0, reg(o[1]), 0, 0b010, reg(o[0]), OP_OP)     # slt rd,x0,rs
        if m == "beqz":
            return b_type(rel(o[1]), 0, reg(o[0]), 0b000, OP_BRANCH)
        if m == "bnez":
            return b_type(rel(o[1]), 0, reg(o[0]), 0b001, OP_BRANCH)
        if m == "blez":
            return b_type(rel(o[1]), reg(o[0]), 0, 0b101, OP_BRANCH)    # bge x0,rs
        if m == "bgez":
            return b_type(rel(o[1]), 0, reg(o[0]), 0b101, OP_BRANCH)    # bge rs,x0
        if m == "bltz":
            return b_type(rel(o[1]), 0, reg(o[0]), 0b100, OP_BRANCH)    # blt rs,x0
        if m == "bgtz":
            return b_type(rel(o[1]), reg(o[0]), 0, 0b100, OP_BRANCH)    # blt x0,rs
        if m == "j":
            return j_type(rel(o[0]), 0, OP_JAL)
        if m == "jal":
            if len(o) == 1:
                return j_type(rel(o[0]), 1, OP_JAL)      # jal ra, label
            return j_type(rel(o[1]), reg(o[0]), OP_JAL)
        if m == "jr":
            return i_type(0, reg(o[0]), 0b000, 0, OP_JALR)
        if m == "ret":
            return i_type(0, 1, 0b000, 0, OP_JALR)       # jalr x0,0(ra)
        if m == "jalr":
            # jalr rd, rs, imm  |  jalr rd, imm(rs)  |  jalr rs
            return self._jalr(o, pc)
        if m == "call":
            return self._call_single(reg(o[0]) if not is_reg(o[0]) else 1, o, pc)
        if m == "fence" or m == "fence.i":
            return i_type(0, 0, 0b000, 0, OP_MISC)

        # ---- LUI / AUIPC ---- (immediate is the 20-bit upper value; GAS-style)
        if m == "lui":
            return u_type((imm(o[1]) & 0xFFFFF) << 12, reg(o[0]), OP_LUI)
        if m == "auipc":
            return u_type((imm(o[1]) & 0xFFFFF) << 12, reg(o[0]), OP_AUIPC)

        # ---- JALR explicit ----
        # ---- OP-IMM (ALU immediate) ----
        opimm = {
            "addi": (0b000, None), "slti": (0b010, None), "sltiu": (0b011, None),
            "xori": (0b100, None), "ori": (0b110, None), "andi": (0b111, None),
        }
        if m in opimm:
            f3, _ = opimm[m]
            return i_type(imm(o[2]), reg(o[1]), f3, reg(o[0]), OP_OPIMM)
        shifti = {"slli": (0b001, 0x00), "srli": (0b101, 0x00), "srai": (0b101, 0x20)}
        if m in shifti:
            f3, f7 = shifti[m]
            sh = imm(o[2]) & 0x1F
            return r_type(f7, sh, reg(o[1]), f3, reg(o[0]), OP_OPIMM)

        # ---- OP (register-register) ----
        op_r = {
            "add": (0x00, 0b000), "sub": (0x20, 0b000), "sll": (0x00, 0b001),
            "slt": (0x00, 0b010), "sltu": (0x00, 0b011), "xor": (0x00, 0b100),
            "srl": (0x00, 0b101), "sra": (0x20, 0b101), "or": (0x00, 0b110),
            "and": (0x00, 0b111),
        }
        if m in op_r:
            f7, f3 = op_r[m]
            return r_type(f7, reg(o[2]), reg(o[1]), f3, reg(o[0]), OP_OP)
        op_m = {
            "mul": 0b000, "mulh": 0b001, "mulhsu": 0b010, "mulhu": 0b011,
            "div": 0b100, "divu": 0b101, "rem": 0b110, "remu": 0b111,
        }
        if m in op_m:
            return r_type(0x01, reg(o[2]), reg(o[1]), op_m[m], reg(o[0]), OP_OP)

        # ---- LOAD ----
        ld = {"lb": (0b000, 1), "lh": (0b001, 1), "lw": (0b010, 1),
              "lbu": (0b100, 1), "lhu": (0b101, 1)}
        if m in ld:
            f3, _ = ld[m]
            off, base = self._mem_operand(o[1], pc)
            return i_type(off, base, f3, reg(o[0]), OP_LOAD)

        # ---- STORE ----
        st = {"sb": 0b000, "sh": 0b001, "sw": 0b010}
        if m in st:
            f3 = st[m]
            off, base = self._mem_operand(o[1], pc)
            # s_type(imm, rs2=data, rs1=base, funct3, opcode)
            return s_type(off, reg(o[0]), base, f3, OP_STORE)

        # ---- BRANCH ----
        br = {"beq": 0b000, "bne": 0b001, "blt": 0b100,
              "bge": 0b101, "bltu": 0b110, "bgeu": 0b111}
        if m in br:
            return b_type(rel(o[2]), reg(o[1]), reg(o[0]), br[m], OP_BRANCH)

        # ---- AMO (A extension) ----
        amo_map = {
            "lr.w": (0b00010, True), "sc.w": (0b00011, True),
            "amoswap.w": (0b00001, False), "amoadd.w": (0b00000, False),
            "amoxor.w": (0b00100, False), "amoand.w": (0b01100, False),
            "amoor.w": (0b01000, False), "amomin.w": (0b10000, False),
            "amomax.w": (0b10001, False), "amominu.w": (0b10100, False),
            "amomaxu.w": (0b10101, False),
        }
        if m in amo_map:
            f5, _ = amo_map[m]
            aq, rl = self._amo_aqrl(o[-1]) if o[-1].strip().lower() in ("aq", "rl", "aqrl") else (0, 0)
            if m == "lr.w":
                # lr.w rd, (rs1)
                base = self._amo_operand(o[1])
                return amo(f5, aq, rl, 0, base, reg(o[0]))
            if m == "sc.w":
                base = self._amo_operand(o[2])
                return amo(f5, aq, rl, reg(o[1]), base, reg(o[0]))
            base = self._amo_operand(o[2])
            return amo(f5, aq, rl, reg(o[1]), base, reg(o[0]))

        # ---- SYSTEM ----
        sysmap = {"ecall": 0x000, "ebreak": 0x001, "mret": 0x302, "wfi": 0x105}
        if m in sysmap:
            return i_type(sysmap[m], 0, 0b000, 0, OP_SYSTEM, signed=False)
        csr_ops = {"csrrw": (0b001, 0), "csrrs": (0b010, 0), "csrrc": (0b011, 0),
                   "csrrwi": (0b101, 1), "csrrsi": (0b110, 1), "csrrci": (0b111, 1)}
        if m in csr_ops:
            f3, is_imm = csr_ops[m]
            csr = self._csr(o[1])
            if is_imm:
                z = imm(o[2]) & 0x1F
                return i_type(csr, z, f3, reg(o[0]), OP_SYSTEM, signed=False)
            return i_type(csr, reg(o[2]), f3, reg(o[0]), OP_SYSTEM, signed=False)
        # csrr/csrrs-style pseudo (csrr rd, csr)
        if m == "csrr":
            return i_type(self._csr(o[1]), 0, 0b010, reg(o[0]), OP_SYSTEM, signed=False)
        if m == "csrw":
            return i_type(self._csr(o[0]), reg(o[1]), 0b001, 0, OP_SYSTEM, signed=False)

        raise AsmError(f"unknown instruction '{m}'")

    # -- helpers ------------------------------------------------------------
    def _csr(self, tok):
        t = tok.strip().lower()
        if t in CSRS:
            return CSRS[t]
        try:
            return int(tok, 0) & 0xFFF
        except ValueError:
            raise AsmError(f"unknown CSR '{tok}'")

    def _mem_operand(self, tok, pc):
        """Parse 'imm(reg)' or 'imm, reg' style; returns (offset, basereg)."""
        tok = tok.strip()
        m = re.match(r"^(.*?)\(\s*([A-Za-z0-9_]+)\s*\)$", tok)
        if m:
            offstr = m.group(1).strip()
            off = self.resolve(offstr, pc) if offstr else 0
            return off, reg(m.group(2))
        raise AsmError(f"bad memory operand '{tok}' (expected imm(reg))")

    def _amo_operand(self, tok):
        tok = tok.strip()
        m = re.match(r"^\(\s*([A-Za-z0-9_]+)\s*\)$", tok)
        if m:
            return reg(m.group(1))
        # allow plain register too
        return reg(tok)

    def _amo_aqrl(self, tok):
        t = tok.strip().lower()
        return (1 if "aq" in t else 0, 1 if "rl" in t else 0)

    def _jalr(self, o, pc):
        # forms: jalr rd, rs, imm | jalr rd, imm(rs) | jalr rs
        if len(o) == 1:
            return i_type(0, reg(o[0]), 0b000, 1, OP_JALR)  # jalr ra, 0(rs)
        # try imm(reg) in last operand
        last = o[-1].strip()
        m = re.match(r"^(.*?)\(\s*([A-Za-z0-9_]+)\s*\)$", last)
        if len(o) == 2:
            if m:
                off = self.resolve(m.group(1), pc) if m.group(1).strip() else 0
                return i_type(off, reg(m.group(2)), 0b000, reg(o[0]), OP_JALR)
            # jalr rd, rs
            return i_type(0, reg(o[1]), 0b000, reg(o[0]), OP_JALR)
        if len(o) == 3:
            off = self.resolve(o[1], pc)
            return i_type(off, reg(o[2]), 0b000, reg(o[0]), OP_JALR)
        raise AsmError("bad jalr operands")

    def _li(self, rd, val, pc, single=False):
        """Single-instruction LI when it fits in 12-bit signed imm."""
        sval = val - (1 << 32) if val & 0x8000_0000 else val
        if -2048 <= sval <= 2047:
            return i_type(sval, 0, 0b000, rd, OP_OPIMM)
        if single:
            raise AsmError(f"li needs 2 instructions for {val:#x}; use full form")
        return None

    def _la_single(self, rd, addr):
        # LA must expand to LUI+ADDI; single-word form unsupported here.
        raise AsmError("la requires two instructions; handled by expander")


# --------------------------------------------------------------------------
# Source preprocessing: strip comments, split into tokens
# --------------------------------------------------------------------------
def strip_comment(line):
    # remove // ; # comments (# only when not an immediate prefix like 0x.. handled
    # by treating '#' and ';' and '//' as comment starts)
    for cmt in ("//", ";"):
        idx = line.find(cmt)
        if idx >= 0:
            line = line[:idx]
    # '#' comment only if preceded by whitespace or at start
    m = re.search(r"(^|\s)#", line)
    if m:
        line = line[:m.start(1) + len(m.group(1))]
    return line


def split_ops(s):
    """Split operand list on commas, but keep 'imm(reg)' together."""
    ops = []
    depth = 0
    cur = ""
    for ch in s:
        if ch == "(":
            depth += 1; cur += ch
        elif ch == ")":
            depth -= 1; cur += ch
        elif ch == "," and depth == 0:
            ops.append(cur.strip()); cur = ""
        else:
            cur += ch
    if cur.strip():
        ops.append(cur.strip())
    return ops


def decode_string(s):
    """Decode a quoted string literal (with escapes) into a list of byte values."""
    s = s.strip()
    m = re.match(r'^"(.*)"\s*$', s, re.S)
    if not m:
        raise AsmError(f"expected quoted string, got '{s}'")
    body = m.group(1)
    out = []
    i = 0
    while i < len(body):
        c = body[i]
        if c == "\\" and i + 1 < len(body):
            n = body[i + 1]
            if n == "n": out.append(0x0A); i += 2
            elif n == "r": out.append(0x0D); i += 2
            elif n == "t": out.append(0x09); i += 2
            elif n == "0": out.append(0x00); i += 2
            elif n == "\\": out.append(0x5C); i += 2
            elif n == '"': out.append(0x22); i += 2
            elif n == "x":
                out.append(int(body[i + 2:i + 4], 16)); i += 4
            else:
                out.append(ord(n)); i += 2
        else:
            out.append(ord(c)); i += 1
    return out


def main():
    ap = argparse.ArgumentParser(description="RV32IMAC assembler")
    ap.add_argument("src")
    ap.add_argument("-o", "--out", default="program.rom.hex", help="ROM (text) hex output")
    ap.add_argument("--ram", default=None, help="RAM (data) hex output")
    ap.add_argument("--text-base", default=None)
    ap.add_argument("--data-base", default=None)
    args = ap.parse_args()

    global TEXT_BASE, DATA_BASE
    if args.text_base:
        TEXT_BASE = int(args.text_base, 0)
    if args.data_base:
        DATA_BASE = int(args.data_base, 0)

    with open(args.src) as f:
        raw_lines = f.readlines()

    asm = Assembler()

    # ---- Pass 0: collect .equ/.set symbols (single pass, simple) ----
    for ln in raw_lines:
        code = strip_comment(ln).strip()
        m = re.match(r"^\.(equ|set)\s+([A-Za-z_.$][\w.$]*)\s*,?\s*(.+)$", code, re.I)
        if m:
            name = m.group(2)
            val = int(m.group(3).strip(), 0)
            asm.equs[name.lower()] = val

    def region_base(region):
        return TEXT_BASE if region == "text" else DATA_BASE

    # ---- Pass 1: assign addresses, expand multi-instruction pseudo-ops ----
    # We build a flat list of "items" each occupying 4 bytes (instructions/words)
    # or N bytes (data), with their addresses, so labels resolve correctly.
    region = "text"
    loc = {"text": TEXT_BASE, "data": DATA_BASE}
    items = []   # (region, addr, kind, payload)

    def cur_pc():
        return loc[region]

    # First, we need labels resolved; do a pass computing addresses.
    # To handle li/la expansion sizes, compute their instruction counts here.
    for raw in raw_lines:
        code = strip_comment(raw).strip()
        if not code:
            continue
        # label
        m = re.match(r"^([A-Za-z_.$][\w.$]*)\s*:\s*(.*)$", code)
        if m:
            name = m.group(1)
            asm.symbols[name] = loc[region]
            code = m.group(2).strip()
            if not code:
                continue
        # directive
        if code.startswith("."):
            d = re.split(r"\s+", code, maxsplit=1)
            name = d[0].lower()
            rest = d[1] if len(d) > 1 else ""
            if name == ".text":
                region = "text"; continue
            if name == ".data":
                region = "data"; continue
            if name == ".globl" or name == ".global":
                continue
            if name in (".equ", ".set"):
                continue
            if name == ".org":
                target = int(rest.split(",")[0].strip(), 0)
                loc[region] = region_base(region) + target
                continue
            if name == ".align":
                n = int(rest.split(",")[0].strip(), 0)
                align = 1 << n
                loc[region] = (loc[region] + align - 1) & ~(align - 1)
                continue
            if name == ".word":
                vals = [v.strip() for v in split_ops(rest)]
                loc[region] += 4 * len(vals); continue
            if name in (".half", ".short"):
                vals = [v.strip() for v in split_ops(rest)]
                loc[region] += 2 * len(vals); continue
            if name == ".byte":
                vals = [v.strip() for v in split_ops(rest)]
                loc[region] += len(vals); continue
            if name in (".space", ".skip", ".zero"):
                parts = split_ops(rest)
                n = int(asm.resolve(parts[0]) if parts else 0)
                loc[region] += n; continue
            if name in (".ascii", ".asciz"):
                b = decode_string(rest) + ([0] if name == ".asciz" else [])
                loc[region] += len(b); continue
            continue
        # instruction: determine size (most are 4 bytes; li/la may be 8)
        parts = re.split(r"[\s,]+", code, maxsplit=1)
        mnem = parts[0].lower()
        ops = split_ops(code[len(parts[0]):].strip()) if len(code) > len(parts[0]) else []
        size = 4
        if mnem in ("li", "la", "call"):
            size = 8  # may expand to two instructions
        loc[region] += size

    # ---- Pass 2: emit bytes/words ----
    region = "text"
    loc = {"text": TEXT_BASE, "data": DATA_BASE}
    text_words = {}   # word index -> value
    data_bytes = {}   # byte offset -> value

    def put_word(addr, val):
        idx = (addr - TEXT_BASE) // 4
        text_words[idx] = val & 0xFFFFFFFF

    def put_data_byte(addr, b):
        data_bytes[addr - DATA_BASE] = b & 0xFF

    for raw in raw_lines:
        code = strip_comment(raw).strip()
        if not code:
            continue
        m = re.match(r"^([A-Za-z_.$][\w.$]*)\s*:\s*(.*)$", code)
        if m:
            code = m.group(2).strip()
            if not code:
                continue
        if code.startswith("."):
            d = re.split(r"\s+", code, maxsplit=1)
            name = d[0].lower()
            rest = d[1] if len(d) > 1 else ""
            if name == ".text":
                region = "text"; continue
            if name == ".data":
                region = "data"; continue
            if name in (".globl", ".global", ".equ", ".set"):
                continue
            if name == ".org":
                target = int(rest.split(",")[0].strip(), 0)
                loc[region] = region_base(region) + target
                continue
            if name == ".align":
                n = int(rest.split(",")[0].strip(), 0)
                align = 1 << n
                loc[region] = (loc[region] + align - 1) & ~(align - 1)
                continue
            if name == ".word":
                for v in split_ops(rest):
                    val = asm.resolve(v) & 0xFFFFFFFF
                    if region == "text":
                        put_word(loc["text"], val)
                    else:
                        for k in range(4):
                            put_data_byte(loc["data"] + k, (val >> (8 * k)) & 0xFF)
                    loc[region] += 4
                continue
            if name in (".half", ".short"):
                for v in split_ops(rest):
                    val = asm.resolve(v) & 0xFFFF
                    for k in range(2):
                        put_data_byte(loc[region] + k, (val >> (8 * k)) & 0xFF)
                    loc[region] += 2
                continue
            if name == ".byte":
                for v in split_ops(rest):
                    val = asm.resolve(v) & 0xFF
                    put_data_byte(loc[region], val)
                    loc[region] += 1
                continue
            if name in (".space", ".skip", ".zero"):
                parts = split_ops(rest)
                n = int(asm.resolve(parts[0]) if parts else 0)
                loc[region] += n
                continue
            if name in (".ascii", ".asciz"):
                if region != "data":
                    sys.exit("Error: .ascii/.asciz only supported in .data")
                b = decode_string(rest) + ([0] if name == ".asciz" else [])
                for ch in b:
                    put_data_byte(loc["data"], ch)
                    loc["data"] += 1
                continue
            continue

        pc = loc[region]
        parts = re.split(r"[\s]+", code, maxsplit=1)
        mnem = parts[0].lower()
        ops = split_ops(parts[1].strip()) if len(parts) > 1 else []

        # expand multi-instruction pseudo-ops
        if mnem == "li":
            words = expand_li(reg_safe(ops[0]), asm.resolve(ops[1]) & 0xFFFFFFFF)
            for i, w in enumerate(words):
                put_word(pc + 4 * i, w)
            loc[region] += 4 * max(len(words), 1)
            # pad reserved size (8) if only one instruction
            if len(words) == 1:
                put_word(pc + 4, NOP)
                loc[region] += 4
            continue
        if mnem == "la":
            words = expand_la(reg_safe(ops[0]), asm.resolve(ops[1]) & 0xFFFFFFFF)
            for i, w in enumerate(words):
                put_word(pc + 4 * i, w)
            loc[region] += 8
            continue
        if mnem == "call":
            words = expand_call(asm.resolve(ops[-1]) & 0xFFFFFFFF, pc)
            for i, w in enumerate(words):
                put_word(pc + 4 * i, w)
            loc[region] += 8
            continue

        try:
            w = asm.encode(mnem, ops, pc)
        except AsmError as e:
            sys.exit(f"Error at 0x{pc:08x} '{code}': {e}")
        put_word(pc, w)
        loc[region] += 4

    # ---- write hex images ----
    write_hex(args.out, text_words, kind="word")
    if args.ram:
        write_hex_bytes(args.ram, data_bytes)

    ntext = (max(text_words) + 1) if text_words else 0
    ndata = (max(data_bytes) + 1) if data_bytes else 0
    print(f"rv32asm: text={ntext} words -> {args.out}" +
          (f", data={ndata} bytes -> {args.ram}" if args.ram else ""))


def reg_safe(tok):
    t = tok.strip().lower()
    if t not in REGS:
        raise AsmError(f"unknown register '{tok}'")
    return REGS[t]


def expand_li(rd, val):
    """Materialize a 32-bit constant in 1 or 2 instructions."""
    sval = val - (1 << 32) if val & 0x8000_0000 else val
    if -2048 <= sval <= 2047:
        return [i_type(sval, 0, 0b000, rd, OP_OPIMM)]
    # lui + addi
    lo = val & 0xFFF
    if lo & 0x800:
        hi = ((val + 0x1000) >> 12) & 0xFFFFF
        addi_imm = lo - 0x1000  # sign-correct
    else:
        hi = (val >> 12) & 0xFFFFF
        addi_imm = lo
    return [u_type(hi << 12, rd, OP_LUI), i_type(addi_imm, rd, 0b000, rd, OP_OPIMM)]


def expand_la(rd, addr):
    lo = addr & 0xFFF
    if lo & 0x800:
        hi = ((addr + 0x1000) >> 12) & 0xFFFFF
        addi_imm = lo - 0x1000
    else:
        hi = (addr >> 12) & 0xFFFFF
        addi_imm = lo
    return [u_type(hi << 12, rd, OP_LUI), i_type(addi_imm, rd, 0b000, rd, OP_OPIMM)]


def expand_call(target, pc):
    # auipc ra, %pcrel_hi ; jalr ra, %pcrel_lo(target)
    off = target - pc
    hi = (off + 0x1000) & 0xFFFFF000
    lo = off - hi
    hi >>= 12
    return [u_type(hi << 12, 1, OP_AUIPC), i_type(lo & 0xFFF, 1, 0b000, 1, OP_JALR)]


def write_hex(path, words, kind="word"):
    n = (max(words) + 1) if words else 0
    with open(path, "w") as f:
        for i in range(n):
            f.write(f"{words.get(i, NOP):08x}\n")


def write_hex_bytes(path, data_bytes):
    n = (max(data_bytes) + 1) if data_bytes else 0
    # pad to word boundary, emit one byte per line (readmemh reads bytes for a
    # byte-wide array is not used; SRAM is word-wide, so emit words)
    nwords = (n + 3) // 4
    with open(path, "w") as f:
        for w in range(nwords):
            val = 0
            for k in range(4):
                b = data_bytes.get(w * 4 + k, 0)
                val |= b << (8 * k)
            f.write(f"{val:08x}\n")


if __name__ == "__main__":
    main()
