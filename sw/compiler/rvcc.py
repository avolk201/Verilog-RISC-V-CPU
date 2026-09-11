#!/usr/bin/env python3
"""
rvcc.py - A rudimentary C compiler targeting the RV32IMAC SoC.

It compiles a useful subset of C to this project's RISC-V assembly, which is then
fed to rv32asm.py to produce ROM/RAM hex images. Zero external dependencies.

Supported subset
----------------
  types      : int, char, void, pointers (T*), fixed-size arrays (T a[N])
  functions  : definitions, calls, recursion; parameters and locals
  control    : if/else, while, for, break, continue, return, blocks
  operators  : + - * / %  & | ^  << >>  == != < > <= >=  && || !  ~ -
               = += -= *= /= %=  ++ --  *deref &addr  a[i]  (T)cast  sizeof
  literals   : integers (dec/hex), char literals, string literals
  intrinsics : hartid(), amoswap(p,v), amoadd(p,v), membar()   (no definition)
  cpp        : // and /* */ comments, #define NAME VALUE, #include "file"

Calling convention (compiler-internal): frame pointer in s0; caller pushes args
right-to-left and pops them; return value in a0. Expression evaluation is a
stack machine with a0 as the accumulator.

Status & Multicore Notes:
  - Single-core C execution is fully verified (see sw/tests/c_arith.c, hello_uart.c).
  - Multi-core C support is a work-in-progress (WIP). While the underlying hardware
    SMP, bus arbitration, and atomic instructions are fully verified via assembly
    (sw/tests/multicore_lock.S), the compiler's unoptimized stack-machine codegen
    and memory-based stack operations encounter bus contention under heavy SMP.

Usage:
  python3 rvcc.py prog.c -o prog.S            # emit assembly
  python3 rvcc.py prog.c --rom prog.rom.hex --ram prog.ram.hex   # compile+assemble
"""

import sys
import re
import os
import argparse

HERE = os.path.dirname(os.path.abspath(__file__))
ASM = os.path.normpath(os.path.join(HERE, "..", "assembler", "rv32asm.py"))

# --------------------------------------------------------------------------
# Types
# --------------------------------------------------------------------------
INT = {"k": "int"}
CHAR = {"k": "char"}
VOID = {"k": "void"}


def PTR(to):
    return {"k": "ptr", "to": to}


def ARR(to, n):
    return {"k": "arr", "to": to, "n": n}


def tsize(t):
    if t is None:
        return 4
    k = t["k"]
    if k in ("int", "ptr"):
        return 4
    if k == "char":
        return 1
    if k == "arr":
        return tsize(t["to"]) * t["n"]
    if k == "void":
        return 1
    return 4


def is_scalar(t):
    return t and t["k"] in ("int", "char", "ptr")


class CError(Exception):
    pass


# --------------------------------------------------------------------------
# Preprocessor (comments, #define object macros, #include "file")
# --------------------------------------------------------------------------
def preprocess(text, base_dir, macros=None, depth=0):
    if macros is None:
        macros = {}
    if depth > 16:
        raise CError("#include nested too deeply")
    # strip block comments
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    out = []
    for line in text.split("\n"):
        # strip line comments
        line = re.sub(r"//.*$", "", line)
        s = line.strip()
        m = re.match(r'#\s*include\s*"([^"]+)"', s)
        if m:
            path = os.path.join(base_dir, m.group(1))
            with open(path) as f:
                inc = f.read()
            out.append(preprocess(inc, os.path.dirname(path), macros, depth + 1))
            continue
        m = re.match(r"#\s*define\s+([A-Za-z_]\w*)\s+(.+?)\s*$", s)
        if m:
            macros[m.group(1)] = m.group(2)
            continue
        if s.startswith("#"):
            continue  # ignore other directives
        out.append(line)
    return "\n".join(out), macros


# --------------------------------------------------------------------------
# Lexer
# --------------------------------------------------------------------------
KEYWORDS = {"int", "char", "void", "if", "else", "while", "for", "return",
            "break", "continue", "sizeof"}
PUNCT3 = []
PUNCT2 = ["<<=", ">>=", "->"]
PUNCT2b = ["==", "!=", "<=", ">=", "&&", "||", "<<", ">>", "+=", "-=", "*=",
           "/=", "%=", "++", "--"]
PUNCT1 = list("+-*/%=&|!<>~(){}[];,?:.")


class Tok:
    def __init__(self, kind, val, line):
        self.kind = kind   # 'id','num','str','char','op','kw','eof'
        self.val = val
        self.line = line

    def __repr__(self):
        return f"Tok({self.kind},{self.val!r})"


