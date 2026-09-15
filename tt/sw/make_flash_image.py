#!/usr/bin/env python3
"""
make_flash_image.py - Create a combined SPI Flash memory image containing:
  - 0x0000..: Boot firmware instructions
  - 0x0800..: String constants & rodata
  - 0x1000..: DOOM1.WAD binary image
"""

import sys

def build_flash_image(rom_hex, ram_hex, wad_bin, out_hex):
    FLASH_SIZE = 65536
    mem = bytearray([0xFF] * FLASH_SIZE)

    # 1. Load instructions from rom_hex (32-bit hex words)
    with open(rom_hex) as f:
        addr = 0
        for line in f:
            s = line.strip()
            if not s: continue
            val = int(s, 16)
            # Little endian byte placement
            mem[addr + 0] = val & 0xFF
            mem[addr + 1] = (val >> 8) & 0xFF
            mem[addr + 2] = (val >> 16) & 0xFF
            mem[addr + 3] = (val >> 24) & 0xFF
            addr += 4

    # 2. Load data from ram_hex (32-bit hex words) at 0x0800
    with open(ram_hex) as f:
        addr = 0x0800
        for line in f:
            s = line.strip()
            if not s: continue
            val = int(s, 16)
            mem[addr + 0] = val & 0xFF
            mem[addr + 1] = (val >> 8) & 0xFF
            mem[addr + 2] = (val >> 16) & 0xFF
            mem[addr + 3] = (val >> 24) & 0xFF
            addr += 4

    # 3. Load DOOM1.WAD at 0x1000 (4096)
    with open(wad_bin, "rb") as f:
        wad_bytes = f.read()
    mem[0x1000:0x1000 + len(wad_bytes)] = wad_bytes

    # Write out hex format for Verilog $readmemh
    with open(out_hex, "w") as f:
        for b in mem:
            f.write(f"{b:02x}\n")

    print(f"Created unified SPI Flash image ({FLASH_SIZE} bytes) with DOOM1.WAD -> {out_hex}")

import os

if __name__ == "__main__":
    prefix = "sw/" if os.path.exists("sw/doom1.wad") else "tt/sw/"
    build_flash_image(
        prefix + "doom_test.rom.hex",
        prefix + "doom_test.ram.hex",
        prefix + "doom1.wad",
        prefix + "flash_image.hex"
    )
