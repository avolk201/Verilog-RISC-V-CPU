# Tiny Silicon Computer — RV32E for Tiny Tapeout

A tapeout-ready, self-contained **RV32E retro workstation / gaming SoC** designed for **Tiny Tapeout (SkyWater Sky130)**.

Unlike typical microcontroller submissions that only fit tiny hardcoded ROMs and run blinkers, this chip provides an **external SPI Flash XIP and 8MB QSPI PSRAM interface**, **direct VGA Pmod graphics**, **chiptune PWM audio with an autonomous boot chime**, **hardware DOOM fixed-point acceleration**, and **USB Keyboard, Mouse & XInput Gamepad support**.

---

## Highlights & "Worth Fabbing" Features

- **Area-Optimized RV32E 3-Stage Core**:
  - 16 general-purpose registers (`x0`–`x15`), saving >500 DFFs to fit within a 3×2 Sky130 tile budget (~4,500–7,500 standard cells).
  - Clean 3-stage pipeline (IF → ID/EX → MEM/WB) with wait-state stall support.
- **Dual External SPI Flash XIP & QSPI PSRAM**:
  - `spi_flash_cs_n` addresses up to 16 MB of external SPI Flash code space (`0x0000_0000`–`0x00FF_FFFF`) backed by an on-chip **256-byte direct-mapped I-cache**.
  - `spi_psram_cs_n` addresses up to 8 MB of external QSPI PSRAM (`0x2000_0000`–`0x207F_FFFF`), completely solving the memory wall and providing enough continuous RAM to run real ports of **DOOM** or Wolfenstein 3D!
- **Hardware DOOM Assist (`fmul16`)**:
  - Single-cycle custom instruction: `fmul16 rd, rs1, rs2` computes $(rs1 \times rs2) \gg 16$ (16.16 signed fixed-point multiplication), accelerating the inner wall-projection, raycasting, and texture-mapping loop of DOOM (`FixedMul`).
- **TinyML / DSP Assist (`dotp8`)**:
  - Single-cycle 4-way 8-bit vector dot-product multiply-accumulate unit: $rd = rd + \sum_{i=0}^3 (rs1_i \times rs2_i)$ for audio synthesis, filtering, and edge-AI neural network inference.
- **Direct 640×480 @ 60 Hz VGA Output**:
  - Connects directly to the standard **Tiny Tapeout VGA Pmod** on `uo_out[7:0]` (2-bit Red, 2-bit Green, 2-bit Blue, HSYNC, VSYNC).
  - Autonomous power-on hardware color bars & "TINY-RV32" boot badge prove display integrity even without external flash.
- **Chiptune Audio Synthesizer with Autonomous Silicon Boot Chime**:
  - 3 audio voices: pulse/square wave with duty cycle, triangle wave, and 16-bit pseudo-random noise LFSR.
  - High-frequency 8-bit PWM DAC output on `uio[6]`.
  - **The Flair**: Hardware 3-chord power-on chime plays autonomously out of reset.
- **USB Keyboard, Mouse & XInput Gamepad Controller**:
  - Connects to Tiny Tapeout Demo Board's companion RP2040 USB Host (or USB-UART bridge) on `ui_in[0]`, parsing standard USB HID keyboards, USB mice, and Xbox 360/One XInput controllers into zero-wait MMIO registers.
  - Standalone direct pushbuttons on `ui_in[6:2]` (Up, Down, Left, Right, Action).

---

## Tiny Tapeout Pinout Mapping (`tt_um_tiny_rv32`)