class Lexer:
    def __init__(self, src, macros):
        self.s = src
        self.i = 0
        self.line = 1
        self.macros = macros
        self.toks = []
        self.tokenize()
        self.p = 0

    def tokenize(self):
        s = self.s
        n = len(s)
        i = 0
        line = 1
        while i < n:
            c = s[i]
            if c == "\n":
                line += 1; i += 1; continue
            if c in " \t\r":
                i += 1; continue
            # identifier / keyword / macro
            m = re.match(r"[A-Za-z_]\w*", s[i:])
            if m:
                word = m.group(0)
                if word in self.macros:
                    # splice macro replacement tokens (drop the sub-lexer's eof)
                    sub = Lexer(self.macros[word], {})
                    for t in sub.toks:
                        if t.kind != "eof":
                            t.line = line
                            self.toks.append(t)
                    i += len(word); continue
                kind = "kw" if word in KEYWORDS else "id"
                self.toks.append(Tok(kind, word, line))
                i += len(word); continue
            # number
            m = re.match(r"0[xX][0-9a-fA-F]+|\d+", s[i:])
            if m:
                self.toks.append(Tok("num", int(m.group(0), 0), line))
                i += len(m.group(0)); continue
            # char literal
            m = re.match(r"'(\\.|[^'\\])'", s[i:])
            if m:
                self.toks.append(Tok("num", char_value(m.group(1)), line))
                i += len(m.group(0)); continue
            # string literal
            m = re.match(r'"(\\.|[^"\\])*"', s[i:])
            if m:
                raw = m.group(0)[1:-1]
                self.toks.append(Tok("str", decode_c_string(raw), line))
                i += len(m.group(0)); continue
            # operators / punctuation
            matched = None
            for p in PUNCT2 + PUNCT2b:
                if s.startswith(p, i):
                    matched = p; break
            if matched is None:
                for p in PUNCT1:
                    if s.startswith(p, i):
                        matched = p; break
            if matched is None:
                raise CError(f"line {line}: unexpected char {c!r}")
            self.toks.append(Tok("op", matched, line))
            i += len(matched)
        self.toks.append(Tok("eof", None, line))

    # token cursor helpers
    def peek(self, k=0):
        return self.toks[self.p + k]

    def next(self):
        t = self.toks[self.p]; self.p += 1; return t

    def accept(self, val):
        t = self.peek()
        if (t.kind in ("op", "kw")) and t.val == val:
            self.p += 1; return True
        return False

    def expect(self, val):
        if not self.accept(val):
            t = self.peek()
            raise CError(f"line {t.line}: expected '{val}' got {t.val!r}")


def char_value(body):
    if body.startswith("\\"):
        return {"n": 10, "r": 13, "t": 9, "0": 0, "\\": 92, "'": 39, '"': 34} \
            .get(body[1], ord(body[1]))
    return ord(body)


def decode_c_string(raw):
    out = []
    i = 0
    while i < len(raw):
        if raw[i] == "\\" and i + 1 < len(raw):
            c = raw[i + 1]
            if c == "x":
                out.append(int(raw[i + 2:i + 4], 16)); i += 4; continue
            out.append(char_value("\\" + c)); i += 2; continue
        out.append(ord(raw[i])); i += 1
    return out


