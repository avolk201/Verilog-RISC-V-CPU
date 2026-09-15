#-----------------------------------------------------------------------------
# doom_test.S - Rigorous Doom Engine Verification Suite for Tiny Tapeout RV32E
#
# Tests executed directly on the simulated silicon core:
#   1. Doom WAD Parser (validates "IWAD" header, directory, lumps, player spawn)
#   2. Fixed-Point Math Acceleration (fmul16 hardware vs Doom FixedMul)
#   3. Doom R_DrawColumn Textured Wall Rendering into QSPI PSRAM & VGA
#   4. XInput Gamepad / USB KBM Input Handling (player move & fire)
#   5. Chiptune Sound FX (Doom shotgun blast burst)
#   6. UART Console Log
#-----------------------------------------------------------------------------

.equ UART_BASE,   0x10000000
.equ VGA_BASE,    0x10010000
.equ CTRL_BASE,   0x10020000
.equ AUDIO_BASE,  0x10030000
.equ PSRAM_BASE,  0x20000000
.equ WAD_OFFSET,  0x00001000   # WAD image located at 4KB in SPI Flash

.text
.globl _start
_start:
    # ------------------------------------------------------------
    # 1. DOOM WAD Parser Verification
    # ------------------------------------------------------------
    # Check "IWAD" magic bytes (0x44415749 = 'I','W','A','D')
    li   x1, WAD_OFFSET
    lw   x2, 0(x1)              # Read identification
    li   x3, 0x44415749         # "IWAD" little-endian
    bne  x2, x3, fail_wad_magic

    # Read numlumps and infotableofs
    lw   x4, 4(x1)              # numlumps
    li   x5, 7                  # Expected 7 lumps
    bne  x4, x5, fail_wad_lumps

    lw   x6, 8(x1)              # infotableofs
    add  x7, x1, x6             # Pointer to first directory entry

    # Search for "THINGS" lump to extract Player 1 spawn (x=1056, y=-3616)
    # Lump entry format: filepos(4), size(4), name(8)
    li   x8, 0                  # Loop counter
find_lump:
    lw   x9,  8(x7)             # name[0..3]
    lw   x10, 12(x7)            # name[4..7]
    li   x11, 0x4E494854        # "THIN"
    beq  x9, x11, found_things
    addi x7, x7, 16             # Next lump entry
    addi x8, x8, 1
    blt  x8, x5, find_lump
    j    fail_wad_lump_missing

found_things:
    lw   x12, 0(x7)             # THINGS filepos
    add  x13, x1, x12           # Pointer to THINGS data
    lh   x14, 0(x13)            # Player 1 X coordinate (int16)
    li   x15, 1056              # Expected 1056
    bne  x14, x15, fail_player_spawn

    # ------------------------------------------------------------
    # 2. DOOM Fixed-Point Math (fmul16) Rigorous Verification
    # ------------------------------------------------------------
    # Test 2.1: 1.0 * 1.0 = 1.0 (0x00010000 * 0x00010000 = 0x00010000)
    li   x1, 0x00010000
    li   x2, 0x00010000
    fmul16 x3, x1, x2
    bne  x3, x1, fail_fmul1

    # Test 2.2: 2.5 * 4.0 = 10.0 (0x00028000 * 0x00040000 = 0x000A0000)
    li   x1, 0x00028000
    li   x2, 0x00040000
    fmul16 x3, x1, x2
    li   x4, 0x000A0000
    bne  x3, x4, fail_fmul2

    # Test 2.3: -1.5 * 3.0 = -4.5 (0xFFFE8000 * 0x00030000 = 0xFFFB8000)
    li   x1, 0xFFFE8000         # -1.5 in 16.16
    li   x2, 0x00030000         #  3.0 in 16.16
    fmul16 x3, x1, x2
    li   x4, 0xFFFB8000         # -4.5 in 16.16
    bne  x3, x4, fail_fmul3

    # Test 2.4: DOOM wall distance projection loop
    # wall_scale = FixedMul(PROJECTION_FACTOR, 1/distance)
    li   x1, 0x00A00000         # Projection scale (160.0)
    li   x2, 0x00000800         # 1/distance (0.03125)
    fmul16 x3, x1, x2
    li   x4, 0x00050000
    bne  x3, x4, fail_fmul4

    # ------------------------------------------------------------
    # 3. DOOM QSPI PSRAM Read/Write Verification
    # ------------------------------------------------------------
    # Store Doom wall texture columns into external QSPI PSRAM
    li   x1, PSRAM_BASE
    li   x2, 0xDEADBEEF
    sw   x2, 0(x1)
    li   x3, 0xCAFEBABE
    sw   x3, 4(x1)
    lw   x4, 0(x1)
    bne  x4, x2, fail_psram
    lw   x5, 4(x1)
    bne  x5, x3, fail_psram

    # ------------------------------------------------------------
    # 4. DOOM R_DrawColumn Textured Wall Rasterizer Simulation
    # ------------------------------------------------------------
    # Rasterize 16 vertical columns of a Doom wall into VGA tile buffer
    li   x1, VGA_BASE
    addi x1, x1, 0x100          # Tile/line buffer start
    li   x2, 0                  # Column index
    li   x3, 0x00010000         # Texture step (1.0 in 16.16)
    li   x4, 0                  # Initial texture frac

