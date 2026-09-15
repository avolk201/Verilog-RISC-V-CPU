# Tiny Tapeout RV32 Fork — Architectural Outline

## 1. Executive Summary & "Worth Fabbing" Value Proposition

Most microcontroller and RISC-V cores submitted to Tiny Tapeout suffer from two critical limitations that make them disappointing once fabricated:
1. **The Memory Wall**: They rely on tiny internal flip-flop ROMs (16 to 64 instructions) because standard tiles cannot fit SRAM macros. Once fabbed, they can only run a hardcoded blinker program.
2. **Lack of Novelty**: Plain RV32 cores on silicon are already ubiquitous.

### The "Worth Fabbing" Killer Feature: The *Tiny Silicon Computer*
To make this chip genuinely exciting to receive back from the foundry, this fork transforms the RV32 SoC into a **self-contained retro workstation / gaming SoC** that drives physical peripherals directly:
1. **Dual External SPI/QSPI Engine (Flash XIP + PSRAM)**:
   - Overcomes the TT memory wall with dual chip-selects: `spi_flash_cs_n` (e.g. W25Q128 16 MB Flash) and `spi_psram_cs_n` (e.g. APS6404 8 MB PSRAM).
   - Transparently maps 16 MB code space + 8 MB continuous read/write RAM space.
2. **Integrated Hardware VGA Display Controller (640×480 @ 60 Hz)**:
   - Connects directly to the standard **Tiny Tapeout VGA Pmod** via `uo_out[7:0]` (2-bit Red, 2-bit Green, 2-bit Blue, HSYNC, VSYNC).
   - Hardware character/tile generator: eliminates the need for a massive full-frame buffer while providing an 80×30 text mode or 40×30 colored tile graphics mode directly from a compact dual-port line/tile buffer.
3. **Hardware Chiptune Audio Synthesizer (PWM DAC)**:
   - Programmable multi-waveform square/triangle/noise sound generator with hardware volume envelope for chiptunes, sound effects, and audible feedback via a speaker Pmod.
4. **Hardware SIMD / Dot-Product Coprocessor (TinyML Hook)**:
   - A custom single-cycle instruction / MMIO accelerator for 4× 8-bit dot-product (`dotp8`), enabling edge-AI inference (neural net forward pass) and fast DSP.
5. **Integrated USB Keyboard / Mouse & XInput Gamepad Controller**:
   - Dedicated hardware input decoder block supporting USB HID keyboards, USB mice, and XInput (Xbox-style) controllers.
   - Dual-mode input:
     - **Direct USB Low-Speed HID (D+/D-)**: Hardware state machine handles NRZI, bit-stuffing, and HID packet parsing for direct plug-and-play USB keyboards and mice.
     - **XInput / High-Speed Host Stream via UART**: Fully compatible with the Tiny Tapeout Demo Board's companion RP2040 USB Host, which enumerates USB XInput gamepads (analog sticks, triggers, D-pad, face buttons) and USB mice/keyboards, translating them into zero-overhead MMIO register updates.

### Flair & The "Can It Run DOOM?" Factor
1. **Silicon Power-on Chime & Hardware Boot Badge (Flair)**:
   - The hardware audio unit features an autonomous, zero-software **power-on silicon chime** (like the iconic Game Boy or Macintosh boot chord) that triggers immediately on reset release.
   - The VGA engine includes a default test pattern / hardware boot badge that displays instantly upon power-up, proving silicon liveness even without an external flash attached!
2. **Can It Run DOOM?**:
   - **Memory**: Original Doom requires ~4 MB of RAM. By supporting external 8-pin QSPI PSRAM (APS6404, 8 MB in an 8-pin SOIC package) alongside QSPI Flash, the memory requirement is **100% solved**.
   - **Compute**: 90% of Doom's engine time is spent in fixed-point math (`FixedMul(a, b) = (a * b) >> 16`) and textured column drawing.
   - **The "Doom Assist" Instruction (`fmul16`)**: We include a dedicated single-cycle 16.16 signed fixed-point multiplier (`fmul16 rd, rs1, rs2 = (rs1 * rs2) >>> 16`). With `fmul16` and QSPI PSRAM, the chip has the exact architectural foundation needed to run Doom (or Wolfenstein 3D / Doom-nano) at playable framerates on silicon!
   - **Controls**: Full USB Keyboard (WASD + Space + Enter), USB Mouse (look/shoot), and XInput gamepad (analog sticks + triggers + buttons) inputs mapped directly into hardware registers.

---

## 2. Pinout & Tiny Tapeout Form Factor

### Target Tile Configuration
- **Tile Dimensions**: 2×2 or 3×2 Tiny Tapeout tiles (~320 µm × 200 µm or ~480 µm × 200 µm in SkyWater Sky130).
- **Target Standard Cell Count**: ~4,500 to 7,500 standard cells.

### Pin Allocation (`tt_um_tiny_rv32`)
The design strictly conforms to the Tiny Tapeout 8-in / 8-out / 8-bidir pin contract:

