//-----------------------------------------------------------------------------
// soc_bus.v - Shared system interconnect
//
// Arbitrates N core data-bus masters onto a set of memory-mapped slaves using a
// rotating-priority (round-robin) scheme. Because every slave acknowledges in a
// single cycle and only one master is granted at a time, single-beat AMO
// read-modify-write transactions are atomic across cores.
//
// Address map (selected by addr[31:16]):
//   0x8001_xxxx  SRAM   (data, atomics)
//   0x0200_xxxx  CLINT  (timer / software interrupts)
//   0x1000_xxxx  UART0
//   0x1001_xxxx  ETH0
//   otherwise    decoded as a no-op read (ack with zero) to avoid bus hangs
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module soc_bus #(
    parameter N = 2                       // number of bus masters (cores)
) (
    input                 clk,
    input                 rst,

    // ---- masters (flattened, index = core id) ----
    input      [N-1:0]    m_cyc,
    input      [N-1:0]    m_we,
    input      [N*32-1:0] m_addr,
    input      [N*32-1:0] m_wdata,
    input      [N*4-1:0]  m_be,
    input      [N*4-1:0]  m_amo,
    output     [N-1:0]    m_ack,
    output     [N*32-1:0] m_rdata,

    // ---- SRAM slave ----
    output                sram_cyc, sram_we,
    output     [31:0]     sram_addr, sram_wdata,
    output     [3:0]      sram_be, sram_amo,
    output     [7:0]      sram_master,
    input                 sram_ack,
    input      [31:0]     sram_rdata,

    // ---- CLINT slave ----
    output                clint_cyc, clint_we,
    output     [31:0]     clint_addr, clint_wdata,
    output     [3:0]      clint_be,
    input                 clint_ack,
    input      [31:0]     clint_rdata,

    // ---- UART slave ----
    output                uart_cyc, uart_we,
    output     [31:0]     uart_addr, uart_wdata,
    output     [3:0]      uart_be,
    input                 uart_ack,
    input      [31:0]     uart_rdata,

    // ---- Ethernet slave ----
    output                eth_cyc, eth_we,
    output     [31:0]     eth_addr, eth_wdata,
    output     [3:0]      eth_be,
    input                 eth_ack,
    input      [31:0]     eth_rdata
);
    localparam W = (N > 1) ? $clog2(N) : 1;

    // ---- rotating-priority arbiter ----
    reg [W-1:0] rr_ptr;
    reg [N-1:0] grant_oh;
    reg [W-1:0] grant_idx;
    reg         found;

    integer k;
    reg [W:0] idx;
    always @(*) begin
        grant_oh  = {N{1'b0}};
        grant_idx = {W{1'b0}};
        found     = 1'b0;
        for (k = 0; k < N; k = k + 1) begin
            idx = rr_ptr + k[W:0];
            if (idx >= N) idx = idx - N;
            if (!found && m_cyc[idx[W-1:0]]) begin
                grant_oh[idx[W-1:0]] = 1'b1;
                grant_idx            = idx[W-1:0];
                found                = 1'b1;
            end
        end
    end
    wire any_req = found;

    // ---- granted master's request ----
    wire [31:0] g_addr  = m_addr [grant_idx*32 +: 32];
    wire        g_we    = m_we   [grant_idx];
    wire [31:0] g_wdata = m_wdata[grant_idx*32 +: 32];
    wire [3:0]  g_be    = m_be   [grant_idx*4  +: 4];
    wire [3:0]  g_amo   = m_amo  [grant_idx*4  +: 4];

    // ---- address decode ----
    wire sel_sram  = (g_addr[31:16] == 16'h8001);
    wire sel_clint = (g_addr[31:16] == 16'h0200);
    wire sel_uart  = (g_addr[31:16] == 16'h1000);
    wire sel_eth   = (g_addr[31:16] == 16'h1001);
    wire sel_any   = sel_sram | sel_clint | sel_uart | sel_eth;

    // ---- drive slaves ----
    assign sram_cyc    = any_req & sel_sram;
    assign sram_we     = g_we;
    assign sram_addr   = g_addr;
    assign sram_wdata  = g_wdata;
    assign sram_be     = g_be;
    assign sram_amo    = g_amo;
    assign sram_master = {{(8-W){1'b0}}, grant_idx};

    assign clint_cyc   = any_req & sel_clint;
    assign clint_we    = g_we;
    assign clint_addr  = g_addr;
    assign clint_wdata = g_wdata;
    assign clint_be    = g_be;

    assign uart_cyc    = any_req & sel_uart;
    assign uart_we     = g_we;
    assign uart_addr   = g_addr;
    assign uart_wdata  = g_wdata;
    assign uart_be     = g_be;

    assign eth_cyc     = any_req & sel_eth;
    assign eth_we      = g_we;
    assign eth_addr    = g_addr;
    assign eth_wdata   = g_wdata;
    assign eth_be      = g_be;

    // ---- collect slave response ----
    wire        sel_ack   = (sel_sram  & sram_ack)  | (sel_clint & clint_ack) |
                            (sel_uart  & uart_ack)  | (sel_eth   & eth_ack)   |
                            (any_req & ~sel_any);   // default: ack with zero
    wire [31:0] sel_rdata = sel_sram  ? sram_rdata  :
                            sel_clint ? clint_rdata :
                            sel_uart  ? uart_rdata  :
                            sel_eth   ? eth_rdata   : 32'b0;

    // ---- route response back to the granted master ----
    assign m_ack = (any_req & sel_ack) ? grant_oh : {N{1'b0}};

    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : g_rdata
            assign m_rdata[gi*32 +: 32] = grant_oh[gi] ? sel_rdata : 32'b0;
        end
    endgenerate

    // ---- advance round-robin pointer after a completed transfer ----
    always @(posedge clk) begin
        if (rst) rr_ptr <= {W{1'b0}};
        else if (any_req & sel_ack) begin
            if (grant_idx == N-1) rr_ptr <= {W{1'b0}};
            else                  rr_ptr <= grant_idx + 1'b1;
        end
    end
endmodule
