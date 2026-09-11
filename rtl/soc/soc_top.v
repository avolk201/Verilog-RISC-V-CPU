//-----------------------------------------------------------------------------
// soc_top.v - Multi-core RV32IMAC System-on-Chip
//
//   NUM_CORES x rv32_core  --+--> shared instruction ROM (multi read port)
//                            \--> arbitrated data bus (soc_bus)
//                                  |-- SRAM   (0x8001_xxxx) shared data + atomics
//                                  |-- CLINT  (0x0200_xxxx) timer / software IRQ
//                                  |-- UART0  (0x1000_xxxx) serial console
//                                  |-- ETH0   (0x1001_xxxx) Ethernet MAC (GMII)
//
// All cores run the same image from the shared ROM and are distinguished by
// mhartid. Cross-core synchronisation uses RV32A atomics on the shared SRAM.
// External device interrupts (UART/ETH) are routed to hart 0; the CLINT drives
// per-hart timer and software (IPI) interrupts.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module soc_top #(
    parameter NUM_CORES  = 2,
    parameter ROM_DEPTH  = 16384,          // words (64 KiB)
    parameter RAM_DEPTH  = 16384,          // words (64 KiB)
    parameter ROM_FILE   = "sw/tests/program.rom.hex",
    parameter RAM_FILE   = "",
    parameter RESET_VEC  = 32'h8000_0000
) (
    input                 clk,
    input                 rst,

    // UART0 serial lines
    input                 uart_rx,
    output                uart_tx,
    output                uart_irq,

    // ETH0 GMII-style media interface
    output                eth_tx_en,
    output [7:0]          eth_tx_data,
    input                 eth_rx_dv,
    input  [7:0]          eth_rx_data,
    output                eth_irq
);
    // ---------------- per-core interconnect wiring ----------------
    wire [NUM_CORES-1:0]     c_d_cyc, c_d_we, c_d_ack;
    wire [NUM_CORES*32-1:0]  c_d_addr, c_d_wdata, c_d_rdata;
    wire [NUM_CORES*4-1:0]   c_d_be, c_d_amo;
    wire [NUM_CORES*32-1:0]  c_if_addr, c_if_data;

    // ---------------- interrupt wiring ----------------
    wire [NUM_CORES-1:0] irq_timer, irq_software;
    wire [63:0]          mtime;
    wire                 uart_irq_w, eth_irq_w;

    assign uart_irq = uart_irq_w;
    assign eth_irq  = eth_irq_w;

    // ---------------- cores ----------------
    genvar ci;
    generate
        for (ci = 0; ci < NUM_CORES; ci = ci + 1) begin : g_core
            wire core_busy_w;
            rv32_core #(
                .HART_ID      (ci),
                .RESET_VECTOR (RESET_VEC)
            ) CORE (
                .clk(clk), .rst(rst),
                .ifetch_addr (c_if_addr[ci*32 +: 32]),
                .ifetch_data (c_if_data[ci*32 +: 32]),
                .d_cyc  (c_d_cyc[ci]),
                .d_we   (c_d_we[ci]),
                .d_addr (c_d_addr[ci*32 +: 32]),
                .d_wdata(c_d_wdata[ci*32 +: 32]),
                .d_be   (c_d_be[ci*4 +: 4]),
                .d_amo  (c_d_amo[ci*4 +: 4]),
                .d_ack  (c_d_ack[ci]),
                .d_rdata(c_d_rdata[ci*32 +: 32]),
                .irq_software (irq_software[ci]),
                .irq_timer    (irq_timer[ci]),
                // External device interrupts are steered to hart 0 only.
                .irq_external ((ci==0) ? (uart_irq_w | eth_irq_w) : 1'b0),
                .mtime_in     (mtime),
                .core_busy    (core_busy_w)
            );
        end
    endgenerate

    // ---------------- shared instruction ROM ----------------
    boot_rom #(
        .DEPTH     (ROM_DEPTH),
        .NUM_PORTS (NUM_CORES),
        .MEMFILE   (ROM_FILE)
    ) ROM (
        .addr  (c_if_addr),
        .instr (c_if_data)
    );

    // ---------------- interconnect ----------------
    wire        sram_cyc, sram_we, sram_ack;
    wire [31:0] sram_addr, sram_wdata, sram_rdata;
    wire [3:0]  sram_be, sram_amo;
    wire [7:0]  sram_master;

    wire        clint_cyc, clint_we, clint_ack;
    wire [31:0] clint_addr, clint_wdata, clint_rdata;
    wire [3:0]  clint_be;

    wire        uart_cyc, uart_we, uart_ack;
    wire [31:0] uart_addr, uart_wdata, uart_rdata;
    wire [3:0]  uart_be;

    wire        eth_cyc, eth_we, eth_ack;
    wire [31:0] eth_addr, eth_wdata, eth_rdata;
    wire [3:0]  eth_be;

    soc_bus #(.N(NUM_CORES)) BUS (
        .clk(clk), .rst(rst),
        .m_cyc(c_d_cyc), .m_we(c_d_we),
        .m_addr(c_d_addr), .m_wdata(c_d_wdata),
        .m_be(c_d_be), .m_amo(c_d_amo),
        .m_ack(c_d_ack), .m_rdata(c_d_rdata),
        .sram_cyc(sram_cyc), .sram_we(sram_we), .sram_addr(sram_addr),
        .sram_wdata(sram_wdata), .sram_be(sram_be), .sram_amo(sram_amo),
        .sram_master(sram_master), .sram_ack(sram_ack), .sram_rdata(sram_rdata),
        .clint_cyc(clint_cyc), .clint_we(clint_we), .clint_addr(clint_addr),
        .clint_wdata(clint_wdata), .clint_be(clint_be),
        .clint_ack(clint_ack), .clint_rdata(clint_rdata),
        .uart_cyc(uart_cyc), .uart_we(uart_we), .uart_addr(uart_addr),
        .uart_wdata(uart_wdata), .uart_be(uart_be),
        .uart_ack(uart_ack), .uart_rdata(uart_rdata),
        .eth_cyc(eth_cyc), .eth_we(eth_we), .eth_addr(eth_addr),
        .eth_wdata(eth_wdata), .eth_be(eth_be),
        .eth_ack(eth_ack), .eth_rdata(eth_rdata)
    );

    // ---------------- slaves ----------------
    sram #(.DEPTH(RAM_DEPTH), .MEMFILE(RAM_FILE)) RAM (
        .clk(clk),
        .s_cyc(sram_cyc), .s_we(sram_we), .s_addr(sram_addr),
        .s_wdata(sram_wdata), .s_be(sram_be), .s_amo(sram_amo),
        .s_master(sram_master), .s_ack(sram_ack), .s_rdata(sram_rdata)
    );

    clint #(.NUM_HARTS(NUM_CORES)) CLINT (
        .clk(clk), .rst(rst),
        .s_cyc(clint_cyc), .s_we(clint_we), .s_addr(clint_addr),
        .s_wdata(clint_wdata), .s_be(clint_be),
        .s_ack(clint_ack), .s_rdata(clint_rdata),
        .mtime(mtime), .irq_timer(irq_timer), .irq_software(irq_software)
    );

    uart UART0 (
        .clk(clk), .rst(rst),
        .s_cyc(uart_cyc), .s_we(uart_we), .s_addr(uart_addr),
        .s_wdata(uart_wdata), .s_be(uart_be),
        .s_ack(uart_ack), .s_rdata(uart_rdata),
        .rx(uart_rx), .tx(uart_tx), .irq(uart_irq_w)
    );

    eth_mac ETH0 (
        .clk(clk), .rst(rst),
        .s_cyc(eth_cyc), .s_we(eth_we), .s_addr(eth_addr),
        .s_wdata(eth_wdata), .s_be(eth_be),
        .s_ack(eth_ack), .s_rdata(eth_rdata),
        .gmii_tx_en(eth_tx_en), .gmii_tx_data(eth_tx_data),
        .gmii_rx_dv(eth_rx_dv), .gmii_rx_data(eth_rx_data),
        .irq(eth_irq_w)
    );
endmodule