| Pin Group | Pin Name | Direction | Function | Compatible Pmod / External Hardware |
|---|---|---|---|---|
| **`uo_out[7:0]`** | `uo_out[1:0]` | Output | Red [1:0] (DAC) | **Tiny Tapeout VGA Pmod** |
| | `uo_out[3:2]` | Output | Green [1:0] (DAC) | |
| | `uo_out[5:4]` | Output | Blue [1:0] (DAC) | |
| | `uo_out[6]` | Output | HSYNC | |
| | `uo_out[7]` | Output | VSYNC | |
| **`uio[5:0]`** | `uio[0]` | Output | `spi_sclk` | **Dual SPI Flash / PSRAM Pmod** |
| | `uio[1]` | Output | `spi_flash_cs_n` | (e.g. W25Q128 Flash) |
| | `uio[2]` | Output | `spi_mosi` | |
| | `uio[3]` | Input | `spi_miso` | |
| | `uio[4]` | Output | `spi_psram_cs_n` | (e.g. APS6404 8 MB PSRAM) |
| | `uio[5]` | Bidir | `usb_dp` / Direct USB D+ | USB D+ (or QSPI IO3) |
| **`uio[7:6]`** | `uio[6]` | Output | Audio PWM DAC | Speaker / Headphone Pmod |
| | `uio[7]` | Output | Status LED / Heartbeat | On-board LED |
| **`ui_in[7:0]`** | `ui_in[0]` | Input | UART RX / XInput Host Stream | USB-UART bridge / TT Demo RP2040 Host |
| | `ui_in[1]` | Input | `usb_dm` / Direct USB D- | USB D- line |
| | `ui_in[6:2]` | Input | Gamepad / Directional Buttons | Pushbuttons (Up, Down, Left, Right, Action) |
| | `ui_in[7]` | Input | Boot Mode Select (0=SPI Flash, 1=UART Bootloader) | DIP switch |

---

## 3. Subsystem Architecture

```
                                  +---------------------------------------+
                                  |         tt_um_tiny_rv32 (SoC)         |
                                  |                                       |
    SPI Flash (Ext) <============>| [ SPI XIP Engine + 256B Direct Cache] |
                                  |                 | (Mem Bus)           |
    UART RX/TX      <============>|           [ Arbiter ]                 |
                                  |          /      |     \               |
                                  |  [RV32 Core] [SRAM]  [VGA + Audio]    |
                                  |   (Area-Opt   (512B   - 640x480 Video |
                                  |    3-stage)   Regs)   - Chiptune PWM  |
                                  |     + MAC8            - Tile Engine   |
                                  +-------|-----------|--------|----------+
                                          |           |        |
                                       ui_in       uio[*]    uo_out (VGA)
```

### 3.1. CPU Core (`tiny_rv32_core`)
- **ISA**: RV32E or RV32I. RV32E uses 16 general-purpose registers (`x0`–`x15`), saving 512 D-flip-flops (~3,000 standard cells) while maintaining standard GCC / Clang toolchain compatibility via `-march=rv32e -mabi=ilp32e`.
- **Pipeline**: Area-efficient 3-stage pipeline (IF → ID/EX → MEM/WB). Eliminates wide pipeline hazard registers and multi-port forwarding arrays while achieving ~20–30 MHz on Sky130.
- **Custom Instruction / Accelerator**: Single-cycle 4-way 8-bit dot-product accumulator (`dotp8 rd, rs1, rs2`: $rd = rd + \sum_{i=0}^3 rs1_i \times rs2_i$).

### 3.2. Memory Subsystem
- **SPI XIP Controller**: Continuously translates core instruction fetches to fast SPI continuous read commands (0x03 or 0xEB Fast Read).
- **Direct-Mapped Cache**: 256 bytes (64 words) of high-speed instruction cache synthesized with scan/clock-gated flip-flops, boosting SPI execution performance by 4–8×.
- **On-Chip Scratchpad**: 512 bytes of internal static memory for stack and hot zero-wait-state variables.

### 3.3. Video & Audio Display Subsystem
- **VGA Timing Generator**: Generates standard 25.175 MHz pixel clock timings (or 25 MHz integer divider) for 640×480 @ 60 Hz.
- **Hardware Tile Engine**:
  - Uses an internal 64-character glyph ROM and small row buffer.
  - Generates crisp 80×30 text mode or 40×30 color glyphs in real-time on `uo_out[7:0]`.
- **Audio Sound Generator**:
  - 3-voice chiptune generator (Square wave with variable duty cycle, triangle wave, pseudo-random noise LFSR).
  - High-frequency delta-sigma or PWM audio output on `uio[6]`.

---

## 4. Implementation Steps & Milestones

1. **Phase 1: Project Structuring & Tiny Tapeout Scaffolding**
   - Create directory `tt/` with Tiny Tapeout compliance files:
     - `info.yaml` (pin description, project metadata, author info)
     - `tt_um_tiny_rv32.v` (top-level wrapper module)
     - Hardening configuration for OpenLane / Sky130

2. **Phase 2: Core Adaptations**
   - Adapt `rv32_core` into an area-optimized RV32E/I engine.
   - Add the custom `dotp8` SIMD instruction / coprocessor.

3. **Phase 3: Peripherals & Memory**
   - Implement the SPI XIP engine and direct-mapped instruction cache.
   - Implement the hardware VGA timing & character/tile engine.
   - Implement the PWM chiptune audio generator and minimal UART.

4. **Phase 4: Simulation & Testbenches**
   - Write an Icarus Verilog testbench simulating SPI flash model, VGA signal verification (hsync/vsync assertions), and UART interactive console.
   - Create a bare-metal demo that outputs graphical text to VGA, plays a chiptune melody, and runs a dot-product benchmark.

5. **Phase 5: Synthesis & Gate Count Verification**
   - Run synthesis with Yosys / OpenLane to confirm cell counts fit comfortably inside the allocated Tiny Tapeout tile budget.
