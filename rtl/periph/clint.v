//-----------------------------------------------------------------------------
// clint.v - Core-Local Interruptor (SiFive-compatible layout)
//
// Provides per-hart machine timer interrupts (mtime / mtimecmp) and machine
// software interrupts (msip) used for inter-core IPIs. mtime is also exposed to
// the cores so the `time` CSR reflects it.
//
// Offset map (within the CLINT region):
//   0x0000 + 4*h : msip[h]      (software interrupt pending, RW)
//   0x4000 + 8*h : mtimecmp[h]  (64-bit, RW; low @ +0, high @ +4)
//   0xBFF8       : mtime        (64-bit, RO here; low @ BFF8, high @ BFFC)
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

/* verilator lint_off WIDTHTRUNC */
module clint #(
    parameter NUM_HARTS = 2
) (
    input                 clk,
    input                 rst,

    input                 s_cyc,
    input                 s_we,
    input      [31:0]     s_addr,
    input      [31:0]     s_wdata,
    input      [3:0]      s_be,
    output                s_ack,
    output reg [31:0]     s_rdata,

    output reg [63:0]     mtime,
    output     [NUM_HARTS-1:0] irq_timer,
    output     [NUM_HARTS-1:0] irq_software
);
    reg [63:0] mtimecmp [0:NUM_HARTS-1];
    reg [NUM_HARTS-1:0] msip;

    integer i;
    initial begin
        mtime = 64'b0;
        msip  = {NUM_HARTS{1'b0}};
        for (i = 0; i < NUM_HARTS; i = i + 1) mtimecmp[i] = 64'hFFFFFFFF_FFFFFFFF;
    end

    assign s_ack = s_cyc;

    wire [15:0] off = s_addr[15:0];
    wire is_msip     = (off < 16'h4000);
    wire is_mtimecmp = (off >= 16'h4000) && (off < 16'hBFF8);
    wire is_mtime    = (off >= 16'hBFF8);

    wire [7:0] hart_msip = off[9:2];                  // off = 4*h
    wire [15:0] cmp_off   = off - 16'h4000;
    wire [7:0] hart_cmp   = cmp_off[10:3];            // off = 8*h (+4 for high)
    wire       cmp_hi     = off[2];

    // ---- read mux ----
    always @(*) begin
        s_rdata = 32'b0;
        if (is_mtime) begin
            s_rdata = off[2] ? mtime[63:32] : mtime[31:0];
        end else if (is_mtimecmp) begin
            if (hart_cmp < NUM_HARTS)
                s_rdata = cmp_hi ? mtimecmp[hart_cmp][63:32] : mtimecmp[hart_cmp][31:0];
        end else if (is_msip) begin
            if (hart_msip < NUM_HARTS)
                s_rdata = {{31{1'b0}}, msip[hart_msip]};
        end
    end

    integer j;
    // ---- write / tick ----
    always @(posedge clk) begin
        if (rst) begin
            mtime <= 64'b0;
            msip  <= {NUM_HARTS{1'b0}};
            for (j = 0; j < NUM_HARTS; j = j + 1) mtimecmp[j] <= 64'hFFFFFFFF_FFFFFFFF;
        end else begin
            mtime <= mtime + 64'd1;
            if (s_cyc & s_we) begin
                if (is_mtimecmp && (hart_cmp < NUM_HARTS)) begin
                    if (cmp_hi) mtimecmp[hart_cmp][63:32] <= s_wdata;
                    else        mtimecmp[hart_cmp][31:0]  <= s_wdata;
                end else if (is_msip && (hart_msip < NUM_HARTS)) begin
                    msip[hart_msip] <= s_wdata[0];
                end
            end
        end
    end

    // ---- interrupt generation ----
    genvar h;
    generate
        for (h = 0; h < NUM_HARTS; h = h + 1) begin : g_irq
            assign irq_timer[h]    = (mtime >= mtimecmp[h]);
            assign irq_software[h] = msip[h];
        end
    endgenerate
endmodule
/* verilator lint_on WIDTHTRUNC */
