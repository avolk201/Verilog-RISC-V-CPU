# Instruction Set

The core implements **RV32IMAC** (32-bit base integer `I`, multiply/divide `M`,
atomics `A`, machine-mode `C`SR/privilege). It is a 32-bit, little-endian,
in-order, single-issue machine.

## RV32I base

| Category | Instructions |
|---|---|
| Arithmetic | `ADD` `SUB` `ADDI` `LUI` `AUIPC` |
| Logical | `AND` `OR` `XOR` `ANDI` `ORI` `XORI` |
| Shifts | `SLL` `SRL` `SRA` `SLLI` `SRLI` `SRAI` |
| Compare | `SLT` `SLTU` `SLTI` `SLTIU` |
| Load | `LB` `LH` `LW` `LBU` `LHU` |
| Store | `SB` `SH` `SW` |
| Branch | `BEQ` `BNE` `BLT` `BGE` `BLTU` `BGEU` |
| Jump | `JAL` `JALR` |
| System | `ECALL` `EBREAK` `MRET` `WFI`* |
| Memory ordering | `FENCE`* |

\* `WFI` and `FENCE`/`FENCE.I` are accepted and treated as hints/NOPs. This is
correct here because the shared-bus, cache-less memory system is already
sequentially consistent and interrupts are polled at instruction boundaries.

## M extension (multiply/divide)

`MUL` `MULH` `MULHSU` `MULHU` `DIV` `DIVU` `REM` `REMU`

Division-by-zero follows the spec (`DIV/REM` → `-1`/dividend,
`DIVU/REMU` → all-ones/dividend). Multiply/divide are single-cycle behavioural
(for simulation); a real FPGA build would pipeline a divider.

## A extension (atomics, word only)

`LR.W` `SC.W` `AMOSWAP.W` `AMOADD.W` `AMOAND.W` `AMOOR.W` `AMOXOR.W`
`AMOMIN.W` `AMOMAX.W` `AMOMINU.W` `AMOMAXU.W`

Atomics execute as a single indivisible bus transaction at the SRAM controller.
`LR/SC` use a global reservation `(master-id, word-address)` cleared by any
intervening write, giving correct store-conditional behaviour across cores.
`SC.W` writes `0` to `rd` on success and `1` on failure.

## Machine-mode CSRs

| CSR | Addr | Notes |
|---|---|---|
| `mstatus` | `0x300` | `MIE`(3), `MPIE`(7), `MPP`(12:11) implemented |
| `misa` | `0x301` | Read-only: RV32 I·M·A |
| `mie` | `0x304` | `MSIE`(3), `MTIE`(7), `MEIE`(9) |
| `mtvec` | `0x305` | Trap vector base (direct mode) |
| `mscratch` | `0x340` | |
| `mepc` | `0x341` | |
| `mcause` | `0x342` | |
| `mtval` | `0x343` | |
| `mip` | `0x344` | Reflects CLINT/external interrupt inputs |
| `mcycle`/`mcycleh` | `0xB00`/`0xB80` | 64-bit cycle counter |
| `minstret`/`minstreth` | `0xB02`/`0xB82` | 64-bit retired-instruction counter |
| `cycle`/`time`/`instret` | `0xC00`/`0xC01`/`0xC02` | Read-only shadows (`time` = CLINT `mtime`) |
| `mhartid` | `0xF14` | Hart id (core index) |

CSR instructions: `CSRRW` `CSRRS` `CSRRC` `CSRRWI` `CSRRSI` `CSRRCI`.

### Traps

| Cause | `mcause` | Trigger |
|---|---|---|
| Illegal instruction | 2 | Undecoded opcode (note: `0x00000000` is treated as NOP) |
| Breakpoint | 3 | `EBREAK` |
| Load address misaligned | 4 | Misaligned `LH`/`LW` |
| Store address misaligned | 6 | Misaligned `SH`/`SW` |
| Env. call from M-mode | 11 | `ECALL` |
| Machine software int. | `0x80000003` | CLINT `msip` |
| Machine timer int. | `0x80000007` | `mtime >= mtimecmp` |
| Machine external int. | `0x8000000B` | UART/ETH (routed to hart 0) |

Interrupts are enabled by `mstatus.MIE` together with the relevant `mie` bit.

## Assembler pseudo-ops

`nop` `li` `la` `mv` `not` `neg` `seqz` `snez` `sltz` `sgtz` `beqz` `bnez`
`blez` `bgez` `bltz` `bgtz` `j` `jr` `ret` `call` `csrr` `csrw`

Directives: `.text` `.data` `.org` `.align` `.word` `.half`/`.short` `.byte`
`.space`/`.skip`/`.zero` `.ascii` `.asciz` `.globl` `.equ`/`.set`. Labels are
case-sensitive; `.equ` names are case-insensitive. Operands accept arithmetic
expressions over numbers, labels, and `.equ` constants (e.g. `NCORES*ITER`).
