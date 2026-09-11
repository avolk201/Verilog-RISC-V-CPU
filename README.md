# RV32 SoC — A Multi-Core RISC-V System-on-Chip in Verilog

A clean, simulation-verified **multi-core System-on-Chip** built around a
5-stage pipelined **RV32IMAC** CPU. This project is a ground-up rewrite and
extension of [`avolk201/Verilog-RISC-V-CPU`](https://github.com/avolk201/Verilog-RISC-V-CPU)
(a 16-bit teaching core): the original ISA was replaced with standard RISC-V, the
pipeline was rebuilt with correct hazard/forwarding and precise machine-mode
traps, and full SoC infrastructure (interconnect, shared memory with atomics,
UART, Ethernet, CLINT) was added to support **symmetric multiprocessing**.

Everything is written in plain, synthesizable-style Verilog-2005 and verified
end-to-end with Icarus Verilog. A self-contained Python RV32 assembler is
included, so **no external RISC-V toolchain is required**.

---

## Highlights

- **RV32IMAC core** — integer base + multiply/divide (M) + atomics (A),
  machine-mode CSRs, precise exceptions and interrupt trapping.
- **Multi-core SMP** — `NUM_CORES` identical harts share one address space.
  Cross-core synchronisation via `LR/SC` and `AMO*` on shared SRAM.
- **Arbitrated interconnect** — rotating-priority bus with address decoding;
  single-beat AMOs are atomic across masters.
- **Peripherals** — 16550-style **UART** (real serial TX/RX), **Ethernet MAC**
  (GMII-style framing with CRC-32), **CLINT** (timer + software IPIs).
- **Self-contained toolchain** — a Python RV32IMAC assembler (`rv32asm.py`) and
  a rudimentary C compiler (`rvcc.py`) compile and emit ROM/RAM hex images directly.
- **Self-checking regression** — `make test` runs every demo and reports
  PASS/FAIL; the UART demos echo to the console.

```
                +-----------------------------------------------+
                |                   soc_top                      |
   hart 0       |   +---------+   shared   +------------------+  |
  ifetch <------+-->| rv32    |   instr    |   boot_rom       |  |
   data  <----+-+   | core    |   ROM      | (NUM_PORTS reads)|  |
              | |   +---------+            +------------------+  |
              | |   +---------+                                  |
              | +-->| rv32    |     +-----------------------+    |
              +---->| core 1  |---->|  soc_bus              |    |
                    +---------+  .  |  (round-robin arbiter |    |
                        .          |   + address decoder)  |    |
                        .          +-----------+-----------+    |
              +---->| core N-1|                |                 |
              |         +---------+   +--------+--------+        |
              |                     |   |    |    |    |        |
              |                  +--+ +-+  +-+  +-+  +-+         |
              |                  |SRAM||CLINT||UART||ETH|        |
              |                  +----++-----++----++---+        |
              +-----------------------------------------------+
```

---

## Quick start

```bash
make test          # assemble, build, and run the full regression
```

Expected output:

```
================ RV32 SoC regression ================
[  PASSED  ] sw/tests/core_test.rom.hex  (cores=1, 197 cycles)
[  PASSED  ] sw/tests/uart_hello.rom.hex  (cores=1, 1878 cycles)
[  PASSED  ] sw/tests/eth_loopback.rom.hex  (cores=1, 511 cycles)
[  PASSED  ] sw/tests/c_arith.rom.hex  (cores=1, 11129 cycles)
[  PASSED  ] sw/tests/hello_uart.rom.hex  (cores=1, 7574 cycles)
[  PASSED  ] sw/tests/multicore_lock.rom.hex  (cores=4, 2423 cycles)
=====================================================
ALL TESTS PASSED
```

Requirements: **Icarus Verilog** (`iverilog`, `vvp`) and **Python 3**.

Run a single program manually:

```bash
iverilog -g2012 -I rtl/periph -P tb_soc.NUM_CORES=1 -o sim/tb1.vvp -s tb_soc -c sim/files.f
vvp sim/tb1.vvp +ROM=sw/tests/uart_hello.rom.hex +RAM=sw/tests/uart_hello.ram.hex
```

Waveforms are dumped to `sim/dump.vcd` (`make waves`).

---

## The demos

| Program | Cores | What it proves |
|---|---|---|
| `core_test.S` | 1 | RV32IMAC ISA: ALU, shifts, `M` mul/div, signed/unsigned & sub-word loads/stores, branches, `JAL/JALR`, CSRs, and `AMOSWAP`/`AMOADD`/`LR`/`SC`. |
| `multicore_lock.S` | 4 | **SMP correctness**: 4 harts concurrently increment a shared counter under an `AMOSWAP` spinlock; the result is exactly `NCORES*ITER` (no lost updates). |
| `uart_hello.S` | 1 | UART transmit + loopback receive of a string; the testbench decodes the serial line and echoes `RV32 SoC UART OK`. |
| `eth_loopback.S` | 1 | Ethernet MAC builds a framed packet with CRC-32, transmits over GMII, receives it back through loopback, validates CRC, and byte-compares. |
| `c_arith.c` | 1 | **Single-core C compiler**: functions, recursion (`fib`, `gcd`), local arrays, pointer passing, array manipulation, relational comparisons (`<`, `<=`, `>`, `>=`), loops, and control flow. |
| `hello_uart.c` | 1 | **C peripheral driver**: UART programming and polled string transmission with loopback reception entirely from C. |

> [!NOTE]
> **Multi-core C status**: Multi-core hardware SMP is fully verified in assembly (`multicore_lock.S`). Multi-core C code generation is currently work-in-progress (WIP) due to stack contention under heavy bus traffic, so the verified C demos currently run single-core.

Each program writes a result code to the `tohost` word in shared SRAM
(`0x8001FFF0`); the testbench polls it and reports PASS/FAIL.

---

## Repository layout

```
rtl/
  core/         rv32_core, rv32_decoder, rv32_alu, rv32_regfile,
                rv32_immgen, rv32_csr        (the CPU)
  interconnect/ soc_bus.v                    (arbiter + decoder)
  mem/          boot_rom.v, sram.v           (shared ROM + atomic-capable RAM)
  periph/       uart.v, eth_mac.v, clint.v, eth_crc32.vh
  soc/          soc_top.v                    (N cores + bus + slaves)
sw/
  assembler/    rv32asm.py                   (RV32IMAC assembler)
  compiler/     rvcc.py                      (rudimentary C compiler)
  tests/        *.S, *.c                     (demo programs)
tb/
  tb_soc.v      self-checking SoC testbench (UART echo + GMII loopback)
  tb_uart.v     UART unit testbench
docs/           architecture, memory map, ISA notes
sim/files.f     source list for iverilog
Makefile        build + regression
```

See [`docs/`](docs) for the architecture, memory map, and ISA details.

---

## Design notes

### Pipeline
Classic 5-stage **IF → ID → EX → MEM → WB**. Instruction fetch reads a shared
multi-port ROM and never stalls; only data accesses contend for the bus.
Branches/jumps resolve in **EX** (2-cycle flush). Hazards are handled by:
- full **data forwarding** (EX→EX and MEM→EX),
- a **load/CSR-use interlock** (1-cycle stall),
- the register file's internal **write-through** (covers WB→ID).

### Precise traps
Exceptions (illegal, `ECALL`, `EBREAK`, misalignment) and interrupts are taken at
the EX boundary. Older in-flight instructions drain to completion, the faulting
instruction and everything younger are squashed, and `mepc`/`mcause`/`mtvec`
follow the RISC-V machine-mode model.

### Multi-core coherence
All harts share one SRAM through a single arbitrated bus, and there are **no
caches**, so the memory system is inherently sequentially consistent. Atomics are
implemented in the SRAM controller: because the arbiter grants one master per
single-beat transaction, an `AMO*` read-modify-write is indivisible. `LR/SC` use
a global reservation register keyed by `(master-id, address)` that is cleared by
any intervening write — giving correct store-conditional semantics across cores.

### On the original project
This is a **fork/rewrite** of `avolk201/Verilog-RISC-V-CPU`. The original
implemented a custom 16-bit ISA with several structural bugs (multiple drivers on
memory buses, ID-stage memory addressing, branch resolution against the wrong
zero flag, dead control FSM). Those were superseded by a standards-based RV32
core and a real SoC. The upstream repository is wired as the `upstream` git
remote for attribution and history.

---

## Status & scope

- Verified in simulation (Icarus Verilog 12). RTL is written in a
  synthesizable style but has not been mapped to a specific FPGA.
- Single-issue, in-order; `FENCE`/`FENCE.I` are treated as NOPs (valid because
  the shared-bus, cache-less memory system is already ordered).
- Ethernet is a simplified single-clock GMII-style MAC intended for
  functional simulation and loopback, not wire-compatible MII timing.