| Pin | Direction | Signal | Function |
|---|---|---|---|
| `ui_in[0]` | Input | `serial_rx` | UART RX / XInput Host Stream (115200 baud) |
| `ui_in[1]` | Input | `usb_dm` | Direct USB Low-Speed D- |
| `ui_in[2]` | Input | `gpio_btn_up` | Gamepad UP (active-low with pullup) |
| `ui_in[3]` | Input | `gpio_btn_down` | Gamepad DOWN (active-low with pullup) |
| `ui_in[4]` | Input | `gpio_btn_left` | Gamepad LEFT (active-low with pullup) |
| `ui_in[5]` | Input | `gpio_btn_right` | Gamepad RIGHT (active-low with pullup) |
| `ui_in[6]` | Input | `gpio_btn_action`| Gamepad ACTION / FIRE (active-low with pullup) |
| `ui_in[7]` | Input | `boot_mode` | 0 = SPI Flash XIP, 1 = UART Bootloader |
| `uo_out[0]` | Output | `vga_r0` | VGA Red 0 (LSB) |
| `uo_out[1]` | Output | `vga_r1` | VGA Red 1 (MSB) |
| `uo_out[2]` | Output | `vga_g0` | VGA Green 0 (LSB) |
| `uo_out[3]` | Output | `vga_g1` | VGA Green 1 (MSB) |
| `uo_out[4]` | Output | `vga_b0` | VGA Blue 0 (LSB) |
| `uo_out[5]` | Output | `vga_b1` | VGA Blue 1 (MSB) |
| `uo_out[6]` | Output | `vga_hsync_n` | VGA Horizontal Sync (active-low) |
| `uo_out[7]` | Output | `vga_vsync_n` | VGA Vertical Sync (active-low) |
| `uio[0]` | Output | `spi_sclk` | SPI Serial Clock |
| `uio[1]` | Output | `spi_flash_cs_n`| SPI Flash Chip Select (active-low) |
| `uio[2]` | Output | `spi_mosi` | SPI Master-Out Slave-In |
| `uio[3]` | Input | `spi_miso` | SPI Master-In Slave-Out |
| `uio[4]` | Output | `spi_psram_cs_n`| QSPI PSRAM Chip Select (active-low, 8 MB RAM) |
| `uio[5]` | Input | `usb_dp` | Direct USB Low-Speed D+ |
| `uio[6]` | Output | `audio_pwm` | Audio PWM DAC output to Speaker Pmod |
| `uio[7]` | Output | `heartbeat_tx` | Heartbeat LED & UART TX output |

---

## Memory Map

| Address Range | Size | Description | Access |
|---|---|---|---|
| `0x0000_0000` – `0x00FF_FFFF` | 16 MB | External SPI Flash XIP (with 256B I-Cache) | Read-Only |
| `0x1000_0000` – `0x1000_00FF` | 256 B | Mini UART Transceiver | Read / Write |
| `0x1001_0000` – `0x1001_00FF` | 256 B | Hardware VGA Controller & Line Buffer | Read / Write |
| `0x1002_0000` – `0x1002_00FF` | 256 B | USB Keyboard, Mouse & XInput Gamepad Registers | Read-Only |
| `0x1003_0000` – `0x1003_00FF` | 256 B | 3-Voice Chiptune Audio Synthesizer | Read / Write |
| `0x2000_0000` – `0x207F_FFFF` | 8 MB | External QSPI PSRAM (APS6404) | Read / Write |
| `0x8000_0000` – `0x8000_01FF` | 512 B | On-Chip Fast Zero-Wait Scratchpad SRAM | Read / Write |

---

## Custom Instructions

### 1. `fmul16 rd, rs1, rs2` (DOOM FixedMul Assist)
- **Opcode**: `7'b0001011` (`CUSTOM_0`), `funct3 = 3'b000`, `funct7 = 7'b0000001`
- **Operation**: Signed 16.16 fixed-point multiplication:
  $$rd = \frac{rs1 \times rs2}{65536} = (rs1 \times rs2) \gg 16$$
- **Latency**: Single-cycle.

### 2. `dotp8 rd, rs1, rs2` (TinyML / Vector MAC Assist)
- **Opcode**: `7'b0001011` (`CUSTOM_0`), `funct3 = 3'b001`, `funct7 = 7'b0000001`
- **Operation**: 4-way packed signed 8-bit dot-product accumulated into $rd$:
  $$rd = rd + \sum_{i=0}^3 \left( rs1[8i+7:8i] \times rs2[8i+7:8i] \right)$$
- **Latency**: Single-cycle.

---

## Verification

To run the full self-checking testbench:

```bash
make -C tt test
```

Expected output:
```
================ Running Tiny Tapeout RV32 Simulation ================
[STATUS] Reset released at t=100000 ps. Clocking SoC...
[PASS] Autonomous Silicon Boot Chime activated on reset release!
[PASS] VGA Timing Generator active: HSYNC=1, VSYNC=1
[PASS] Heartbeat LED active on uio[7]: 1
[PASS] USB / XInput Gamepad packet successfully received & decoded!
[PASS] Direct GPIO Gamepad pushbutton registered on MMIO bus!
[PASS] Verified DOOM fmul16 hardware math unit in core pipeline!
[PASS] Verified TinyML dotp8 4-way vector multiply-accumulate!
=========================================================
   ALL 7 VERIFICATION CHECKS PASSED SUCCESSFULLY!     
   TINY SILICON COMPUTER IS TAPE-OUT READY!              
=========================================================
```
