//-----------------------------------------------------------------------------
// rv32_core.v - 5-stage pipelined RV32IMAC machine-mode core
//
// Pipeline: IF -> ID -> EX -> MEM -> WB
//   * IF reads a shared instruction ROM through a dedicated per-core port, so
//     instruction fetch never stalls (reads do not contend on the data bus).
//   * Branches/jumps resolve in EX (2-cycle flush penalty).
//   * Full data forwarding (EX->EX, MEM->EX), a load/CSR-use interlock, and the
//     register file's internal write-through cover every RAW distance.
//   * A single data-bus master issues loads/stores/atomics; the pipeline
//     freezes while the transaction is outstanding (valid/ack handshake).
//   * Precise machine-mode traps (exceptions + interrupts) are taken at the EX
//     boundary: older in-flight instructions drain, the faulting instruction
//     and all younger ones are squashed, PC redirects to mtvec.
//
// The data bus uses a simple single-beat valid/ack protocol so the core can be
// attached directly to the shared interconnect.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module rv32_core #(
    parameter HART_ID      = 0,
    parameter RESET_VECTOR = 32'h8000_0000
) (
    input              clk,
    input              rst,

    // Instruction fetch port (dedicated, asynchronous, never stalls)
    output     [31:0]  ifetch_addr,
    input      [31:0]  ifetch_data,

    // Data bus master (valid/ack single beat)
    output reg         d_cyc,      // transaction in progress (held until ack)
    output reg         d_we,       // 1 = write
    output reg [31:0]  d_addr,
    output reg [31:0]  d_wdata,
    output reg [3:0]   d_be,       // byte enables
    output reg [3:0]   d_amo,      // AMO_* (0 = none)
    input              d_ack,      // transfer complete this cycle
    input      [31:0]  d_rdata,    // read data / old value (AMO) / SC result

    // Interrupts
    input              irq_software,
    input              irq_timer,
    input              irq_external,
    input      [63:0]  mtime_in,

    // Status
    output             core_busy
);
    // ----- shared encodings -------------------------------------------------
    localparam WB_ALU=2'd0, WB_LOAD=2'd1, WB_PC4=2'd2, WB_CSR=2'd3;
    localparam CSR_NONE=2'd0, CSR_RW=2'd1;
    localparam AMO_NONE=4'd0, AMO_LR=4'd1;

    localparam OP_LUI=7'b0110111, OP_AUIPC=7'b0010111, OP_JAL=7'b1101111,
               OP_JALR=7'b1100111, OP_BRANCH=7'b1100011, OP_LOAD=7'b0000011,
               OP_STORE=7'b0100011, OP_OP=7'b0110011, OP_AMO=7'b0101111;

    localparam EXC_ILLEGAL=32'd2, EXC_BREAK=32'd3, EXC_LOAD_MIS=32'd4,
               EXC_STORE_MIS=32'd6, EXC_ECALL_M=32'd11;

    // =======================================================================
    // IF
    // =======================================================================
    reg  [31:0] pc_q;
    assign ifetch_addr = pc_q;
    wire [31:0] fetch_instr = ifetch_data;

    reg         ifid_valid;
    reg  [31:0] ifid_pc, ifid_instr;

    // =======================================================================
    // ID : decode + register read
    // =======================================================================
    wire [6:0] id_opcode = ifid_instr[6:0];
    wire [4:0] id_rs1 = ifid_instr[19:15];
    wire [4:0] id_rs2 = ifid_instr[24:20];
    wire [4:0] id_rd  = ifid_instr[11:7];

    wire [4:0] d_alu_op;  wire d_alu_src;  wire [2:0] d_imm_type;
    wire d_reg_write;     wire [1:0] d_wb_sel;
    wire d_mem_read;      wire d_mem_write; wire [1:0] d_mem_size; wire d_load_sign;
    wire d_is_branch;     wire d_is_jal;    wire d_is_jalr;
    wire d_is_lui;        wire d_is_auipc;
    wire d_is_amo;        wire [3:0] d_amo_op;
    wire [1:0] d_csr_op;  wire d_csr_use_zimm;
    wire d_is_mret;       wire d_is_ecall;  wire d_is_ebreak; wire d_is_wfi;
    wire d_illegal;

    rv32_decoder DEC (
        .instr(ifid_instr),
        .alu_op(d_alu_op), .alu_src(d_alu_src), .imm_type(d_imm_type),
        .reg_write(d_reg_write), .wb_sel(d_wb_sel),
        .mem_read(d_mem_read), .mem_write(d_mem_write), .mem_size(d_mem_size),
        .load_sign(d_load_sign),
        .is_branch(d_is_branch), .is_jal(d_is_jal), .is_jalr(d_is_jalr),
        .is_lui(d_is_lui), .is_auipc(d_is_auipc),
        .is_amo(d_is_amo), .amo_op(d_amo_op),
        .csr_op(d_csr_op), .csr_use_zimm(d_csr_use_zimm),
        .is_mret(d_is_mret), .is_ecall(d_is_ecall),
        .is_ebreak(d_is_ebreak), .is_wfi(d_is_wfi), .illegal(d_illegal)
    );

    // Zero word = NOP (used for bubbles / unprogrammed ROM): never illegal.
    wire id_is_nop  = (ifid_instr == 32'b0);
    wire id_illegal = d_illegal & ~id_is_nop;

    wire [31:0] id_imm;
    rv32_immgen IMM (.instr(ifid_instr), .imm_type(d_imm_type), .imm(id_imm));

    // Which source registers does the ID instruction actually read?
    wire uses_rs1 = ~(id_opcode==OP_LUI | id_opcode==OP_AUIPC | id_opcode==OP_JAL);
    wire uses_rs2 =  (id_opcode==OP_OP   | id_opcode==OP_BRANCH |
                      id_opcode==OP_STORE| id_opcode==OP_AMO);

    wire        rf_we    = memwb_reg_write;
    wire [4:0]  rf_waddr = memwb_rd;
    wire [31:0] rf_wdata;
    wire [31:0] rf_rdata1, rf_rdata2;
    rv32_regfile RF (
        .clk(clk), .we(rf_we), .waddr(rf_waddr), .wdata(rf_wdata),
        .raddr1(id_rs1), .raddr2(id_rs2), .rdata1(rf_rdata1), .rdata2(rf_rdata2)
    );

    // =======================================================================
    // ID/EX register
    // =======================================================================
    reg         idex_valid;
    reg  [31:0] idex_pc, idex_imm, idex_rs1val, idex_rs2val;
    reg  [4:0]  idex_rs1, idex_rs2, idex_rd, idex_alu_op;
    reg         idex_alu_src, idex_reg_write;
    reg  [1:0]  idex_wb_sel, idex_mem_size, idex_csr_op;
    reg         idex_mem_read, idex_mem_write, idex_load_sign;
    reg         idex_is_branch, idex_is_jal, idex_is_jalr, idex_is_lui, idex_is_auipc;
    reg         idex_is_amo, idex_csr_use_zimm;
    reg  [3:0]  idex_amo_op;
    reg         idex_is_mret, idex_is_ecall, idex_is_ebreak, idex_is_wfi, idex_illegal;
    reg  [2:0]  idex_funct3;

    // =======================================================================
    // EX/MEM register (declared here so EX forwarding can reference it)
    // =======================================================================
    reg         exmem_valid;
    reg  [31:0] exmem_pc, exmem_alu_result, exmem_addr, exmem_rs2val;
    reg  [4:0]  exmem_rd;
    reg  [1:0]  exmem_mem_size, exmem_wb_sel;
    reg         exmem_reg_write, exmem_mem_read, exmem_mem_write;
    reg         exmem_load_sign, exmem_is_amo, exmem_is_csr;
    reg  [3:0]  exmem_amo_op;

    // =======================================================================
    // MEM/WB register
    // =======================================================================
    reg         memwb_valid;
    reg         memwb_reg_write;
    reg  [1:0]  memwb_wb_sel;
    reg  [31:0] memwb_alu_result, memwb_load_data, memwb_pc, memwb_csr_rdata;
    reg  [4:0]  memwb_rd;

    reg [31:0] wbval;
    always @(*) begin
        case (memwb_wb_sel)
            WB_LOAD: wbval = memwb_load_data;
            WB_PC4:  wbval = memwb_pc + 32'd4;
            WB_CSR:  wbval = memwb_csr_rdata;
            default: wbval = memwb_alu_result;
        endcase
    end
    wire [31:0] memwb_wbval = wbval;
    assign rf_wdata = wbval;

    // EX/MEM forwarding value (ALU result, or PC+4 for jumps)
    wire [31:0] exmem_fwd_val = (exmem_wb_sel==WB_PC4) ? (exmem_pc + 32'd4)
                                                       : exmem_alu_result;

    // =======================================================================
    // EX
    // =======================================================================
    wire fwdA_mem = exmem_reg_write & (exmem_rd!=0) & (exmem_rd==idex_rs1)
                    & ~exmem_mem_read & ~exmem_is_csr;
    wire fwdA_wb  = memwb_reg_write & (memwb_rd!=0) & (memwb_rd==idex_rs1);
    wire fwdB_mem = exmem_reg_write & (exmem_rd!=0) & (exmem_rd==idex_rs2)
                    & ~exmem_mem_read & ~exmem_is_csr;
    wire fwdB_wb  = memwb_reg_write & (memwb_rd!=0) & (memwb_rd==idex_rs2);

    wire [31:0] ex_opA = fwdA_mem ? exmem_fwd_val : fwdA_wb ? memwb_wbval : idex_rs1val;
    wire [31:0] ex_opB = fwdB_mem ? exmem_fwd_val : fwdB_wb ? memwb_wbval : idex_rs2val;

    wire [31:0] alu_a = idex_is_auipc ? idex_pc : ex_opA;
    wire [31:0] alu_b = idex_alu_src  ? idex_imm : ex_opB;
    wire [31:0] alu_result;
    wire        alu_zero;
    rv32_alu ALU (.a(alu_a), .b(alu_b), .alu_op(idex_alu_op),
                  .result(alu_result), .zero(alu_zero));

    reg branch_cond;
    always @(*) begin
        case (idex_funct3)
            3'b000:  branch_cond = (ex_opA == ex_opB);
            3'b001:  branch_cond = (ex_opA != ex_opB);
            3'b100:  branch_cond = ($signed(ex_opA) <  $signed(ex_opB));
            3'b101:  branch_cond = ($signed(ex_opA) >= $signed(ex_opB));
            3'b110:  branch_cond = (ex_opA <  ex_opB);
            3'b111:  branch_cond = (ex_opA >= ex_opB);
            default: branch_cond = 1'b0;
        endcase
    end

    wire [31:0] ex_target = idex_is_jalr ? ((ex_opA + idex_imm) & ~32'b1)
                                         : (idex_pc + idex_imm);
    wire ex_branch_taken = idex_valid &
        (idex_is_jal | idex_is_jalr | (idex_is_branch & branch_cond)) & ~stall_mem;

    wire [31:0] ex_addr = idex_is_amo ? ex_opA : alu_result; // memory address

    // Misalignment: word must be 4-aligned, half 2-aligned, byte always OK.
    wire ex_mis = (idex_mem_size==2'd2) ? (ex_addr[1:0] != 2'b00) :
                  (idex_mem_size==2'd1) ? (ex_addr[0]    != 1'b0)  : 1'b0;
    wire ex_load_misalign  = idex_valid & (idex_mem_read | idex_is_amo) & ex_mis;
    wire ex_store_misalign = idex_valid & idex_mem_write & ex_mis;

    // ----- CSR / traps -----------------------------------------------------
    wire [31:0] csr_rdata, mtvec, mepc, mstatus_csr, int_cause;
    wire        take_interrupt;

    wire [31:0] csr_src     = idex_csr_use_zimm ? {27'b0, idex_rs1} : ex_opA;
    wire        csr_do_write= (idex_csr_op==CSR_RW) | (idex_rs1 != 5'b0);
    wire        is_csr_op   = (idex_csr_op != CSR_NONE);

    wire ex_exception = idex_valid &
        (idex_illegal | idex_is_ecall | idex_is_ebreak |
         ex_load_misalign | ex_store_misalign);

    reg [31:0] trap_cause, trap_tval;
    always @(*) begin
        trap_cause = 32'b0; trap_tval = 32'b0;
        if      (idex_illegal)        begin trap_cause=EXC_ILLEGAL;   trap_tval=ifid_instr; end
        else if (idex_is_ebreak)      begin trap_cause=EXC_BREAK;     trap_tval=32'b0;      end
        else if (ex_load_misalign)    begin trap_cause=EXC_LOAD_MIS;  trap_tval=ex_addr;    end
        else if (ex_store_misalign)   begin trap_cause=EXC_STORE_MIS; trap_tval=ex_addr;    end
        else if (idex_is_ecall)       begin trap_cause=EXC_ECALL_M;   trap_tval=32'b0;      end
    end
    wire trap_is_interrupt = ~ex_exception & take_interrupt;

    // =======================================================================
    // MEM : load-result extraction (uses registered MEM address)
    // =======================================================================
    reg [31:0] load_extracted;
    always @(*) begin
        case (exmem_mem_size)
            2'd0: case (exmem_addr[1:0])
                    2'd0: load_extracted = {{24{exmem_load_sign & d_rdata[7]}},  d_rdata[7:0]};
                    2'd1: load_extracted = {{24{exmem_load_sign & d_rdata[15]}}, d_rdata[15:8]};
                    2'd2: load_extracted = {{24{exmem_load_sign & d_rdata[23]}}, d_rdata[23:16]};
                    2'd3: load_extracted = {{24{exmem_load_sign & d_rdata[31]}}, d_rdata[31:24]};
                  endcase
            2'd1: load_extracted = exmem_addr[1]
                    ? {{16{exmem_load_sign & d_rdata[31]}}, d_rdata[31:16]}
                    : {{16{exmem_load_sign & d_rdata[15]}}, d_rdata[15:0]};
            default: load_extracted = d_rdata;
        endcase
        if (exmem_is_amo) load_extracted = d_rdata; // AMO/SC write back full word
    end

    // =======================================================================
    // Hazard / stall control
    // =======================================================================
    wire id_ex_produces_load = idex_mem_read | idex_is_amo | is_csr_op;
    wire loaduse_stall = idex_valid & id_ex_produces_load & (idex_rd != 0) &
        (((idex_rd==id_rs1) & uses_rs1) | ((idex_rd==id_rs2) & uses_rs2));

    wire stall_mem = d_cyc & ~d_ack;
    wire freeze    = stall_mem | loaduse_stall;

    wire take_trap_now = (ex_exception |
                          (take_interrupt & idex_valid & ~idex_is_mret)) & ~stall_mem;
    wire do_mret       = idex_valid & idex_is_mret & ~stall_mem;

    wire squash_ex_mem = take_trap_now | do_mret;
    wire flush_id_ex   = ex_branch_taken | take_trap_now | do_mret | (loaduse_stall & ~stall_mem);
    wire flush_if_id   = ex_branch_taken | take_trap_now | do_mret;

    reg [31:0] pc_next;
    always @(*) begin
        if      (take_trap_now)   pc_next = mtvec;
        else if (do_mret)         pc_next = mepc;
        else if (ex_branch_taken) pc_next = ex_target;
        else                      pc_next = pc_q + 32'd4;
    end
    wire pc_en = ~freeze | take_trap_now | do_mret;

    // =======================================================================
    // Next-state bus byte-enables / store data (computed in EX)
    // =======================================================================
    reg [3:0]  be_next;
    reg [31:0] wdata_next;
    always @(*) begin
        case (idex_mem_size)
            2'd0: begin
                be_next     = 4'b0001 << ex_addr[1:0];
                wdata_next  = {4{ex_opB[7:0]}} << (8*ex_addr[1:0]);
            end
            2'd1: begin
                be_next     = ex_addr[1] ? 4'b1100 : 4'b0011;
                wdata_next  = ex_addr[1] ? {ex_opB[15:0],16'b0} : {16'b0,ex_opB[15:0]};
            end
            default: begin
                be_next     = 4'b1111;
                wdata_next  = ex_opB;
            end
        endcase
    end
    wire bus_op_next = idex_valid & ~squash_ex_mem &
                       (idex_mem_read | idex_mem_write | idex_is_amo);

    // =======================================================================
    // Sequential pipeline
    // =======================================================================
    always @(posedge clk) begin
        if (rst) begin
            pc_q        <= RESET_VECTOR;
            ifid_valid  <= 1'b0; ifid_pc <= 0; ifid_instr <= 0;
            idex_valid  <= 1'b0; idex_reg_write <= 0; idex_mem_read <= 0;
            idex_mem_write <= 0; idex_is_amo <= 0; idex_csr_op <= CSR_NONE;
            idex_illegal <= 0; idex_is_mret <= 0; idex_is_ecall <= 0;
            idex_is_ebreak <= 0; idex_is_branch <= 0; idex_is_jal <= 0;
            idex_is_jalr <= 0; idex_is_lui <= 0; idex_is_auipc <= 0; idex_is_wfi <= 0;
            exmem_valid <= 1'b0; exmem_reg_write <= 0; exmem_mem_read <= 0;
            exmem_mem_write <= 0; exmem_is_amo <= 0; exmem_is_csr <= 0;
            memwb_valid <= 1'b0; memwb_reg_write <= 0;
            d_cyc <= 1'b0; d_we <= 1'b0; d_amo <= AMO_NONE;
        end else begin
            // ---- PC ----
            if (pc_en) pc_q <= pc_next;

            // ---- IF/ID ----
            if (flush_if_id) begin
                ifid_valid <= 1'b0; ifid_instr <= 32'b0; ifid_pc <= 32'b0;
            end else if (~freeze) begin
                ifid_valid <= 1'b1; ifid_pc <= pc_q; ifid_instr <= fetch_instr;
            end

            // ---- ID/EX ----
            if (flush_id_ex) begin
                idex_valid <= 1'b0; idex_reg_write <= 0; idex_mem_read <= 0;
                idex_mem_write <= 0; idex_is_branch <= 0; idex_is_jal <= 0;
                idex_is_jalr <= 0; idex_is_amo <= 0; idex_csr_op <= CSR_NONE;
                idex_illegal <= 0; idex_is_mret <= 0; idex_is_ecall <= 0;
                idex_is_ebreak <= 0; idex_is_lui <= 0; idex_is_auipc <= 0;
                idex_is_wfi <= 0;
            end else if (~freeze) begin
                idex_valid       <= ifid_valid;
                idex_pc          <= ifid_pc;
                idex_imm         <= id_imm;
                idex_rs1val      <= rf_rdata1;
                idex_rs2val      <= rf_rdata2;
                idex_rs1         <= id_rs1;
                idex_rs2         <= id_rs2;
                idex_rd          <= id_rd;
                idex_alu_op      <= d_alu_op;
                idex_alu_src     <= d_alu_src;
                idex_reg_write   <= d_reg_write & ifid_valid;
                idex_wb_sel      <= d_wb_sel;
                idex_mem_read    <= d_mem_read;
                idex_mem_write   <= d_mem_write;
                idex_mem_size    <= d_mem_size;
                idex_load_sign   <= d_load_sign;
                idex_is_branch   <= d_is_branch;
                idex_is_jal      <= d_is_jal;
                idex_is_jalr     <= d_is_jalr;
                idex_is_lui      <= d_is_lui;
                idex_is_auipc    <= d_is_auipc;
                idex_is_amo      <= d_is_amo;
                idex_amo_op      <= d_amo_op;
                idex_csr_op      <= d_csr_op;
                idex_csr_use_zimm<= d_csr_use_zimm;
                idex_is_mret     <= d_is_mret;
                idex_is_ecall    <= d_is_ecall;
                idex_is_ebreak   <= d_is_ebreak;
                idex_is_wfi      <= d_is_wfi;
                idex_illegal     <= id_illegal;
                idex_funct3      <= ifid_instr[14:12];
            end else begin
                idex_rs1val <= ex_opA;
                idex_rs2val <= ex_opB;
            end

            // ---- EX/MEM ----
            if (~stall_mem) begin
                exmem_valid      <= idex_valid & ~squash_ex_mem;
                exmem_pc         <= idex_pc;
                exmem_alu_result <= alu_result;
                exmem_addr       <= ex_addr;
                exmem_rs2val     <= ex_opB;
                exmem_rd         <= idex_rd;
                exmem_mem_size   <= idex_mem_size;
                exmem_load_sign  <= idex_load_sign;
                exmem_wb_sel     <= idex_wb_sel;
                exmem_is_amo     <= idex_is_amo   & ~squash_ex_mem;
                exmem_amo_op     <= idex_amo_op;
                exmem_is_csr     <= is_csr_op     & ~squash_ex_mem;
                exmem_mem_read   <= idex_mem_read & ~squash_ex_mem;
                exmem_mem_write  <= idex_mem_write& ~squash_ex_mem;
                exmem_reg_write  <= idex_reg_write & ~squash_ex_mem & ~idex_is_amo;
            end

            // ---- data bus request (registered in step with EX/MEM) ----
            if (~stall_mem) begin
                if (bus_op_next) begin
                    d_cyc   <= 1'b1;
                    d_we    <= idex_mem_write | (idex_is_amo & (idex_amo_op != AMO_LR));
                    d_addr  <= ex_addr;
                    d_wdata <= idex_is_amo ? ex_opB : wdata_next;
                    d_be    <= be_next;
                    d_amo   <= idex_is_amo ? idex_amo_op : AMO_NONE;
                end else begin
                    d_cyc   <= 1'b0;
                    d_we    <= 1'b0;
                    d_amo   <= AMO_NONE;
                end
            end

            // ---- MEM/WB ----
            if (stall_mem) begin
                memwb_valid     <= 1'b0;
                memwb_reg_write <= 1'b0;
            end else begin
                memwb_valid      <= exmem_valid;
                memwb_reg_write  <= exmem_reg_write | (exmem_is_amo & exmem_valid);
                memwb_wb_sel     <= exmem_wb_sel;
                memwb_alu_result <= exmem_alu_result;
                memwb_load_data  <= load_extracted;
                memwb_pc         <= exmem_pc;
                memwb_csr_rdata  <= csr_rdata;
                memwb_rd         <= exmem_rd;
            end
        end
    end

    // =======================================================================
    // CSR instance
    // =======================================================================
    rv32_csr #(.HART_ID(HART_ID)) CSR (
        .clk(clk), .rst(rst),
        .csr_en       (idex_valid & is_csr_op & ~freeze & ~squash_ex_mem),
        .csr_op       (idex_csr_op),
        .csr_addr     (idex_imm[11:0]),   // I-type immediate == instr[31:20]
        .csr_wdata    (csr_src),
        .csr_do_write (csr_do_write),
        .csr_rdata    (csr_rdata),
        .trap_en      (take_trap_now),
        .trap_interrupt(trap_is_interrupt),
        .trap_cause   (trap_is_interrupt ? int_cause : trap_cause),
        .trap_tval    (trap_tval),
        .trap_pc      (idex_pc),
        .mtvec(mtvec), .mepc(mepc), .mstatus(mstatus_csr),
        .mret_en      (do_mret),
        .irq_software (irq_software), .irq_timer(irq_timer),
        .irq_external (irq_external),
        .instret_inc  (memwb_valid),
        .mtime_in     (mtime_in),
        .take_interrupt(take_interrupt), .int_cause(int_cause)
    );

    assign core_busy = pc_en | d_cyc | idex_valid | exmem_valid | memwb_valid;

    always @(posedge clk) begin
        if (idex_valid && !freeze) begin
            $display("PC=%x instr=%x alu_op=%d a=%x b=%x result=%x d_cyc=%d", idex_pc, idex_imm, idex_alu_op, alu_a, alu_b, alu_result, d_cyc);
        end
    end
endmodule
