# RV32IMAC Multi-Core SoC

A clean, simulation-verified multi-core System-on-Chip built in synthesizable Verilog. This repository serves as a reusable CPU and SoC IP block, designed to be integrated into larger ASIC tapeout projects and FPGA systems.

## The IP Ecosystem
This repository has been decoupled from its software toolchain to support a modular, IP-driven design methodology.

1. Verilog-RISC-V-CPU (This Repository): The verified RV32IMAC multi-core CPU, bus arbiter, memory controllers, and peripheral subsystem.
2. rv32-toolchain (External Dependency): Custom C compiler and assembler required to build software for this SoC.
3. rv32-apu-tapeout: Top-level integration project featuring this SoC and a custom procedural graphics accelerator.

## Architecture

    +----------------------------------------------------+
    |                    soc_top                         |
    |   +---------+   shared   +------------------+      |
    |   | rv32    |   instr    |   boot_rom       |      |
    |   | core 0  |------------| (multi-port read)|      |
    |   +---------+            +------------------+      |
    |        |                                           |
    |   +---------+                                      |
    |   | rv32    |     +-----------------------+        |
    |   | core 1  |---->|  soc_bus              |        |
    |   +---------+     |  (rotating-priority   |        |
    |        .          |   arbiter + decoder)  |        |
    |   +---------+     +-----------+-----------+        |
    |   | rv32    |                 |                    |
    |   | core N  |     +-----------+-----------+        |
    |   +---------+     |           |           |        |
    |                   |           |           |        |
    |                +--v---+    +--v---+    +--v---+    |
    |                | SRAM |    | CLINT|    | UART |    |
    |                | AMO  |    | Timer|    | 16550|    |
    |                | LR/SC|    | IPI  |    |      |    |
    |                +------+    +------+    +------+    |
    +----------------------------------------------------+

## Key Features

### RV32IMAC Core
* 5-stage pipeline (IF, ID, EX, MEM, WB) with full data forwarding and load/CSR-use interlocks.
* Machine-mode CSRs (mstatus, mie, mip, mtvec, mepc, mcause) with precise exceptions and interrupt trapping.
* Hardware support for RV32A atomics (AMO* and LR/SC) to enable symmetric multiprocessing (SMP).

### Multi-Core SMP
* Parameterized NUM_CORES top-level design.
* Shared memory space via a rotating-priority bus arbiter.
* Sequentially consistent memory model (no caches), ensuring atomic read-modify-write operations are indivisible across cores.

### Peripherals
* CLINT: Machine timer (mtime/mtimecmp) and software interrupts for cross-core IPIs.
* UART: 16550-style serial TX/RX.
* Ethernet MAC: GMII-style framing with CRC-32 generation and validation.

## Verification & Regression
The design is verified end-to-end using self-checking testbenches. The regression suite includes:

* core_test: Verifies ALU, shifts, M-extension, branches, and atomic instructions.
* multicore_lock: 4-core SMP test using AMOSWAP spinlocks to prove memory coherence.
* uart_hello: Serial transmission and loopback reception.
* eth_loopback: Ethernet packet framing, CRC-32, and GMII loopback validation.

## Getting Started

### Prerequisites
* Icarus Verilog (iverilog, vvp)
* Python 3
* The external rv32-toolchain repository

### Building and Simulating
By default, the Makefile expects the toolchain to be located at ../rv32-toolchain. If your toolchain is located elsewhere, override the TOOLCHAIN_DIR variable.

Run the full regression suite:

    make test

Run with a custom toolchain path:

    make TOOLCHAIN_DIR=/path/to/rv32-toolchain test

Generate waveforms for debugging:

    make waves

## Repository Layout

    rtl/
      core/         rv32_core, rv32_decoder, rv32_alu, rv32_csr
      interconnect/ soc_bus (arbiter + decoder)
      mem/          boot_rom, sram (with atomic support)
      periph/       uart, eth_mac, clint
      soc/          soc_top
    tb/
      tb_soc.v      Self-checking SoC testbench
    sim/
      files.f       Source list for simulation
    sw/
      tests/        Assembly and C regression tests

## License
MIT License. See LICENSE for details.
