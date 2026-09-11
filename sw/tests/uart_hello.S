# ---------------------------------------------------------------------------
# uart_hello.S - UART transmit/receive self-test (single core)
#
# Programs the UART divisor, then transmits a NUL-terminated message one byte at
# a time (polling LSR.THRE). The testbench loops tx -> rx, so each byte is read
# back (polling LSR.DR) and compared. A mismatch -> FAIL; full match -> PASS.
# The console echo in the testbench also prints the message.
# ---------------------------------------------------------------------------
    .equ UART,   0x10000000
    .equ LCR,    0x0C
    .equ LSR,    0x14
    .equ THR,    0x00
    .equ tohost, 0x8001FFF0
    .equ PASS,   0x600D600D

    .text
    .globl _start
_start:
    li   a0, UART
    # --- program divisor = 8 (fast for simulation), DLAB = 1 ---
    li   t0, 0x80
    sw   t0, LCR(a0)
    li   t0, 8
    sw   t0, THR(a0)          # DLL (offset 0 with DLAB=1)
    sw   zero, 4(a0)          # DLM (offset 4 with DLAB=1)
    # --- 8N1, DLAB = 0 ---
    li   t0, 0x03
    sw   t0, LCR(a0)

    la   a1, msg              # message lives in SRAM (.data)
send_loop:
    lbu  t1, 0(a1)
    beqz t1, tx_ok             # NUL terminator -> success
wait_thre:
    lw   t2, LSR(a0)
    andi t2, t2, 0x20         # THRE
    beqz t2, wait_thre
    sw   t1, THR(a0)          # transmit byte
wait_dr:
    lw   t2, LSR(a0)
    andi t2, t2, 0x01         # DR (looped back)
    beqz t2, wait_dr
    lw   t3, THR(a0)          # read received byte (RBR)
    bne  t3, t1, fail
    addi a1, a1, 1
    j    send_loop

tx_ok:
    li   t0, PASS
    li   a0, tohost
    sw   t0, 0(a0)
    j    spin
fail:
    li   t0, 0xBAD00000
    or   t0, t0, t3           # include the mismatched received byte
    li   a0, tohost
    sw   t0, 0(a0)
spin:
    j    spin

    .data
msg:
    .asciz "RV32 SoC UART OK\r\n"