# --------------------------------------------------------------------------
# Parser -> AST (tuples)
#   decl:    ('decl', ty, [(name, arrsize|None, initexpr|None), ...])
#   func:    ('func', retty, name, [(pty,pname),...], body)
#   stmts:   ('block',[..]) ('if',c,t,e) ('while',c,b) ('for',i,c,inc,b)
#            ('return',e|None) ('break',) ('continue',) ('expr',e) ('decl',..)
#   exprs:   ('num',v) ('str',bytes) ('var',name) ('bin',op,l,r) ('un',op,e)
#            ('assign',op,lval,rval) ('call',name,[args]) ('deref',e)
#            ('addr',e) ('index',a,i) ('cast',ty,e) ('sizeof',ty)
# --------------------------------------------------------------------------
class Parser:
    def __init__(self, lexer):
        self.lx = lexer
        self.funcs = []
        self.globals = []   # (ty, name, arrsize, init)

    def parse(self):
        while self.lx.peek().kind != "eof":
            self.top_level()
        return self.funcs, self.globals

    def top_level(self):
        ty = self.parse_type()
        name = self.parse_ident()
        if self.lx.peek().val == "(":
            # function definition
            self.lx.expect("(")
            params = []
            if self.lx.accept(")"):
                pass
            elif self.lx.peek().val == "void" and self.lx.peek(1).val == ")":
                self.lx.next(); self.lx.expect(")")   # (void) == no params
            else:
                while True:
                    pty = self.parse_type()
                    pname = self.parse_ident()
                    params.append((pty, pname))
                    if not self.lx.accept(","):
                        break
                self.lx.expect(")")
            body = self.parse_block()
            self.funcs.append(("func", ty, name, params, body))
        else:
            # global variable(s)
            self.global_declarators(ty, name)

    def global_declarators(self, ty, firstname):
        decls = []
        name = firstname
        arrsize = None
        init = None
        if self.lx.accept("["):
            arrsize = self.lx.next().val
            self.lx.expect("]")
        if self.lx.accept("="):
            init = self.parse_initializer()
        decls.append((name, arrsize, init))
        while self.lx.accept(","):
            name = self.parse_ident()
            arrsize = None; init = None
            if self.lx.accept("["):
                arrsize = self.lx.next().val; self.lx.expect("]")
            if self.lx.accept("="):
                init = self.parse_initializer()
            decls.append((name, arrsize, init))
        self.lx.expect(";")
        for (nm, asz, ini) in decls:
            t = ARR(ty, asz) if asz is not None else ty
            self.globals.append((t, nm, asz, ini))

    def parse_initializer(self):
        if self.lx.accept("{"):
            vals = []
            if not self.lx.accept("}"):
                while True:
                    vals.append(self.parse_expr())
                    if not self.lx.accept(","):
                        break
                self.lx.expect("}")
            return ("initlist", vals)
        return self.parse_expr()

    def parse_type(self):
        t = self.lx.next()
        if t.val not in ("int", "char", "void"):
            raise CError(f"line {t.line}: expected type, got {t.val!r}")
        ty = {"int": INT, "char": CHAR, "void": VOID}[t.val]
        while self.lx.peek().val == "*":
            self.lx.next(); ty = PTR(ty)
        return ty

    def parse_ident(self):
        t = self.lx.next()
        if t.kind != "id":
            raise CError(f"line {t.line}: expected identifier, got {t.val!r}")
        return t.val

    def parse_block(self):
        self.lx.expect("{")
        stmts = []
        while not self.lx.accept("}"):
            stmts.append(self.parse_stmt())
        return ("block", stmts)

    def is_type_start(self):
        return self.lx.peek().val in ("int", "char", "void")

    def parse_stmt(self):
        lx = self.lx
        tk = lx.peek()
        if tk.val == "{":
            return self.parse_block()
        if tk.val == ";":
            lx.next(); return ("expr", None)
        if tk.kind == "kw" and tk.val == "if":
            lx.next(); lx.expect("(")
            c = self.parse_expr(); lx.expect(")")
            then = self.parse_stmt()
            els = None
            if lx.accept("else"):
                els = self.parse_stmt()
            return ("if", c, then, els)
        if tk.kind == "kw" and tk.val == "while":
            lx.next(); lx.expect("(")
            c = self.parse_expr(); lx.expect(")")
            b = self.parse_stmt()
            return ("while", c, b)
        if tk.kind == "kw" and tk.val == "for":
            lx.next(); lx.expect("(")
            init = None
            if not lx.accept(";"):
                if self.is_type_start():
                    init = self.parse_local_decl()
                else:
                    init = ("expr", self.parse_expr()); lx.expect(";")
            cond = None if lx.peek().val == ";" else self.parse_expr()
            lx.expect(";")
            inc = None if lx.peek().val == ")" else self.parse_expr()
            lx.expect(")")
            b = self.parse_stmt()
            return ("for", init, cond, inc, b)
        if tk.kind == "kw" and tk.val == "return":
            lx.next()
            e = None if lx.peek().val == ";" else self.parse_expr()
            lx.expect(";")
            return ("return", e)
        if tk.kind == "kw" and tk.val == "break":
            lx.next(); lx.expect(";"); return ("break",)
        if tk.kind == "kw" and tk.val == "continue":
            lx.next(); lx.expect(";"); return ("continue",)
        if self.is_type_start():
            return self.parse_local_decl()
        e = self.parse_expr(); lx.expect(";")
        return ("expr", e)

    def parse_local_decl(self):
        ty = self.parse_type()
        decls = []
        while True:
            name = self.parse_ident()
            arrsize = None; init = None
            if self.lx.accept("["):
                arrsize = self.lx.next().val; self.lx.expect("]")
            if self.lx.accept("="):
                init = self.parse_initializer()
            t = ARR(ty, arrsize) if arrsize is not None else ty
            decls.append((name, t, arrsize, init))
            if not self.lx.accept(","):
                break
        self.lx.expect(";")
        return ("decl", decls)

    # ---- expressions (precedence climbing) ----
    BINLEVELS = [
        (["||"], "L"),
        (["&&"], "L"),
        (["|"], "L"),
        (["^"], "L"),
        (["&"], "L"),
        (["==", "!="], "L"),
        (["<", ">", "<=", ">="], "L"),
        (["<<", ">>"], "L"),
        (["+", "-"], "L"),
        (["*", "/", "%"], "L"),
    ]

    def parse_expr(self):
        return self.parse_assign()

    def parse_assign(self):
        left = self.parse_bin(0)
        tk = self.lx.peek()
        if tk.kind == "op" and tk.val in ("=", "+=", "-=", "*=", "/=", "%="):
            self.lx.next()
            right = self.parse_assign()
            return ("assign", tk.val, left, right)
        return left

    def parse_bin(self, level):
        if level >= len(self.BINLEVELS):
            return self.parse_unary()
        ops, _ = self.BINLEVELS[level]
        node = self.parse_bin(level + 1)
        while self.lx.peek().kind == "op" and self.lx.peek().val in ops:
            op = self.lx.next().val
            rhs = self.parse_bin(level + 1)
            node = ("bin", op, node, rhs)
        return node

    def parse_unary(self):
        tk = self.lx.peek()
        if tk.kind == "op" and tk.val in ("-", "!", "~", "*", "&"):
            self.lx.next()
            e = self.parse_unary()
            return ("un", tk.val, e)
        if tk.kind == "op" and tk.val == "++":
            self.lx.next(); e = self.parse_unary()
            return ("preinc", e, 1)
        if tk.kind == "op" and tk.val == "--":
            self.lx.next(); e = self.parse_unary()
            return ("preinc", e, -1)
        if tk.kind == "kw" and tk.val == "sizeof":
            self.lx.next()
            if self.lx.accept("("):
                ty = self.parse_type(); self.lx.expect(")")
                return ("num", tsize(ty))
            e = self.parse_unary()
            return ("sizeofexpr", e)
        if tk.kind == "op" and tk.val == "(":
            # cast or parenthesized expr
            save = self.lx.p
            self.lx.next()
            if self.is_type_start():
                ty = self.parse_type()
                # allow '*' already consumed in parse_type
                self.lx.expect(")")
                e = self.parse_unary()
                return ("cast", ty, e)
            self.lx.p = save
        return self.parse_postfix()

    def parse_postfix(self):
        node = self.parse_primary()
        while True:
            tk = self.lx.peek()
            if tk.kind == "op" and tk.val == "(":
                self.lx.next()
                args = []
                if not self.lx.accept(")"):
                    while True:
                        args.append(self.parse_expr())
                        if not self.lx.accept(","):
                            break
                    self.lx.expect(")")
                # node must be ('var',name)
                if node[0] != "var":
                    raise CError("only direct function calls supported")
                node = ("call", node[1], args)
            elif tk.kind == "op" and tk.val == "[":
                self.lx.next()
                idx = self.parse_expr(); self.lx.expect("]")
                node = ("index", node, idx)
            elif tk.kind == "op" and tk.val == "++":
                self.lx.next(); node = ("postinc", node, 1)
            elif tk.kind == "op" and tk.val == "--":
                self.lx.next(); node = ("postinc", node, -1)
            else:
                break
        return node

    def parse_primary(self):
        tk = self.lx.next()
        if tk.kind == "num":
            return ("num", tk.val)
        if tk.kind == "str":
            return ("str", tk.val)
        if tk.kind == "id":
            return ("var", tk.val)
        if tk.kind == "op" and tk.val == "(":
            e = self.parse_expr(); self.lx.expect(")"); return e
        raise CError(f"line {tk.line}: unexpected token {tk.val!r}")


