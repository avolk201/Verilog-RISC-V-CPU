//-----------------------------------------------------------------------------
// rv32_decoder.v - RISC-V main instruction decoder
// Combinational decode of RV32I plus the M (mul/div) and A (atomic) subsets.
// Produces the control word consumed by the core pipeline. Illegal encodings
// raise `illegal` so the core can take a precise illegal-instruction trap.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module rv32_decoder (
    input  [31:0] instr,
    // ALU
    output reg  [4:0] alu_op,
    output reg        alu_src,        // 0 = rs2, 1 = immediate
    output reg  [2:0] imm_type,
    // register write-back
    output reg        reg_write,
    output reg  [1:0] wb_sel,         // WB_* below
    // memory
    output reg        mem_read,
    output reg        mem_write,
    output reg  [1:0] mem_size,       // 0=B 1=H 2=W
    output reg        load_sign,      // sign-extend loaded value
    // control flow
    output reg        is_branch,
    output reg        is_jal,
    output reg        is_jalr,
    output reg        is_lui,
    output reg        is_auipc,
    // atomics
    output reg        is_amo,
    output reg  [3:0] amo_op,         // AMO_* below
    // system
    output reg  [1:0] csr_op,         // CSR_* below
    output reg        csr_use_zimm,
    output reg        is_mret,
    output reg        is_ecall,
    output reg        is_ebreak,
    output reg        is_wfi,
    output reg        illegal
);
    // Immediate types (must match rv32_immgen)
    localparam IMT_I = 3'd0, IMT_S = 3'd1, IMT_B = 3'd2,
               IMT_U = 3'd3, IMT_J = 3'd4;
    // Write-back sources
    localparam WB_ALU = 2'd0, WB_LOAD = 2'd1, WB_PC4 = 2'd2, WB_CSR = 2'd3;
    // CSR operations
    localparam CSR_NONE = 2'd0, CSR_RW = 2'd1, CSR_RS = 2'd2, CSR_RC = 2'd3;
    // Atomic operations (bus encoding)
    localparam AMO_NONE = 4'd0, AMO_LR = 4'd1, AMO_SC = 4'd2,
               AMO_SWAP = 4'd3, AMO_ADD = 4'd4, AMO_AND = 4'd5,
               AMO_OR  = 4'd6, AMO_XOR = 4'd7, AMO_MIN = 4'd8,
               AMO_MAX = 4'd9, AMO_MINU = 4'd10, AMO_MAXU = 4'd11;
    // ALU operations (must match rv32_alu)
    localparam ALU_ADD=5'd0, ALU_SUB=5'd1, ALU_SLL=5'd2, ALU_SLT=5'd3,
               ALU_SLTU=5'd4, ALU_XOR=5'd5, ALU_SRL=5'd6, ALU_SRA=5'd7,
               ALU_OR=5'd8, ALU_AND=5'd9, ALU_MUL=5'd10, ALU_MULH=5'd11,
               ALU_MULHSU=5'd12, ALU_MULHU=5'd13, ALU_DIV=5'd14, ALU_DIVU=5'd15,
               ALU_REM=5'd16, ALU_REMU=5'd17, ALU_PASS_B=5'd18;

    // Opcode fields
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];
    wire [4:0] funct5 = instr[31:27];

    localparam OP_LUI    = 7'b0110111,
               OP_AUIPC  = 7'b0010111,
               OP_JAL    = 7'b1101111,
               OP_JALR   = 7'b1100111,
               OP_BRANCH = 7'b1100011,
               OP_LOAD   = 7'b0000011,
               OP_STORE  = 7'b0100011,
               OP_OPIMM  = 7'b0010011,
               OP_OP     = 7'b0110011,
               OP_AMO    = 7'b0101111,
               OP_SYSTEM = 7'b1110011,
               OP_FENCE  = 7'b0001111;

    always @(*) begin
        // ---- safe defaults: a harmless NOP ----
        alu_op      = ALU_ADD;
        alu_src     = 1'b0;
        imm_type    = IMT_I;
        reg_write   = 1'b0;
        wb_sel      = WB_ALU;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_size    = 2'd2;
        load_sign   = 1'b0;
        is_branch   = 1'b0;
        is_jal      = 1'b0;
        is_jalr     = 1'b0;
        is_lui      = 1'b0;
        is_auipc    = 1'b0;
        is_amo      = 1'b0;
        amo_op      = AMO_NONE;
        csr_op      = CSR_NONE;
        csr_use_zimm= 1'b0;
        is_mret     = 1'b0;
        is_ecall    = 1'b0;
        is_ebreak   = 1'b0;
        is_wfi      = 1'b0;
        illegal     = 1'b0;

        case (opcode)
            OP_LUI: begin
                is_lui   = 1'b1;
                reg_write= 1'b1;
                alu_src  = 1'b1;
                alu_op   = ALU_PASS_B;   // result = imm
                imm_type = IMT_U;
            end
            OP_AUIPC: begin
                is_auipc = 1'b1;
                reg_write= 1'b1;
                alu_src  = 1'b1;
                alu_op   = ALU_ADD;      // PC + imm (PC supplied as operand A)
                imm_type = IMT_U;
            end
            OP_JAL: begin
                is_jal   = 1'b1;
                reg_write= 1'b1;
                wb_sel   = WB_PC4;
                imm_type = IMT_J;
            end
            OP_JALR: begin
                is_jalr  = 1'b1;
                reg_write= 1'b1;
                wb_sel   = WB_PC4;
                alu_src  = 1'b1;
                alu_op   = ALU_ADD;      // rs1 + imm forms the target
                imm_type = IMT_I;
            end
            OP_BRANCH: begin
                is_branch= 1'b1;
                imm_type = IMT_B;
                // funct3 carried to EX comparator separately; ALU unused.
            end
            OP_LOAD: begin
                mem_read = 1'b1;
                reg_write= 1'b1;
                wb_sel   = WB_LOAD;
                alu_src  = 1'b1;
                alu_op   = ALU_ADD;      // rs1 + imm = address
                imm_type = IMT_I;
                mem_size = funct3[1:0];
                load_sign= ~funct3[2];   // LB/LH signed (funct3[2]=0); LBU/LHU unsigned
                if (funct3 == 3'b011 || funct3[1:0] == 2'b11) illegal = 1'b1;
            end
            OP_STORE: begin
                mem_write= 1'b1;
                alu_src  = 1'b1;
                alu_op   = ALU_ADD;      // rs1 + imm = address
                imm_type = IMT_S;
                mem_size = funct3[1:0];
                if (funct3[1:0] == 2'b11) illegal = 1'b1;
            end
            OP_OPIMM: begin
                reg_write= 1'b1;
                alu_src  = 1'b1;
                imm_type = IMT_I;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;    // ADDI
                    3'b010: alu_op = ALU_SLT;    // SLTI
                    3'b011: alu_op = ALU_SLTU;   // SLTIU
                    3'b100: alu_op = ALU_XOR;    // XORI
                    3'b110: alu_op = ALU_OR;     // ORI
                    3'b111: alu_op = ALU_AND;    // ANDI
                    3'b001: begin                // SLLI
                        alu_op = ALU_SLL;
                        if (funct7 != 7'b0000000) illegal = 1'b1;
                    end
                    3'b101: begin                // SRLI / SRAI
                        alu_op = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                        if (funct7 != 7'b0000000 && funct7 != 7'b0100000) illegal = 1'b1;
                    end
                endcase
            end
            OP_OP: begin
                reg_write= 1'b1;
                alu_src  = 1'b0;
                if (funct7 == 7'b0000001) begin       // M extension
                    case (funct3)
                        3'b000: alu_op = ALU_MUL;
                        3'b001: alu_op = ALU_MULH;
                        3'b010: alu_op = ALU_MULHSU;
                        3'b011: alu_op = ALU_MULHU;
                        3'b100: alu_op = ALU_DIV;
                        3'b101: alu_op = ALU_DIVU;
                        3'b110: alu_op = ALU_REM;
                        3'b111: alu_op = ALU_REMU;
                    endcase
                end else if (funct7 == 7'b0000000 || funct7 == 7'b0100000) begin
                    case (funct3)
                        3'b000: alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                        3'b001: alu_op = ALU_SLL;
                        3'b010: alu_op = ALU_SLT;
                        3'b011: alu_op = ALU_SLTU;
                        3'b100: alu_op = ALU_XOR;
                        3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                        3'b110: alu_op = ALU_OR;
                        3'b111: alu_op = ALU_AND;
                    endcase
                end else begin
                    illegal = 1'b1;
                end
            end
            OP_AMO: begin
                if (funct3 != 3'b010) begin           // only .W supported
                    illegal = 1'b1;
                end else begin
                    is_amo    = 1'b1;
                    reg_write = 1'b1;
                    wb_sel    = WB_LOAD;              // old memory value -> rd
                    alu_src   = 1'b0;
                    alu_op    = ALU_ADD;              // rs1 holds the address
                    case (funct5)
                        5'b00010: amo_op = AMO_LR;
                        5'b00011: amo_op = AMO_SC;
                        5'b00001: amo_op = AMO_SWAP;
                        5'b00000: amo_op = AMO_ADD;
                        5'b00100: amo_op = AMO_XOR;
                        5'b01000: amo_op = AMO_OR;
                        5'b01100: amo_op = AMO_AND;
                        5'b10000: amo_op = AMO_MIN;
                        5'b10001: amo_op = AMO_MAX;
                        5'b10100: amo_op = AMO_MINU;
                        5'b10101: amo_op = AMO_MAXU;
                        default:  illegal = 1'b1;
                    endcase
                end
            end
            OP_SYSTEM: begin
                if (funct3 == 3'b000) begin
                    case (instr[31:20])
                        12'h000: is_ecall  = 1'b1;
                        12'h001: is_ebreak = 1'b1;
                        12'h302: is_mret   = 1'b1;
                        12'h105: is_wfi    = 1'b1;
                        default: illegal   = 1'b1;
                    endcase
                end else begin
                    reg_write    = 1'b1;
                    wb_sel       = WB_CSR;
                    csr_use_zimm = funct3[2];
                    case (funct3[1:0])
                        2'b01: csr_op = CSR_RW;
                        2'b10: csr_op = CSR_RS;
                        2'b11: csr_op = CSR_RC;
                        default: illegal = 1'b1;
                    endcase
                end
            end
            OP_FENCE: begin
                // FENCE / FENCE.I treated as NOPs in this single-issue core.
            end
            default: illegal = 1'b1;
        endcase
    end
endmodule
