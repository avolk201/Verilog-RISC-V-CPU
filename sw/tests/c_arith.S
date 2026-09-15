    .equ __stack_top, 0x8001FF00
    .equ __tohost,   0x8001FFF0
    .text
    .globl _start
    _start:
    csrr t0, mhartid
    li   t1, 4096
    mul  t2, t0, t1
    la   sp, __stack_top
    sub  sp, sp, t2
    jal  ra, main
    csrr t0, mhartid
    bnez t0, __park
    la   t1, __tohost
    beqz a0, __ok
    li   t2, 0xBAD00000
    or   a0, a0, t2
    sw   a0, 0(t1)
    j    __park
    __ok:
    li   t2, 0x600D600D
    sw   t2, 0(t1)
    __park:
    j    __park
    fib:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    addi s0, sp, 8
    lw a0, 0(s0)
    mv t3, a0
    li a0, 2
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mv a0, t0
    slt a0, a0, t1
    beqz a0, _else2
    lw a0, 0(s0)
    j _ret1
    _else2:
    lw a0, 0(s0)
    mv t3, a0
    li a0, 1
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    addi sp, sp, -4
    sw a0, 0(sp)
    jal ra, fib
    addi sp, sp, 4
    mv t3, a0
    addi sp, sp, -4
    sw t3, 0(sp)
    lw a0, 0(s0)
    mv t4, a0
    li a0, 2
    mv t1, a0
    mv a0, t4
    mv t0, a0
    sub a0, t0, t1
    addi sp, sp, -4
    sw a0, 0(sp)
    jal ra, fib
    addi sp, sp, 4
    lw t3, 0(sp)
    addi sp, sp, 4
    mv t1, a0
    mv a0, t3
    mv t0, a0
    add a0, t0, t1
    j _ret1
    _ret1:
    addi sp, s0, -8
    lw   ra, 4(sp)
    lw   s0, 0(sp)
    addi sp, sp, 8
    ret
    gcd:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    addi s0, sp, 8
    lw a0, 4(s0)
    mv t3, a0
    li a0, 0
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    seqz a0, a0
    beqz a0, _else5
    lw a0, 0(s0)
    j _ret4
    _else5:
    lw a0, 0(s0)
    mv t3, a0
    lw a0, 4(s0)
    mv t1, a0
    mv a0, t3
    mv t0, a0
    rem a0, t0, t1
    addi sp, sp, -4
    sw a0, 0(sp)
    lw a0, 4(s0)
    addi sp, sp, -4
    sw a0, 0(sp)
    jal ra, gcd
    addi sp, sp, 8
    j _ret4
    _ret4:
    addi sp, s0, -8
    lw   ra, 4(sp)
    lw   s0, 0(sp)
    addi sp, sp, 8
    ret
    sum_array:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    addi s0, sp, 8
    addi sp, sp, -16
    li a0, 0
    addi t0, s0, -12
    sw a0, 0(t0)
    li a0, 0
    mv t3, a0
    addi a0, s0, -16
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    _top8:
    lw a0, -16(s0)
    mv t3, a0
    lw a0, 4(s0)
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mv a0, t0
    slt a0, a0, t1
    beqz a0, _end9
    addi a0, s0, -12
    mv t3, a0
    lw a0, 0(a0)
    mv t4, a0
    lw a0, 0(s0)
    mv t2, a0
    lw a0, -16(s0)
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    lw a0, 0(a0)
    mv t2, a0
    mv t1, t4
    mv t0, t3
    add a0, t1, t2
    sw a0, 0(t0)
    _cont10:
    lw a0, -16(s0)
    mv t3, a0
    li a0, 1
    mv t1, a0
    mv a0, t3
    mv t0, a0
    add a0, t0, t1
    mv t3, a0
    addi a0, s0, -16
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    j _top8
    _end9:
    lw a0, -12(s0)
    j _ret7
    _ret7:
    addi sp, s0, -8
    lw   ra, 4(sp)
    lw   s0, 0(sp)
    addi sp, sp, 8
    ret
    reverse_array:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    addi s0, sp, 8
    addi sp, sp, -16
    li a0, 0
    mv t3, a0
    addi a0, s0, -12
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    _top12:
    lw a0, -12(s0)
    mv t3, a0
    lw a0, 4(s0)
    mv t4, a0
    li a0, 2
    mv t1, a0
    mv a0, t4
    mv t0, a0
    div a0, t0, t1
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mv a0, t0
    slt a0, a0, t1
    beqz a0, _end13
    lw a0, 0(s0)
    mv t2, a0
    lw a0, -12(s0)
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    lw a0, 0(a0)
    mv t3, a0
    addi a0, s0, -16
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    lw a0, 0(s0)
    mv t2, a0
    lw a0, 4(s0)
    mv t3, a0
    li a0, 1
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    mv t3, a0
    lw a0, -12(s0)
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    lw a0, 0(a0)
    mv t3, a0
    lw a0, 0(s0)
    mv t2, a0
    lw a0, -12(s0)
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    lw a0, -16(s0)
    mv t3, a0
    lw a0, 0(s0)
    mv t2, a0
    lw a0, 4(s0)
    mv t4, a0
    li a0, 1
    mv t1, a0
    mv a0, t4
    mv t0, a0
    sub a0, t0, t1
    mv t4, a0
    lw a0, -12(s0)
    mv t1, a0
    mv a0, t4
    mv t0, a0
    sub a0, t0, t1
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    _cont14:
    lw a0, -12(s0)
    mv t3, a0
    li a0, 1
    mv t1, a0
    mv a0, t3
    mv t0, a0
    add a0, t0, t1
    mv t3, a0
    addi a0, s0, -12
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    j _top12
    _end13:
    _ret11:
    addi sp, s0, -8
    lw   ra, 4(sp)
    lw   s0, 0(sp)
    addi sp, sp, 8
    ret
    sum_squares:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    addi s0, sp, 8
    addi sp, sp, -48
    li a0, 0
    mv t3, a0
    addi a0, s0, -44
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    _top16:
    lw a0, -44(s0)
    mv t3, a0
    li a0, 8
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mv a0, t0
    slt a0, a0, t1
    beqz a0, _end17
    lw a0, -44(s0)
    mv t3, a0
    lw a0, -44(s0)
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mul a0, t0, t1
    mv t3, a0
    addi a0, s0, -40
    mv t2, a0
    lw a0, -44(s0)
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    _cont18:
    lw a0, -44(s0)
    mv t3, a0
    li a0, 1
    mv t1, a0
    mv a0, t3
    mv t0, a0
    add a0, t0, t1
    mv t3, a0
    addi a0, s0, -44
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    j _top16
    _end17:
    li a0, 8
    addi sp, sp, -4
    sw a0, 0(sp)
    addi a0, s0, -40
    addi sp, sp, -4
    sw a0, 0(sp)
    jal ra, sum_array
    addi sp, sp, 8
    j _ret15
    _ret15:
    addi sp, s0, -8
    lw   ra, 4(sp)
    lw   s0, 0(sp)
    addi sp, sp, 8
    ret
    main:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    addi s0, sp, 8
    addi sp, sp, -48
    li a0, 7
    addi t0, s0, -12
    sw a0, 0(t0)
    li a0, 6
    addi t0, s0, -16
    sw a0, 0(t0)
    lw a0, -12(s0)
    mv t3, a0
    lw a0, -16(s0)
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mul a0, t0, t1
    mv t3, a0
    li a0, 42
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    beqz a0, _else20
    li a0, 1
    j _ret19
    _else20:
    li a0, 100
    mv t3, a0
    li a0, 7
    mv t1, a0
    mv a0, t3
    mv t0, a0
    div a0, t0, t1
    mv t3, a0
    li a0, 14
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    beqz a0, _else22
    li a0, 2
    j _ret19
    _else22:
    li a0, 100
    mv t3, a0
    li a0, 7
    mv t1, a0
    mv a0, t3
    mv t0, a0
    rem a0, t0, t1
    mv t3, a0
    li a0, 2
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    beqz a0, _else24
    li a0, 3
    j _ret19
    _else24:
    li a0, 10
    addi sp, sp, -4
    sw a0, 0(sp)
    jal ra, fib
    addi sp, sp, 4
    mv t3, a0
    li a0, 55
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    beqz a0, _else26
    li a0, 4
    j _ret19
    _else26:
    jal ra, sum_squares
    mv t3, a0
    li a0, 140
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    beqz a0, _else28
    li a0, 5
    j _ret19
    _else28:
    li a0, 0
    addi t0, s0, -20
    sw a0, 0(t0)
    _top30:
    lw a0, -20(s0)
    mv t3, a0
    li a0, 10
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mv a0, t0
    slt a0, a0, t1
    beqz a0, _end31
    lw a0, -20(s0)
    mv t3, a0
    li a0, 1
    mv t1, a0
    mv a0, t3
    mv t0, a0
    add a0, t0, t1
    mv t3, a0
    addi a0, s0, -20
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    j _top30
    _end31:
    lw a0, -20(s0)
    mv t3, a0
    li a0, 10
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    beqz a0, _else32
    li a0, 6
    j _ret19
    _else32:
    li a0, 0
    addi t0, s0, -24
    sw a0, 0(t0)
    li a0, 0
    mv t3, a0
    addi a0, s0, -28
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    _top34:
    lw a0, -28(s0)
    mv t3, a0
    li a0, 5
    mv t1, a0
    mv a0, t3
    mv t0, a0
    slt a0, t1, t0
    xori a0, a0, 1
    beqz a0, _end35
    addi a0, s0, -24
    mv t3, a0
    lw a0, 0(a0)
    mv t4, a0
    lw a0, -28(s0)
    mv t2, a0
    mv t1, t4
    mv t0, t3
    add a0, t1, t2
    sw a0, 0(t0)
    _cont36:
    lw a0, -28(s0)
    mv t3, a0
    li a0, 1
    mv t1, a0
    mv a0, t3
    mv t0, a0
    add a0, t0, t1
    mv t3, a0
    addi a0, s0, -28
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    j _top34
    _end35:
    lw a0, -24(s0)
    mv t3, a0
    li a0, 15
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    beqz a0, _else37
    li a0, 7
    j _ret19
    _else37:
    li a0, 5
    mv t3, a0
    li a0, 3
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mv a0, t0
    slt a0, a0, t1
    bnez a0, _or141
    li a0, 1
    mv t3, a0
    li a0, 1
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    seqz a0, a0
    seqz a0, a0
    bnez a0, _or141
    li a0, 0
    j _orE42
    _or141:
    li a0, 1
    _orE42:
    beqz a0, _else39
    li a0, 8
    j _ret19
    _else39:
    li a0, 65280
    mv t3, a0
    li a0, 4080
    mv t1, a0
    mv a0, t3
    mv t0, a0
    and a0, t0, t1
    mv t3, a0
    li a0, 4
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sra a0, t0, t1
    mv t3, a0
    li a0, 240
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    beqz a0, _else43
    li a0, 9
    j _ret19
    _else43:
    li a0, 3
    mv t3, a0
    li a0, 5
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mv a0, t0
    slt a0, a0, t1
    seqz a0, a0
    bnez a0, _or149
    li a0, 5
    mv t3, a0
    li a0, 3
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mv a0, t0
    slt a0, a0, t1
    bnez a0, _or149
    li a0, 0
    j _orE50
    _or149:
    li a0, 1
    _orE50:
    bnez a0, _or147
    li a0, 5
    mv t3, a0
    li a0, 5
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mv a0, t0
    slt a0, a0, t1
    bnez a0, _or147
    li a0, 0
    j _orE48
    _or147:
    li a0, 1
    _orE48:
    beqz a0, _else45
    li a0, 10
    j _ret19
    _else45:
    li a0, 5
    mv t3, a0
    li a0, 5
    mv t1, a0
    mv a0, t3
    mv t0, a0
    slt a0, t1, t0
    xori a0, a0, 1
    seqz a0, a0
    bnez a0, _or155
    li a0, 4
    mv t3, a0
    li a0, 5
    mv t1, a0
    mv a0, t3
    mv t0, a0
    slt a0, t1, t0
    xori a0, a0, 1
    seqz a0, a0
    bnez a0, _or155
    li a0, 0
    j _orE56
    _or155:
    li a0, 1
    _orE56:
    bnez a0, _or153
    li a0, 6
    mv t3, a0
    li a0, 5
    mv t1, a0
    mv a0, t3
    mv t0, a0
    slt a0, t1, t0
    xori a0, a0, 1
    bnez a0, _or153
    li a0, 0
    j _orE54
    _or153:
    li a0, 1
    _orE54:
    beqz a0, _else51
    li a0, 11
    j _ret19
    _else51:
    li a0, 5
    mv t3, a0
    li a0, 3
    mv t1, a0
    mv a0, t3
    mv t0, a0
    slt a0, t1, t0
    seqz a0, a0
    bnez a0, _or161
    li a0, 3
    mv t3, a0
    li a0, 5
    mv t1, a0
    mv a0, t3
    mv t0, a0
    slt a0, t1, t0
    bnez a0, _or161
    li a0, 0
    j _orE62
    _or161:
    li a0, 1
    _orE62:
    bnez a0, _or159
    li a0, 3
    mv t3, a0
    li a0, 3
    mv t1, a0
    mv a0, t3
    mv t0, a0
    slt a0, t1, t0
    bnez a0, _or159
    li a0, 0
    j _orE60
    _or159:
    li a0, 1
    _orE60:
    beqz a0, _else57
    li a0, 12
    j _ret19
    _else57:
    li a0, 5
    mv t3, a0
    li a0, 5
    mv t1, a0
    mv a0, t3
    mv t0, a0
    slt a0, t0, t1
    xori a0, a0, 1
    seqz a0, a0
    bnez a0, _or167
    li a0, 6
    mv t3, a0
    li a0, 5
    mv t1, a0
    mv a0, t3
    mv t0, a0
    slt a0, t0, t1
    xori a0, a0, 1
    seqz a0, a0
    bnez a0, _or167
    li a0, 0
    j _orE68
    _or167:
    li a0, 1
    _orE68:
    bnez a0, _or165
    li a0, 4
    mv t3, a0
    li a0, 5
    mv t1, a0
    mv a0, t3
    mv t0, a0
    slt a0, t0, t1
    xori a0, a0, 1
    bnez a0, _or165
    li a0, 0
    j _orE66
    _or165:
    li a0, 1
    _orE66:
    beqz a0, _else63
    li a0, 13
    j _ret19
    _else63:
    li a0, 18
    addi sp, sp, -4
    sw a0, 0(sp)
    li a0, 48
    addi sp, sp, -4
    sw a0, 0(sp)
    jal ra, gcd
    addi sp, sp, 8
    mv t3, a0
    li a0, 6
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    beqz a0, _else69
    li a0, 14
    j _ret19
    _else69:
    li a0, 0
    mv t3, a0
    addi a0, s0, -52
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    _top71:
    lw a0, -52(s0)
    mv t3, a0
    li a0, 5
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mv a0, t0
    slt a0, a0, t1
    beqz a0, _end72
    lw a0, -52(s0)
    mv t3, a0
    li a0, 1
    mv t1, a0
    mv a0, t3
    mv t0, a0
    add a0, t0, t1
    mv t3, a0
    li a0, 10
    mv t1, a0
    mv a0, t3
    mv t0, a0
    mul a0, t0, t1
    mv t3, a0
    addi a0, s0, -48
    mv t2, a0
    lw a0, -52(s0)
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    _cont73:
    lw a0, -52(s0)
    mv t3, a0
    li a0, 1
    mv t1, a0
    mv a0, t3
    mv t0, a0
    add a0, t0, t1
    mv t3, a0
    addi a0, s0, -52
    mv t0, a0
    mv a0, t3
    sw a0, 0(t0)
    j _top71
    _end72:
    li a0, 5
    addi sp, sp, -4
    sw a0, 0(sp)
    addi a0, s0, -48
    addi sp, sp, -4
    sw a0, 0(sp)
    jal ra, sum_array
    addi sp, sp, 8
    mv t3, a0
    li a0, 150
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    beqz a0, _else74
    li a0, 15
    j _ret19
    _else74:
    li a0, 5
    addi sp, sp, -4
    sw a0, 0(sp)
    addi a0, s0, -48
    addi sp, sp, -4
    sw a0, 0(sp)
    jal ra, reverse_array
    addi sp, sp, 8
    addi a0, s0, -48
    mv t2, a0
    li a0, 0
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    lw a0, 0(a0)
    mv t3, a0
    li a0, 50
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    bnez a0, _or184
    addi a0, s0, -48
    mv t2, a0
    li a0, 1
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    lw a0, 0(a0)
    mv t3, a0
    li a0, 40
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    bnez a0, _or184
    li a0, 0
    j _orE85
    _or184:
    li a0, 1
    _orE85:
    bnez a0, _or182
    addi a0, s0, -48
    mv t2, a0
    li a0, 2
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    lw a0, 0(a0)
    mv t3, a0
    li a0, 30
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    bnez a0, _or182
    li a0, 0
    j _orE83
    _or182:
    li a0, 1
    _orE83:
    bnez a0, _or180
    addi a0, s0, -48
    mv t2, a0
    li a0, 3
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    lw a0, 0(a0)
    mv t3, a0
    li a0, 20
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    bnez a0, _or180
    li a0, 0
    j _orE81
    _or180:
    li a0, 1
    _orE81:
    bnez a0, _or178
    addi a0, s0, -48
    mv t2, a0
    li a0, 4
    li a2, 4
    mul a0, a0, a2
    add a0, t2, a0
    lw a0, 0(a0)
    mv t3, a0
    li a0, 10
    mv t1, a0
    mv a0, t3
    mv t0, a0
    sub a0, t0, t1
    snez a0, a0
    bnez a0, _or178
    li a0, 0
    j _orE79
    _or178:
    li a0, 1
    _orE79:
    beqz a0, _else76
    li a0, 16
    j _ret19
    _else76:
    li a0, 0
    j _ret19
    _ret19:
    addi sp, s0, -8
    lw   ra, 4(sp)
    lw   s0, 0(sp)
    addi sp, sp, 8
    ret
    .data
