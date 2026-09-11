# Memory Map

All addresses are 32-bit. The interconnect (`soc_bus`) decodes on `addr[31:16]`.

| Region | Base | Size | Access | Description |
|---|---|---|---|---|
| Boot ROM | `0x8000_0000` | 64 KiB | R / X | Shared instruction memory (multi read port). Reset vector. |
| Data SRAM | `0x8001_0000` | 64 KiB | R/W/A | Shared data memory; supports RV32A atomics. |
| CLINT | `0x0200_0000` | 64 KiB | R/W | Timer + software interrupts. |
| UART0 | `0x1000_0000` | 64 KiB | R/W | 16550-style serial port. |
| ETH0 | `0x1001_0000` | 64 KiB | R/W | Ethernet MAC. |

Unmapped addresses acknowledge with zero data (no bus hang).

## Conventions used by the test software

| Symbol | Address | Purpose |
|---|---|---|
| `tohost` | `0x8001_FFF0` | Test result word polled by the testbench. `0x600D600D` = PASS; `0xBAD000xx` = FAIL. |

## CLINT (`0x0200_0000`)

SiFive-compatible layout (offset within region):

| Offset | Width | Name | Description |
|---|---|---|---|
| `0x0000 + 4*h` | 32 | `msip[h]` | Machine software interrupt pending for hart `h` (write 1/0). |
| `0x4000 + 8*h` | 64 | `mtimecmp[h]` | Timer compare; timer IRQ when `mtime >= mtimecmp[h]`. |
| `0xBFF8` | 64 | `mtime` | Free-running machine time (also readable via the `time` CSR). |

## UART0 (`0x1000_0000`)

16550-lite, 8N1. `LCR.DLAB` (bit 7) switches offsets 0/4 between data and divisor.

| Offset | DLAB=0 | DLAB=1 |
|---|---|---|
| `0x00` | RBR (read) / THR (write) | DLL (divisor low) |
| `0x04` | IER | DLM (divisor high) |
| `0x08` | IIR (read) / FCR (write) | — |
| `0x0C` | LCR (line control) | — |
| `0x14` | LSR (line status) | — |

LSR bits: `[0]` data ready (RX FIFO non-empty), `[5]` THRE (TX FIFO empty),
`[6]` TEMT (transmitter idle). The bit period equals `divisor` clock cycles.

IER bits: `[0]` RX-data interrupt enable, `[1]` TX-empty interrupt enable.

## ETH0 (`0x1001_0000`)

| Offset | Name | Description |
|---|---|---|
| `0x00` | CTRL | `[0]` enable, `[1]` start_tx (self-clearing), `[2]` soft_reset |
| `0x04` | STATUS | `[0]` tx_busy, `[1]` rx_avail, `[2]` tx_done, `[3]` rx_ok, `[4]` rx_err |
| `0x08` | TXLEN | Bytes staged in the TX buffer to transmit |
| `0x0C` | RXLEN | Bytes available in the RX buffer (excludes FCS) |
| `0x10` | IRQSTAT | `[0]` tx_done, `[1]` rx (write-1-clear) |
| `0x14` | IRQMASK | Interrupt mask |
| `0x20` | TXDATA | Write a byte (auto-increment) into the TX frame buffer |
| `0x24` | RXDATA | Read a byte (auto-increment) from the RX frame buffer |

The MAC prepends preamble+SFD and appends a CRC-32 FCS on transmit, and strips
and validates them on receive. The GMII interface is single-clock and intended
for functional simulation / loopback.
