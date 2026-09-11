# Architecture

## Overview

`soc_top` integrates `NUM_CORES` identical RV32IMAC harts with a shared
instruction ROM, an arbitrated data bus, shared SRAM, and memory-mapped
peripherals (CLINT, UART, Ethernet). It is a symmetric-multiprocessing (SMP)
design: every hart runs the same image from the shared ROM and is distinguished
only by its `mhartid`.

```
            +-------------------+        +-------------------+
 ifetch ----| rv32_core (hart0) |        |   boot_rom        |
 (dedicated|  IF ID EX MEM WB   |<------>|  NUM_PORTS reads  |
  port)    +---------+---------+ addr   +-------------------+
                     | data bus (valid/ack)
                     v
            +-------------------+
            |      soc_bus      |   rotating-priority arbiter
            |  arbiter+decoder  |   + address decode
            +--+-----+----+--+--+
               |     |    |  |
            +--+ +---+ +--+ +---+
            |SRAM|CLINT| |UART|ETH|
            +----+-----+ +----+---+
```

## The core (`rtl/core/rv32_core.v`)

Five stages, in order, single-issue:

1. **IF** — PC drives a dedicated ROM read port. Fetch is asynchronous and
   **never stalls** (reads don’t contend).
2. **ID** — decode (`rv32_decoder`), immediate generation (`rv32_immgen`),
   register read (`rv32_regfile`, 2R1W with write-through), hazard detection.
3. **EX** — ALU (`rv32_alu`), branch condition and target, jump target,
   address generation, exception detection, CSR access.
4. **MEM** — data-bus transaction (load/store/atomic); the pipeline freezes
   while the transfer is outstanding.
5. **WB** — write-back mux (ALU / load / PC+4 / CSR) into the register file.

### Hazard handling
- **Forwarding**: EX→EX (from the EX/MEM register) and MEM→EX (from MEM/WB).
- **Load/CSR-use interlock**: a 1-cycle stall when an EX-stage load/atomic/CSR
  feeds the ID-stage instruction’s operands.
- **Write-through register file**: a WB-stage write is visible to an ID-stage
  read in the same cycle, covering the remaining distance.
- **Control**: branches/jumps resolve in EX and flush the two younger slots
  (`if_id`, `id_ex`).

### Data bus protocol
A single-beat valid/ack handshake:

| Signal | Dir | Meaning |
|---|---|---|
| `d_cyc` | out | transfer in progress (held until `d_ack`) |
| `d_we` | out | write |
| `d_addr`,`d_wdata`,`d_be` | out | address, data, byte enables |
| `d_amo` | out | atomic op code (0 = none) |
| `d_ack` | in | transfer complete this cycle |
| `d_rdata` | in | read data / AMO old value / SC result |

`d_cyc & ~d_ack` freezes the whole pipeline (`stall_mem`).

### Traps
Exceptions and interrupts are taken **precisely at the EX boundary**:
instructions older than EX drain and retire; the EX instruction and all younger
ones are squashed; `mepc` = the EX instruction’s PC; PC → `mtvec`. `MRET`
restores PC from `mepc` and re-enables interrupts via `MPIE`. Interrupts are
suppressed while a memory transaction is outstanding to keep traps precise.

## Interconnect (`rtl/interconnect/soc_bus.v`)

A rotating-priority (round-robin) arbiter selects one requesting master per
cycle and routes it to the addressed slave. Because each transfer completes in
one cycle and only one master is ever connected, a single-beat AMO
read-modify-write at the SRAM is **atomic** with respect to all other harts.

## Shared memory & atomics (`rtl/mem/sram.v`)

- Byte-lane writes via `be`.
- AMOs computed in the controller (swap/add/and/or/xor/min/max[u]).
- `LR/SC` use one global reservation `(valid, master-id, word-address)`:
  - `LR.W` sets the reservation and returns the word.
  - `SC.W` writes and returns `0` (success) only if the reservation still
    matches this master and address; otherwise returns `1` (failure).
  - Any write to the reserved word (by any master) clears the reservation.

There are **no caches**, so the memory system is inherently sequentially
consistent and `FENCE` is unnecessary for correctness.

## Instruction memory (`rtl/mem/boot_rom.v`)

A single physical ROM with `NUM_CORES` asynchronous read ports (one per hart),
so all cores execute the same shared image with no fetch arbitration.
Unprogrammed words default to `addi x0,x0,0` (NOP).

## Peripherals
- **CLINT** (`clint.v`): per-hart `mtimecmp`/`msip`, global `mtime`; drives
  timer and software interrupts. External device IRQs are steered to hart 0.
- **UART** (`uart.v`): 16550-lite with a baud generator, TX/RX FIFOs, LSR, and
  interrupts. Real serial lines; the testbench loops `tx → rx`.
- **Ethernet** (`eth_mac.v`): GMII-style MAC with TX/RX frame buffers,
  preamble/SFD insertion, CRC-32 (`eth_crc32.vh`) generation and validation.
  The testbench loops `gmii_tx → gmii_rx`.

## Reset
All harts start at `RESET_VECTOR` (`0x8000_0000`). `mstatus` resets to
`MPP=machine`, interrupts disabled, `mtvec=0`.