# --------------------------------------------------------------------------
# Code generator
# --------------------------------------------------------------------------
class CodeGen:
    def __init__(self, funcs, globals_):
        self.out = []
        self.funcs = {f[2]: f for f in funcs}
        self.func_order = [f[2] for f in funcs]
        self.globals = {}      # name -> type
        self.global_init = []  # (name, type, arrsize, init)
        for (t, nm, asz, ini) in globals_:
            self.globals[nm] = t
            self.global_init.append((nm, t, asz, ini))
        self.strings = []      # list of byte-lists
        self.lbl = 0
        self.INTRINSICS = {"hartid", "amoswap", "amoadd", "membar"}

    # ---- helpers ----
    def emit(self, s):
        self.out.append("    " + s)

    def push(self, reg="a0"):
        self.emit("addi sp, sp, -4")
        self.emit(f"sw {reg}, 0(sp)")

    def pop(self, reg="a0"):
        self.emit(f"lw {reg}, 0(sp)")
        self.emit("addi sp, sp, 4")

    def label(self, prefix="L"):
        self.lbl += 1
        return f"_{prefix}{self.lbl}"

    def new_str(self, bytes_):
        self.strings.append(bytes_)
        return len(self.strings) - 1

    def lookup(self, name, locals_):
        if name in locals_:
            return ("local", locals_[name])
        if name in self.globals:
            return ("global", self.globals[name])
        raise CError(f"undeclared identifier '{name}'")

    # ---- top level ----
    def generate(self):
        self.emit(".equ __stack_top, 0x8001FF00")
        self.emit(".equ __tohost,   0x8001FFF0")
        self.emit(".text")
        self.emit(".globl _start")
        self.emit("_start:")
        self.startup()
        for name in self.func_order:
            self.gen_func(self.funcs[name])
        # data
        self.emit(".data")
        for (nm, t, asz, ini) in self.global_init:
            self.emit(f"{nm}:")
            self.emit_global_data(t, asz, ini)
        for k, bs in enumerate(self.strings):
            self.emit(f"_LS{k}:")
            self.emit(".byte " + ", ".join(str(b) for b in bs) + ", 0")
        return "\n".join(self.out) + "\n"

    def startup(self):
        # per-hart stack; call main; hart 0 reports the result to `tohost`
        self.emit("csrr t0, mhartid")
        self.emit("li   t1, 4096")
        self.emit("mul  t2, t0, t1")
        self.emit("la   sp, __stack_top")
        self.emit("sub  sp, sp, t2")
        self.emit("jal  ra, main")
        self.emit("csrr t0, mhartid")
        self.emit("bnez t0, __park")
        self.emit("la   t1, __tohost")
        self.emit("beqz a0, __ok")
        self.emit("li   t2, 0xBAD00000")
        self.emit("or   a0, a0, t2")
        self.emit("sw   a0, 0(t1)")
        self.emit("j    __park")
        self.emit("__ok:")
        self.emit("li   t2, 0x600D600D")
        self.emit("sw   t2, 0(t1)")
        self.emit("__park:")
        self.emit("j    __park")

    def emit_global_data(self, t, asz, ini):
        if t["k"] == "arr":
            esz = tsize(t["to"])
            vals = [0] * t["n"]
            if ini and ini[0] == "initlist":
                for i, e in enumerate(ini[1][:t["n"]]):
                    vals[i] = const_value(e)
            elif ini is not None:
                vals[0] = const_value(ini)
            for v in vals:
                if esz == 1:
                    self.emit(f".byte {v & 0xFF}")
                else:
                    self.emit(f".word {v & 0xFFFFFFFF}")
        else:
            v = const_value(ini) if ini is not None else 0
            if t["k"] == "char":
                self.emit(f".byte {v & 0xFF}")
            else:
                self.emit(f".word {v & 0xFFFFFFFF}")

    # ---- functions ----
    def gen_func(self, f):
        _, retty, name, params, body = f
        locals_ = {}
        # params at s0 + 4*i
        off = 0
        for (pty, pname) in params:
            locals_[pname] = {"type": pty, "off": off, "kind": "param"}
            off += 4
        # collect locals (function-scoped), assign negative offsets
        frame = self.collect_locals(body, locals_)
        self.emit(f"{name}:")
        self.emit("addi sp, sp, -8")
        self.emit("sw   ra, 4(sp)")
        self.emit("sw   s0, 0(sp)")
        self.emit("addi s0, sp, 8")
        if frame:
            self.emit(f"addi sp, sp, -{frame}")
        self.ret_label = self.label("ret")
        self.loop_stack = []
        self.gen_stmt(body, locals_, retty)
        self.emit(f"{self.ret_label}:")
        self.emit("addi sp, s0, -8")
        self.emit("lw   ra, 4(sp)")
        self.emit("lw   s0, 0(sp)")
        self.emit("addi sp, sp, 8")
        self.emit("ret")

    def collect_locals(self, node, locals_):
        """Walk the function body assigning fp-relative slots to every local
        (function-scoped). Returns the total frame size (16-byte aligned)."""
        size = [0]

        def walk(n):
            if not isinstance(n, tuple):
                return
            tag = n[0]
            if tag == "decl":
                for (nm, t, asz, ini) in n[1]:
                    size[0] += (tsize(t) + 3) & ~3
                    locals_[nm] = {"type": t, "off": -8 - size[0],
                                   "kind": "local", "size": tsize(t)}
            elif tag == "block":
                for s in n[1]:
                    walk(s)
            elif tag == "if":
                walk(n[2])
                if n[3]:
                    walk(n[3])
            elif tag == "while":
                walk(n[2])
            elif tag == "for":
                if n[1]:
                    walk(n[1])
                walk(n[4])
        walk(node)
        return (size[0] + 15) & ~15

    # ---- statements ----
    def gen_stmt(self, n, locals_, retty):
        tag = n[0]
        if tag == "block":
            for s in n[1]:
                self.gen_stmt(s, locals_, retty)
        elif tag == "expr":
            if n[1] is not None:
                self.gen(n[1], locals_)
        elif tag == "decl":
            for (nm, t, asz, ini) in n[1]:
                if ini is not None:
                    if t["k"] == "arr" and ini[0] == "initlist":
                        base = locals_[nm]["off"]
                        esz = tsize(t["to"])
                        for i, e in enumerate(ini[1][:t["n"]]):
                            self.gen(e, locals_)
                            self.emit("addi t0, s0, %d" % (base + i * esz))
                            self.emit_store(t["to"], "a0", "t0")
                    else:
                        self.gen(ini, locals_)
                        info = locals_[nm]
                        self.emit("addi t0, s0, %d" % info["off"])
                        self.emit_store(t, "a0", "t0")
        elif tag == "if":
            lelse = self.label("else"); lend = self.label("end")
            self.gen(n[1], locals_)
            self.emit(f"beqz a0, {lelse}")
            self.gen_stmt(n[2], locals_, retty)
            if n[3]:
                self.emit(f"j {lend}")
                self.emit(f"{lelse}:")
                self.gen_stmt(n[3], locals_, retty)
                self.emit(f"{lend}:")
            else:
                self.emit(f"{lelse}:")
        elif tag == "while":
            ltop = self.label("top"); lend = self.label("end")
            self.loop_stack.append((lend, ltop))
            self.emit(f"{ltop}:")
            if n[1] is not None:
                self.gen(n[1], locals_)
                self.emit(f"beqz a0, {lend}")
            self.gen_stmt(n[2], locals_, retty)
            self.emit(f"j {ltop}")
            self.emit(f"{lend}:")
            self.loop_stack.pop()
        elif tag == "for":
            ltop = self.label("top"); lend = self.label("end")
            lcont = self.label("cont")
            if n[1]:
                self.gen_stmt(n[1], locals_, retty)
            self.loop_stack.append((lend, lcont))
            self.emit(f"{ltop}:")
            if n[2] is not None:
                self.gen(n[2], locals_)
                self.emit(f"beqz a0, {lend}")
            self.gen_stmt(n[4], locals_, retty)
            self.emit(f"{lcont}:")
            if n[3]:
                self.gen(n[3], locals_)
            self.emit(f"j {ltop}")
            self.emit(f"{lend}:")
            self.loop_stack.pop()
        elif tag == "return":
            if n[1] is not None:
                self.gen(n[1], locals_)
            self.emit(f"j {self.ret_label}")
        elif tag == "break":
            if not self.loop_stack:
                raise CError("break outside loop")
            self.emit(f"j {self.loop_stack[-1][0]}")
        elif tag == "continue":
            if not self.loop_stack:
                raise CError("continue outside loop")
            self.emit(f"j {self.loop_stack[-1][1]}")
        else:
            raise CError(f"unknown statement {tag}")

    # ---- load/store width helpers ----
    def emit_load(self, t, dst, base):
        if t and t["k"] == "char":
            self.emit(f"lbu {dst}, 0({base})")
        else:
            self.emit(f"lw {dst}, 0({base})")

    def emit_load_off(self, t, dst, base, off):
        if t and t["k"] == "char":
            self.emit(f"lbu {dst}, {off}({base})")
        else:
            self.emit(f"lw {dst}, {off}({base})")

    def emit_store(self, t, src, base):
        if t and t["k"] == "char":
            self.emit(f"sb {src}, 0({base})")
        else:
            self.emit(f"sw {src}, 0({base})")

    def emit_store_off(self, t, src, base, off):
        if t and t["k"] == "char":
            self.emit(f"sb {src}, {off}({base})")
        else:
            self.emit(f"sw {src}, {off}({base})")

    # ---- expressions: gen returns type, value left in a0 ----
    def gen(self, n, locals_):
        tag = n[0]
        if tag == "num":
            self.emit(f"li a0, {n[1] & 0xFFFFFFFF if n[1] >= 0 else n[1]}")
            return INT
        if tag == "str":
            k = self.new_str(n[1])
            self.emit(f"la a0, _LS{k}")
            return PTR(CHAR)
        if tag == "var":
            return self.gen_var(n[1], locals_)
        if tag == "bin":
            return self.gen_bin(n[1], n[2], n[3], locals_)
        if tag == "un":
            return self.gen_un(n[1], n[2], locals_)
        if tag == "assign":
            return self.gen_assign(n[1], n[2], n[3], locals_)
        if tag == "call":
            return self.gen_call(n[1], n[2], locals_)
        if tag == "deref":
            t = self.gen(n[1], locals_)        # address in a0
            pt = t["to"] if t and t["k"] == "ptr" else INT
            self.emit_load(pt, "a0", "a0")
            return pt
        if tag == "index":
            return self.gen_index(n[1], n[2], locals_)
        if tag == "addr":
            self.gen_addr(n[1], locals_)
            ty = self.expr_type(n[1], locals_)
            return PTR(ty)
        if tag == "cast":
            self.gen(n[2], locals_)
            self.coerce(n[2] and self.expr_type(n[2], locals_), n[1])
            return n[1]
        if tag == "sizeofexpr":
            t = self.expr_type(n[1], locals_)
            self.emit(f"li a0, {tsize(t)}")
            return INT
        if tag == "preinc":
            return self.gen_incdec(n[1], n[2], locals_, pre=True)
        if tag == "postinc":
            return self.gen_incdec(n[1], n[2], locals_, pre=False)
        raise CError(f"codegen: unknown expr {tag}")

    def coerce(self, fromty, toty):
        # truncate/sign-extend when converting to char; else no-op
        if toty and toty["k"] == "char":
            self.emit("slli a0, a0, 24")
            self.emit("srli a0, a0, 24")   # char treated as unsigned byte value

    def gen_var(self, name, locals_):
        kind, info = self.lookup(name, locals_)
        t = info["type"] if kind == "local" else info
        if kind == "local":
            if t["k"] == "arr":
                self.emit("addi a0, s0, %d" % info["off"])
                return PTR(t["to"])
            self.emit_load_off(t, "a0", "s0", info["off"])
            return t
        else:
            if t["k"] == "arr":
                self.emit(f"la a0, {name}")
                return PTR(t["to"])
            self.emit(f"la a1, {name}")
            self.emit_load(t, "a0", "a1")
            return t

    def gen_index(self, a, i, locals_):
        at = self.gen(a, locals_)             # base address in a0 (array/ptr)
        base_type = at["to"] if at and at["k"] == "ptr" else INT
        self.emit("mv t2, a0")                # t2 = base
        self.gen(i, locals_)                  # a0 = index
        esz = tsize(base_type)
        if esz != 1:
            self.emit(f"li t3, {esz}")
            self.emit("mul a0, a0, t3")
        self.emit("add a0, t2, a0")           # a0 = element address
        self.emit_load(base_type, "a0", "a0")
        return base_type

    def gen_un(self, op, e, locals_):
        if op == "&":
            self.gen_addr(e, locals_)
            return PTR(self.expr_type(e, locals_))
        if op == "*":
            t = self.gen(e, locals_)
            pt = t["to"] if t and t["k"] == "ptr" else INT
            self.emit_load(pt, "a0", "a0")
            return pt
        t = self.gen(e, locals_)
        if op == "-":
            self.emit("neg a0, a0")
        elif op == "!":
            self.emit("seqz a0, a0")
        elif op == "~":
            self.emit("not a0, a0")
        elif op == "+":
            pass
        return INT

    def gen_bin(self, op, l, r, locals_):
        if op == "&&":
            lf = self.label("and0"); le = self.label("andE")
            self.gen(l, locals_); self.emit(f"beqz a0, {lf}")
            self.gen(r, locals_); self.emit(f"beqz a0, {lf}")
            self.emit("li a0, 1"); self.emit(f"j {le}")
            self.emit(f"{lf}:"); self.emit("li a0, 0"); self.emit(f"{le}:")
            return INT
        if op == "||":
            lt = self.label("or1"); le = self.label("orE")
            self.gen(l, locals_); self.emit(f"bnez a0, {lt}")
            self.gen(r, locals_); self.emit(f"bnez a0, {lt}")
            self.emit("li a0, 0"); self.emit(f"j {le}")
            self.emit(f"{lt}:"); self.emit("li a0, 1"); self.emit(f"{le}:")
            return INT
        # pointer arithmetic
        lt = self.expr_type(l, locals_)
        rt = self.expr_type(r, locals_)
        self.gen(l, locals_)
        self.push()                         # save left across gen(r)
        self.gen(r, locals_)
        self.emit("mv t1, a0")              # t1 = right
        self.pop()                          # a0 = left
        self.emit("mv t0, a0")              # t0 = left
        if op in ("+", "-") and lt and lt["k"] == "ptr":
            esz = tsize(lt["to"])
            if esz != 1:
                self.emit(f"li t3, {esz}")
                self.emit("mul t1, t1, t3")
            self.emit(("add a0, t0, t1") if op == "+" else ("sub a0, t0, t1"))
            return lt
        if op == "-" and lt and lt["k"] == "ptr" and rt and rt["k"] == "ptr":
            self.emit("sub a0, t0, t1")
            esz = tsize(lt["to"])
            if esz != 1:
                self.emit(f"li t3, {esz}"); self.emit("div a0, a0, t3")
            return INT
        # scalar arithmetic / logic
        if op == "+":
            self.emit("add a0, t0, t1")
        elif op == "-":
            self.emit("sub a0, t0, t1")
        elif op == "*":
            self.emit("mul a0, t0, t1")
        elif op == "/":
            self.emit("div a0, t0, t1")
        elif op == "%":
            self.emit("rem a0, t0, t1")
        elif op == "&":
            self.emit("and a0, t0, t1")
        elif op == "|":
            self.emit("or a0, t0, t1")
        elif op == "^":
            self.emit("xor a0, t0, t1")
        elif op == "<<":
            self.emit("sll a0, t0, t1")
        elif op == ">>":
            self.emit("sra a0, t0, t1")
        elif op == "==":
            self.emit("sub a0, t0, t1"); self.emit("seqz a0, a0")
        elif op == "!=":
            self.emit("sub a0, t0, t1"); self.emit("snez a0, a0")
        elif op == "<":
            self.emit("mv a0, t0"); self.emit("slt a0, a0, t1")
        elif op == ">":
            self.emit("slt a0, t1, t0")
        elif op == "<=":
            self.emit("slt a0, t1, t0"); self.emit("xori a0, a0, 1")
        elif op == ">=":
            self.emit("slt a0, t0, t1"); self.emit("xori a0, a0, 1")
        else:
            raise CError(f"bad binary op {op}")
        return INT

    def gen_incdec(self, target, delta, locals_, pre):
        # only for int/char scalar lvalues
        t = self.expr_type(target, locals_)
        step = delta
        self.gen_addr(target, locals_)       # a0 = address
        self.emit("mv t0, a0")
        self.emit_load(t, "t1", "t0")        # t1 = old value
        self.emit(f"li t2, {step}")
        self.emit("add t2, t1, t2")          # t2 = new value
        self.emit_store(t, "t2", "t0")
        if pre:
            self.emit("mv a0, t2")
        else:
            self.emit("mv a0, t1")
        return t

    def gen_assign(self, op, lval, rval, locals_):
        t = self.expr_type(lval, locals_)
        if op != "=":
            base = {"+=": "add", "-=": "sub", "*=": "mul", "/=": "div", "%=": "rem"}[op]
            self.gen_addr(lval, locals_)    # a0 = address
            self.push()                     # save address
            self.emit_load(t, "a0", "a0")   # a0 = old value
            self.push()                     # save old
            self.gen(rval, locals_)
            self.emit("mv t2, a0")          # t2 = rval
            self.pop("t1")                  # t1 = old
            self.pop("t0")                  # t0 = address
            self.emit(f"{base} a0, t1, t2") # a0 = old OP rval
            self.emit_store(t, "a0", "t0")
            return t
        # simple assignment
        self.gen(rval, locals_)
        self.push()                         # save value
        self.gen_addr(lval, locals_)        # a0 = address
        self.emit("mv t0, a0")
        self.pop()                          # a0 = value (also the result)
        self.emit_store(t, "a0", "t0")
        return t

    def gen_addr(self, n, locals_):
        """Emit the address of an lvalue into a0."""
        tag = n[0]
        if tag == "var":
            kind, info = self.lookup(n[1], locals_)
            if kind == "local":
                self.emit("addi a0, s0, %d" % info["off"])
            else:
                self.emit(f"la a0, {n[1]}")
            return
        if tag == "deref":
            self.gen(n[1], locals_)          # address already
            return
        if tag == "un" and n[1] == "*":
            self.gen(n[2], locals_)          # *p : address = value of p
            return
        if tag == "index":
            at = self.gen(n[1], locals_)
            base_type = at["to"] if at and at["k"] == "ptr" else INT
            self.emit("mv t2, a0")
            self.gen(n[2], locals_)
            esz = tsize(base_type)
            if esz != 1:
                self.emit(f"li t3, {esz}"); self.emit("mul a0, a0, t3")
            self.emit("add a0, t2, a0")
            return
        raise CError("invalid lvalue")

    def gen_call(self, name, args, locals_):
        # intrinsics
        if name == "hartid":
            self.emit("csrr a0, mhartid"); return INT
        if name == "membar":
            self.emit("nop"); return VOID
        if name in ("amoswap", "amoadd"):
            # args: (ptr, val) -> a0 = old.
            # Value into t1 first, then address into t0 immediately before the
            # AMO so the address is forwarded from EX/MEM (an ALU result), which
            # is robust under bus stalls. args[0] (address-of) never touches t1.
            self.gen(args[1], locals_); self.emit("mv t1, a0")   # t1 = val
            self.gen(args[0], locals_); self.emit("mv t0, a0")   # t0 = addr
            op = "amoswap.w" if name == "amoswap" else "amoadd.w"
            self.emit(f"{op} a0, t1, (t0)")
            return INT
        if name not in self.funcs:
            raise CError(f"call to undefined function '{name}'")
        f = self.funcs[name]
        retty = f[1]
        # push args right-to-left
        for a in reversed(args):
            self.gen(a, locals_)
            self.emit("addi sp, sp, -4")
            self.emit("sw a0, 0(sp)")
        self.emit(f"jal ra, {name}")
        if args:
            self.emit(f"addi sp, sp, {4*len(args)}")
        return retty

    # ---- type inference (no codegen) ----
    def expr_type(self, n, locals_):
        if not isinstance(n, tuple):
            return INT
        tag = n[0]
        if tag == "num":
            return INT
        if tag == "str":
            return PTR(CHAR)
        if tag == "var":
            kind, info = self.lookup(n[1], locals_)
            t = info["type"] if kind == "local" else info
            return PTR(t["to"]) if t["k"] == "arr" else t
        if tag in ("deref", "un") and tag == "deref":
            t = self.expr_type(n[1], locals_)
            return t["to"] if t and t["k"] == "ptr" else INT
        if tag == "un":
            if n[1] == "*":
                t = self.expr_type(n[2], locals_)
                return t["to"] if t and t["k"] == "ptr" else INT
            if n[1] == "&":
                return PTR(self.expr_type(n[2], locals_))
            return INT
        if tag == "index":
            t = self.expr_type(n[1], locals_)
            return t["to"] if t and t["k"] == "ptr" else INT
        if tag == "bin":
            if n[1] in ("+", "-") :
                lt = self.expr_type(n[2], locals_)
                if lt and lt["k"] == "ptr":
                    return lt
            if n[1] in ("==", "!=", "<", ">", "<=", ">=", "&&", "||"):
                return INT
            lt = self.expr_type(n[2], locals_)
            rt = self.expr_type(n[3], locals_)
            return lt if lt and lt["k"] == "ptr" else rt
        if tag == "assign":
            return self.expr_type(n[2], locals_)
        if tag == "cast":
            return n[1]
        if tag == "call":
            if n[1] in self.INTRINSICS:
                return VOID if n[1] == "membar" else INT
            if n[1] in self.funcs:
                return self.funcs[n[1]][1]
            return INT
        if tag in ("preinc", "postinc"):
            return self.expr_type(n[1], locals_)
        if tag == "sizeofexpr":
            return INT
        return INT


