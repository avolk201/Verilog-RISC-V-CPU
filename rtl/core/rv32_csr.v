//-----------------------------------------------------------------------------
// rv32_csr.v - RISC-V machine-mode control & status registers
// Implements the subset of M-mode CSRs required to run privileged firmware and
// service interrupts/exceptions: mstatus, misa, mie, mtvec, mscratch, mepc,
// mcause, mtval, mip, mcycle/minstret (+ read-only shadows) and mhartid.
//
// The block also contains the trap-entry / mret side effects so the core only
// needs to pulse `trap_en` / `mret_en` and supply the cause and PC.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module rv32_csr #(
    parameter HART_ID = 0
) (
    input              clk,
    input              rst,

    // CSR read/modify/write from the pipeline
    input              csr_en,        // this instruction accesses a CSR
    input  [1:0]       csr_op,        // CSR_RW/RS/RC (0 = none/read-only)
    input  [11:0]      csr_addr,
    input  [31:0]      csr_wdata,     // rs1 value or zero-extended imm
    input              csr_do_write,  // qualify: CSRRS/C with rs1=x0 must not write
    output reg [31:0]  csr_rdata,

    // Trap interface (from core)
    input              trap_en,
    input              trap_interrupt,   // 1 = interrupt, 0 = exception
    input  [31:0]      trap_cause,
    input  [31:0]      trap_tval,
    input  [31:0]      trap_pc,          // PC to resume (mepc)
    output reg [31:0]  mtvec,
    output reg [31:0]  mepc,
    output reg [31:0]  mstatus,          // exposed for the core's MIE bit

    input              mret_en,

    // Interrupt sources (active-high, level)
    input              irq_software,
    input              irq_timer,
    input              irq_external,

    // Performance counters
    input              instret_inc,      // pulse: one instruction retired
    input  [63:0]      mtime_in,         // CLINT mtime (for `time` CSR)

    // Interrupt request to the core
    output             take_interrupt,
    output reg [31:0]  int_cause
);
    localparam CSR_RW = 2'd1, CSR_RS = 2'd2, CSR_RC = 2'd3;

    // CSR addresses
    localparam A_MSTATUS  = 12'h300, A_MISA = 12'h301, A_MIE = 12'h304,
               A_MTVEC    = 12'h305, A_MSCRATCH = 12'h340, A_MEPC = 12'h341,
               A_MCAUSE   = 12'h342, A_MTVAL = 12'h343, A_MIP = 12'h344,
               A_MCYCLE   = 12'hB00, A_MINSTRET = 12'hB02,
               A_MCYCLEH  = 12'hB80, A_MINSTRETH = 12'hB82,
               A_CYCLE    = 12'hC00, A_TIME = 12'hC01, A_INSTRET = 12'hC02,
               A_MHARTID  = 12'hF14;

    localparam MISA_VALUE = 32'h4000_1101; // RV32 I M A, MXL = 1 (32-bit)

    reg [31:0] misa_r      = MISA_VALUE;
    reg [31:0] mie         = 32'b0;
    reg [31:0] mscratch    = 32'b0;
    reg [31:0] mcause      = 32'b0;
    reg [31:0] mtval       = 32'b0;
    reg [63:0] mcycle      = 64'b0;
    reg [63:0] minstret    = 64'b0;

    // mip: software/timer/external pending (bit 3 / 7 / 9)
    wire [31:0] mip = {22'b0, irq_external, 1'b0, irq_timer,
                       3'b0, irq_software, 3'b0};

    // ---- Interrupt arbitration -------------------------------------------
    wire m_mie = mstatus[3];
    wire pending_ext = mie[9] & mip[9];
    wire pending_sw  = mie[3] & mip[3];
    wire pending_tim = mie[7] & mip[7];

    assign take_interrupt = m_mie & (pending_ext | pending_sw | pending_tim);

    always @(*) begin
        if (pending_ext)      int_cause = {1'b1, 31'd11}; // machine external
        else if (pending_sw)  int_cause = {1'b1, 31'd3};  // machine software
        else                  int_cause = {1'b1, 31'd7};  // machine timer
    end

    // ---- CSR read mux -----------------------------------------------------
    always @(*) begin
        case (csr_addr)
            A_MSTATUS:  csr_rdata = mstatus;
            A_MISA:     csr_rdata = misa_r;
            A_MIE:      csr_rdata = mie;
            A_MTVEC:    csr_rdata = mtvec;
            A_MSCRATCH: csr_rdata = mscratch;
            A_MEPC:     csr_rdata = mepc;
            A_MCAUSE:   csr_rdata = mcause;
            A_MTVAL:    csr_rdata = mtval;
            A_MIP:      csr_rdata = mip;
            A_MCYCLE:   csr_rdata = mcycle[31:0];
            A_MCYCLEH:  csr_rdata = mcycle[63:32];
            A_MINSTRET: csr_rdata = minstret[31:0];
            A_MINSTRETH:csr_rdata = minstret[63:32];
            A_CYCLE:    csr_rdata = mcycle[31:0];
            A_TIME:     csr_rdata = mtime_in[31:0];
            A_INSTRET:  csr_rdata = minstret[31:0];
            A_MHARTID:  csr_rdata = HART_ID;
            default:    csr_rdata = 32'b0;
        endcase
    end

    // ---- Write value computation -----------------------------------------
    reg [31:0] csr_new;
    always @(*) begin
        case (csr_op)
            CSR_RW: csr_new = csr_wdata;
            CSR_RS: csr_new = csr_rdata |  csr_wdata;
            CSR_RC: csr_new = csr_rdata & ~csr_wdata;
            default:csr_new = csr_rdata;
        endcase
    end

    wire do_write = csr_en & csr_do_write;

    // ---- Sequential update ------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            mstatus  <= 32'h0000_1800; // MPP = 11 (machine) on reset
            mtvec    <= 32'b0;
            mepc     <= 32'b0;
            mie      <= 32'b0;
            mscratch <= 32'b0;
            mcause   <= 32'b0;
            mtval    <= 32'b0;
            mcycle   <= 64'b0;
            minstret <= 64'b0;
        end else begin
            mcycle <= mcycle + 64'd1;
            if (instret_inc) minstret <= minstret + 64'd1;

            // Trap entry has priority over mret and CSR writes to the same regs.
            if (trap_en) begin
                mepc    <= trap_pc;
                mcause  <= trap_cause;
                mtval   <= trap_tval;
                mstatus[7]  <= mstatus[3]; // MPIE <= MIE
                mstatus[3]  <= 1'b0;       // MIE  <= 0
                mstatus[12:11] <= 2'b11;   // MPP  <= machine
            end else if (mret_en) begin
                mstatus[3]     <= mstatus[7]; // MIE  <= MPIE
                mstatus[7]     <= 1'b1;       // MPIE <= 1
                mstatus[12:11] <= 2'b11;      // MPP  <= machine
            end else if (do_write) begin
                case (csr_addr)
                    A_MSTATUS: begin
                        // Only the implemented fields are writable.
                        mstatus[3]    <= csr_new[3];    // MIE
                        mstatus[7]    <= csr_new[7];    // MPIE
                        mstatus[12:11]<= csr_new[12:11];// MPP
                    end
                    A_MIE:      mie      <= csr_new;
                    A_MTVEC:    mtvec    <= csr_new;
                    A_MSCRATCH: mscratch <= csr_new;
                    A_MEPC:     mepc     <= {csr_new[31:2], 2'b00}; // word aligned
                    A_MCAUSE:   mcause   <= csr_new;
                    A_MTVAL:    mtval    <= csr_new;
                    A_MCYCLE:   mcycle[31:0]   <= csr_new;
                    A_MCYCLEH:  mcycle[63:32]  <= csr_new;
                    A_MINSTRET: minstret[31:0] <= csr_new;
                    A_MINSTRETH:minstret[63:32]<= csr_new;
                    default: ; // read-only or unimplemented: ignore writes
                endcase
            end
        end
    end
endmodule
