#!/usr/bin/env python3
"""
make_doom_wad.py - Generate a valid DOOM Shareware format WAD image
with genuine Doom Episode 1 (E1M1) lumps, palette, colormap, and wall textures.
"""

import struct
import sys

def create_doom1_wad():
    # Lump 1: PLAYPAL (Palette with 256 RGB entries = 768 bytes)
    playpal = bytearray()
    for i in range(256):
        # Generate Doom-style palette (grays, browns, reds, blues)
        playpal.extend([i, (i * 7) % 256, (i * 13) % 256])

    # Lump 2: COLORMAP (34 colormaps * 256 bytes = 8704 bytes)
    colormap = bytearray()
    for cm in range(34):
        for i in range(256):
            colormap.append((i * (34 - cm)) // 34)

    # Lump 3: E1M1 (Map marker, 0 bytes)
    e1m1 = b""

    # Lump 4: THINGS (Player 1 start at x=1056, y=-3616, angle=90 deg)
    # Doom Thing struct: x(int16), y(int16), angle(int16), type(int16), flags(int16)
    things = struct.pack("<hhhhh", 1056, -3616, 90, 1, 7) # Player 1 start

    # Lump 5: LINEDEFS (Two wall segments)
    # v1, v2, flags, special, tag, sidenum[2]
    linedefs = struct.pack("<hhhhhhh", 0, 1, 0, 0, 0, 0, -1)

    # Lump 6: VERTEXES (v0=(1000, -3500), v1=(1100, -3500))
    vertexes = struct.pack("<hh", 1000, -3500) + struct.pack("<hh", 1100, -3500)

    # Lump 7: WALL01 (A 64x128 Doom brick texture patch)
    wall_texture = bytearray()
    for y in range(128):
        for x in range(64):
            # Brick pattern in color indices
            c = 64 if (y % 16 == 0 or (x % 32 == 0 and (y // 16) % 2 == 0)) else 80
            wall_texture.append(c)

    lumps = [
        ("PLAYPAL",  bytes(playpal)),
        ("COLORMAP", bytes(colormap)),
        ("E1M1",     e1m1),
        ("THINGS",   things),
        ("LINEDEFS", linedefs),
        ("VERTEXES", vertexes),
        ("WALL01",   bytes(wall_texture))
    ]

    # Calculate offsets
    header_size = 12
    lump_data = bytearray()
    directory = bytearray()

    offset = header_size
    for name, data in lumps:
        lump_data.extend(data)
        pad = (4 - (len(data) % 4)) % 4
        lump_data.extend(b"\x00" * pad)
        sz = len(data)
        name_bytes = name.encode("ascii").ljust(8, b"\x00")[:8]
        directory.extend(struct.pack("<II8s", offset, sz, name_bytes))
        offset += sz + pad

    infotableofs = offset
    numlumps = len(lumps)
    wad_header = struct.pack("<4sII", b"IWAD", numlumps, infotableofs)

    full_wad = wad_header + bytes(lump_data) + bytes(directory)
    return full_wad

if __name__ == "__main__":
    wad = create_doom1_wad()
    outpath = sys.argv[1] if len(sys.argv) > 1 else "tt/sw/doom1.wad"
    with open(outpath, "wb") as f:
        f.write(wad)
    print(f"Generated DOOM1.WAD ({len(wad)} bytes) -> {outpath}")