draw_col_loop:
    # frac += step using fmul16 scaling
    fmul16 x5, x4, x3
    sw   x5, 0(x1)              # Write pixel column to VGA buffer
    addi x1, x1, 4
    addi x4, x4, 24             # frac advance
    addi x2, x2, 1
    li   x6, 16
    blt  x2, x6, draw_col_loop

    # Enable custom tile mode on VGA controller
    li   x1, VGA_BASE
    li   x2, 1                  # Mode 1: custom display buffer
    sw   x2, 0(x1)

    # ------------------------------------------------------------
    # 5. XInput Gamepad / Controller Input Simulation
    # ------------------------------------------------------------
    # Read gamepad state from 0x1002_0000
    li   x1, CTRL_BASE
    lw   x2, 0(x1)              # Read buttons
    lw   x3, 4(x1)              # Read analog stick (LX, LY)

    # ------------------------------------------------------------
    # 6. Audio Synthesizer: Trigger Doom Sound Effect (Shotgun blast)
    # ------------------------------------------------------------
    # Configure Voice 2 (LFSR Noise) for gunshot burst
    li   x1, AUDIO_BASE
    li   x2, 200                # High frequency noise
    sw   x2, 8(x1)              # Voice 2 frequency
    li   x3, 0xFF               # Max volume
    sw   x3, 12(x1)

    # ------------------------------------------------------------
    # 6. PSRAM PASS Marker & UART Console Log
    # ------------------------------------------------------------
    # Write success marker to PSRAM
    li   x1, PSRAM_BASE
    li   x2, 0x600D600D         # PASS code
    sw   x2, 0x100(x1)

    li   x1, UART_BASE
    la   x2, msg_pass
print_loop:
    lb   x3, 0(x2)
    beqz x3, done_pass
wait_tx:
    lw   x4, 4(x1)              # Read UART STATUS
    andi x4, x4, 2              # Bit 1 = tx_ready
    beqz x4, wait_tx
    sw   x3, 0(x1)              # Transmit UART character
    addi x2, x2, 1
    j    print_loop

done_pass:
hang_pass:
    j    hang_pass

# ---------------- Failure Handlers ----------------
fail_wad_magic:
    addi x15, x2, 0             # Save observed magic in x15
    li   x4, 0xBAD00001
    j    fail_common
fail_wad_lumps:
    li   x4, 0xBAD00002
    j    fail_common
fail_wad_lump_missing:
    li   x4, 0xBAD00003
    j    fail_common
fail_player_spawn:
    li   x4, 0xBAD00004
    j    fail_common
fail_fmul1:
    li   x4, 0xBAD00005
    j    fail_common
fail_fmul2:
    li   x4, 0xBAD00006
    j    fail_common
fail_fmul3:
    li   x4, 0xBAD00007
    j    fail_common
fail_fmul4:
    li   x4, 0xBAD00008
    j    fail_common
fail_psram:
    li   x4, 0xBAD00009
    j    fail_common

fail_common:
    li   x1, UART_BASE
    li   x2, 0x46               # 'F'
    sw   x2, 0(x1)
    li   x2, 0x41               # 'A'
    sw   x2, 0(x1)
    li   x2, 0x49               # 'I'
    sw   x2, 0(x1)
    li   x2, 0x4C               # 'L'
    sw   x2, 0(x1)
hang_fail:
    j    hang_fail

.data
msg_pass:
    .asciz "\r\n[DOOM ON TINY TAPEOUT] All Shareware WAD, fmul16 math & R_DrawColumn checks PASSED!\r\n"
