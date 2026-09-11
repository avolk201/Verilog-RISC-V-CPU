# ---------------------------------------------------------------------------
# core_test.S - RV32IMAC instruction-set smoke test (single core)
#
# Each check branches to `fail` on a mismatch, recording the test number.
# On success the program writes PASS_CODE to `tohost`; the testbench polls that
# word and reports PASS/FAIL.
# ---------------------------------------------------------------------------
    .equ tohost,   0x8001FFF0      # testbench watches this word
    .equ PASS_CODE, 0x600D600D
    .equ FAIL_BASE, 0xBAD00000

    .text
    .globl _start
_start:
    li   x7, 0                     # current test number
    # ---- 1: ADD / forwarding chain ----
    addi x7, x7, 1
    li   x1, 5
    li   x2, 7
    add  x3, x1, x2                # back-to-back producer/consumer
    li   x4, 12
    bne  x3, x4, fail

    # ---- 2: SUB ----
    addi x7, x7, 1
    sub  x3, x2, x1                # 7-5
    li   x4, 2
    bne  x3, x4, fail

    # ---- 3: LUI / AUIPC ----
    addi x7, x7, 1
    lui  x3, 0x12345
    li   x4, 0x12345000
    bne  x3, x4, fail

    # ---- 4: logic ----
    addi x7, x7, 1
    li   x1, 0xF0F0
    li   x2, 0x0FF0
    and  x3, x1, x2
    li   x4, 0x00F0
    bne  x3, x4, fail
    or   x3, x1, x2
    li   x4, 0xFFF0
    bne  x3, x4, fail
    xor  x3, x1, x2
    li   x4, 0xFF00
    bne  x3, x4, fail

    # ---- 5: shifts ----
    addi x7, x7, 1
    li   x1, 0x80000001
    srli x3, x1, 1
    li   x4, 0x40000000
    bne  x3, x4, fail
    srai x3, x1, 1
    li   x4, 0xC0000000
    bne  x3, x4, fail
    li   x2, 4
    sll  x3, x2, x2                # 4<<4 = 64
    li   x4, 64
    bne  x3, x4, fail

    # ---- 6: SLT / SLTU ----
    addi x7, x7, 1
    li   x1, -1
    li   x2, 1
    slt  x3, x1, x2                # signed: -1 < 1 => 1
    li   x4, 1
    bne  x3, x4, fail
    sltu x3, x1, x2                # unsigned: 0xFFFF.. < 1 => 0
    li   x4, 0
    bne  x3, x4, fail

    # ---- 7: M extension ----
    addi x7, x7, 1
    li   x1, 6
    li   x2, 7
    mul  x3, x1, x2
    li   x4, 42
    bne  x3, x4, fail
    li   x1, 100
    li   x2, 7
    div  x3, x1, x2
    li   x4, 14
    bne  x3, x4, fail
    rem  x3, x1, x2
    li   x4, 2
    bne  x3, x4, fail

    # ---- 8: store / load word ----
    addi x7, x7, 1
    li   x1, 0x80010100            # scratch data address
    li   x2, 0xDEADBEEF
    sw   x2, 0(x1)
    lw   x3, 0(x1)
    bne  x3, x2, fail

    # ---- 9: byte / half store-load with sign extend ----
    addi x7, x7, 1
    li   x2, 0x81
    sb   x2, 4(x1)
    lb   x3, 4(x1)                 # sign-extended => 0xFFFFFF81
    li   x4, 0xFFFFFF81
    bne  x3, x4, fail
    lbu  x3, 4(x1)                 # zero-extended => 0x81
    li   x4, 0x81
    bne  x3, x4, fail

    # ---- 10: branches ----
    addi x7, x7, 1
    li   x1, 3
    li   x2, 3
    beq  x1, x2, t10a
    j    fail
t10a:
    blt  x2, x1, fail              # not taken
    bge  x1, x2, t10b
    j    fail
t10b:

    # ---- 11: JAL / JALR (call & return) ----
    addi x7, x7, 1
    jal  x1, sub_fn                # x1 = return address
    li   x4, 9
    bne  x10, x4, fail             # sub_fn returns 9 in x10
    j    after_sub
sub_fn:
    li   x10, 9
    ret
after_sub:

    # ---- 12: CSR read (mhartid) ----
    addi x7, x7, 1
    csrr x3, mhartid
    li   x4, 0
    bne  x3, x4, fail

    # ---- 13: CSR write/read (mscratch) ----
    addi x7, x7, 1
    li   x2, 0x1234
    csrrw x3, mscratch, x2         # write, x3 = old (0)
    csrr x4, mscratch
    bne  x4, x2, fail

    # ---- 14: AMOSWAP ----
    addi x7, x7, 1
    li   x1, 0x80010200
    li   x2, 0x1111
    sw   x2, 0(x1)
    li   x3, 0x2222
    amoswap.w x4, x3, (x1)         # x4 = old, mem = 0x2222
    bne  x4, x2, fail
    lw   x5, 0(x1)
    bne  x5, x3, fail

    # ---- 15: AMOADD ----
    addi x7, x7, 1
    li   x1, 0x80010204
    li   x2, 10
    sw   x2, 0(x1)
    li   x3, 5
    amoadd.w x4, x3, (x1)          # x4 = old(10), mem = 15
    li   x5, 10
    bne  x4, x5, fail
    lw   x6, 0(x1)
    li   x5, 15
    bne  x6, x5, fail

    # ---- 16: LR / SC success ----
    addi x7, x7, 1
    li   x1, 0x80010208
    li   x2, 100
    sw   x2, 0(x1)
    lr.w x3, (x1)
    li   x4, 200
    sc.w x5, x4, (x1)              # x5 = 0 on success
    bnez x5, fail
    lw   x6, 0(x1)
    bne  x6, x4, fail

    # ---- 17: loop with backward branch ----
    addi x7, x7, 1
    li   x1, 0                     # sum
    li   x2, 5                     # counter
loop17:
    add  x1, x1, x2
    addi x2, x2, -1
    bnez x2, loop17
    li   x4, 15                    # 5+4+3+2+1
    bne  x1, x4, fail

    # ---- all passed ----
    li   x5, 0x600D600D            # PASS_CODE
    li   x1, 0x8001FFF0            # tohost
    sw   x5, 0(x1)
spin_pass:
    j    spin_pass

fail:
    li   x5, 0xBAD00000
    or   x5, x5, x7                # embed failing test number
    li   x1, 0x8001FFF0
    sw   x5, 0(x1)
spin_fail:
    j    spin_fail