def const_value(e):
    """Evaluate a constant expression (for global initializers)."""
    if e is None:
        return 0
    if isinstance(e, tuple):
        if e[0] == "num":
            return e[1]
        if e[0] == "un" and e[1] == "-":
            return -const_value(e[2])
        if e[0] == "bin":
            a = const_value(e[2]); b = const_value(e[3])
            return {"+": a + b, "-": a - b, "*": a * b,
                    "<<": a << b, ">>": a >> b, "&": a & b,
                    "|": a | b, "^": a ^ b}[e[1]]
    raise CError("global initializer must be a constant expression")


# --------------------------------------------------------------------------
# Driver
# --------------------------------------------------------------------------
def compile_c(src_text, base_dir):
    text, macros = preprocess(src_text, base_dir)
    lx = Lexer(text, macros)
    p = Parser(lx)
    funcs, globals_ = p.parse()
    cg = CodeGen(funcs, globals_)
    return cg.generate()


def main():
    ap = argparse.ArgumentParser(description="rvcc - rudimentary C compiler for the RV32 SoC")
    ap.add_argument("src")
    ap.add_argument("-o", "--out", default=None, help="assembly output (.S)")
    ap.add_argument("--rom", default=None, help="also assemble -> ROM hex")
    ap.add_argument("--ram", default=None, help="also assemble -> RAM hex")
    ap.add_argument("--keep-asm", action="store_true")
    args = ap.parse_args()

    base_dir = os.path.dirname(os.path.abspath(args.src))
    with open(args.src) as f:
        src = f.read()
    try:
        asm_text = compile_c(src, base_dir)
    except CError as e:
        sys.exit(f"rvcc: {e}")

    outS = args.out or (os.path.splitext(args.src)[0] + ".S")
    with open(outS, "w") as f:
        f.write(asm_text)

    if args.rom:
        import subprocess
        cmd = [sys.executable, ASM, outS, "-o", args.rom]
        if args.ram:
            cmd += ["--ram", args.ram]
        r = subprocess.run(cmd, capture_output=True, text=True)
        sys.stderr.write(r.stdout)
        if r.returncode != 0:
            sys.stderr.write(r.stderr)
            sys.exit("rvcc: assembly failed")
        if not args.keep_asm:
            os.remove(outS)
    print(f"rvcc: {args.src} -> {outS}" + (f" (+ {args.rom})" if args.rom else ""))


if __name__ == "__main__":
    main()
