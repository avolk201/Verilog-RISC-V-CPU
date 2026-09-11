# ---------------------------------------------------------------------------
# eth_loopback.S - Ethernet MAC transmit/receive self-test (single core)
#
# Stages a small Ethernet frame (DA/SA/EtherType/payload) into the MAC's TX
# buffer, transmits it (preamble+SFD+frame+CRC32), and - via the testbench GMII
# loopback - receives it back. The MAC validates the CRC on receive; software
# then compares the received bytes against the original frame. Match -> PASS.
# ---------------------------------------------------------------------------
    .equ ETH,      0x10010000
    .equ CTRL,     0x00
    .equ STATUS,   0x04
    .equ TXLEN,    0x08
    .equ RXLEN,    0x0C
    .equ TXDATA,   0x20
    .equ RXDATA,   0x24
    .equ tohost,   0x8001FFF0
    .equ PASS,     0x600D600D
    .equ FRAMELEN, 22

    .text
    .globl _start
_start:
    li   a0, ETH

    # ---- stage the frame into the TX buffer (auto-incrementing write) ----
    la   a1, frame
    li   a2, FRAMELEN
    li   a3, 0
stage:
    add  t1, a1, a3
    lbu  t2, 0(t1)
    sw   t2, TXDATA(a0)
    addi a3, a3, 1
    blt  a3, a2, stage

    # ---- arm and start transmission ----
    sw   a2, TXLEN(a0)
    li   t0, 0x01
    sw   t0, CTRL(a0)          # enable
    li   t0, 0x03
    sw   t0, CTRL(a0)          # enable + start_tx

    # ---- wait for transmit complete ----
wait_tx:
    lw   t1, STATUS(a0)
    andi t1, t1, 0x04          # tx_done
    beqz t1, wait_tx

    # ---- wait for a frame to be received (looped back) ----
wait_rx:
    lw   t1, STATUS(a0)
    andi t2, t1, 0x02          # rx_avail
    beqz t2, wait_rx
    andi t2, t1, 0x08          # rx_ok (CRC valid)
    beqz t2, fail
    andi t2, t1, 0x10          # rx_err
    bnez t2, fail

    # ---- length check ----
    lw   t3, RXLEN(a0)
    li   t4, FRAMELEN
    bne  t3, t4, fail

    # ---- byte-by-byte compare against the original frame ----
    la   a1, frame
    li   a3, 0
verify:
    lw   t2, RXDATA(a0)
    andi t2, t2, 0xFF
    add  t1, a1, a3
    lbu  t5, 0(t1)
    bne  t2, t5, fail
    addi a3, a3, 1
    blt  a3, t3, verify

    li   t0, PASS
    li   a0, tohost
    sw   t0, 0(a0)
    j    spin
fail:
    li   t0, 0xBAD00000
    li   a0, tohost
    sw   t0, 0(a0)
spin:
    j    spin

    .data
frame:
    .byte 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF   # DA (broadcast)
    .byte 0x00, 0x11, 0x22, 0x33, 0x44, 0x55   # SA
    .byte 0x08, 0x00                            # EtherType (IPv4)
    .byte 0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02, 0x03, 0x04   # payload
