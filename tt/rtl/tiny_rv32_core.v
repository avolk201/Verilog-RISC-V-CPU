//-----------------------------------------------------------------------------
// tiny_rv32_core.v - Area-optimized RV32E Core for Tiny Tapeout
//
// Features:
//   - 16 registers (x0-x15) to minimize flip-flop count for Sky130 tiles
//   - Full RV32I base instructions (branch, jump, load/store, ALU, shifts)
//   - RV32M basic multiply: MUL (single-cycle 32-bit integer multiplication)
//   - Custom DOOM Assist: FMUL16 (single-cycle 16.16 signed fixed-point multiply)
//   - Custom TinyML Assist: DOTP8 (single-cycle 4x 8-bit vector dot-product)
//   - Clean memory bus interface with wait-state / stall support
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module tiny_rv32_core #(
    parameter RESET_VEC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst_n,

    // Instruction bus
    output wire [31:0] i_addr,
    output wire        i_req,
    input  wire [31:0] i_rdata,
    input  wire        i_ack,

    // Data bus
    output wire [31:0] d_addr,
    output wire [31:0] d_wdata,
    output wire [3:0]  d_be,
    output wire        d_we,
    output wire        d_req,
    input  wire [31:0] d_rdata,
    input  wire        d_ack
);

    // ---------------- Registers (RV32E: x0 - x15) ----------------
    reg [31:0] regs [1:15];
    integer r_i;

    // ---------------- Program Counter ----------------
    reg [31:0] pc;
    reg [31:0] pc_next;

    // ---------------- State Machine ----------------
    localparam S_IF     = 2'd0;
    localparam S_EX_MEM = 2'd1;
    localparam S_WAIT_M = 2'd2;
    reg [1:0] state;

    reg [31:0] instr;
    reg [31:0] mem_addr_reg;
    reg [31:0] mem_wdata_reg;
    reg [3:0]  mem_be_reg;
    reg        mem_we_reg;
    reg        mem_req_reg;
    reg [3:0]  wb_rd_reg;
    reg        wb_en_reg;

    // ---------------- Instruction Field Decode ----------------
    wire [6:0] opcode = instr[6:0];
    wire [3:0] rd     = instr[11:7] & 4'hF;  // Constrained to x0-x15
    wire [2:0] funct3 = instr[14:12];
    wire [3:0] rs1    = instr[19:15] & 4'hF;
    wire [3:0] rs2    = instr[24:20] & 4'hF;
    wire [6:0] funct7 = instr[31:25];

    // Immediates
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    wire [31:0] store_addr = rdata1 + imm_s;
    wire [1:0]  store_offset = store_addr[1:0];

    // Register reads
    wire [31:0] rdata1 = (rs1 == 4'd0) ? 32'b0 : regs[rs1];
    wire [31:0] rdata2 = (rs2 == 4'd0) ? 32'b0 : regs[rs2];

    // ---------------- ALU & Coprocessors ----------------
    wire [31:0] alu_op2 = (opcode == 7'b0010011 || opcode == 7'b0000011 || opcode == 7'b1100111) ? imm_i : rdata2;
    wire [4:0]  shamt   = alu_op2[4:0];

    // Standard ALU results
    reg [31:0] alu_res;
    always @(*) begin
        case (funct3)
            3'b000:  alu_res = (opcode == 7'b0110011 && funct7[5]) ? (rdata1 - alu_op2) : (rdata1 + alu_op2);
            3'b001:  alu_res = rdata1 << shamt;
            3'b010:  alu_res = ($signed(rdata1) < $signed(alu_op2)) ? 32'd1 : 32'd0;
            3'b011:  alu_res = (rdata1 < alu_op2) ? 32'd1 : 32'd0;
            3'b100:  alu_res = rdata1 ^ alu_op2;
            3'b101:  alu_res = funct7[5] ? ($signed(rdata1) >>> shamt) : (rdata1 >> shamt);
            3'b110:  alu_res = rdata1 | alu_op2;
            3'b111:  alu_res = rdata1 & alu_op2;
        endcase
    end

    // Multiplier (RV32M MUL: single-cycle 32-bit low product)
    wire signed [63:0] mul_full = $signed(rdata1) * $signed(rdata2);
    wire [31:0] mul_res = mul_full[31:0];

    // DOOM Assist: FMUL16 (16.16 signed fixed-point multiply: FixedMul(a, b) = (a * b) >> 16)
    wire [31:0] fmul16_res = mul_full[47:16];

    // TinyML Assist: DOTP8 (4-way 8-bit signed dot-product accumulated with destination rd)
    wire signed [15:0] dp0 = $signed(rdata1[7:0])   * $signed(rdata2[7:0]);
    wire signed [15:0] dp1 = $signed(rdata1[15:8])  * $signed(rdata2[15:8]);
    wire signed [15:0] dp2 = $signed(rdata1[23:16]) * $signed(rdata2[23:16]);
    wire signed [15:0] dp3 = $signed(rdata1[31:24]) * $signed(rdata2[31:24]);
    wire [31:0] dotp8_res = regs[rd] + {{16{dp0[15]}}, dp0} + {{16{dp1[15]}}, dp1} +
                                       {{16{dp2[15]}}, dp2} + {{16{dp3[15]}}, dp3};

    // Branch condition
    reg branch_taken;
    always @(*) begin
        case (funct3)
            3'b000: branch_taken = (rdata1 == rdata2);
            3'b001: branch_taken = (rdata1 != rdata2);
            3'b100: branch_taken = ($signed(rdata1) < $signed(rdata2));
            3'b101: branch_taken = ($signed(rdata1) >= $signed(rdata2));
            3'b110: branch_taken = (rdata1 < rdata2);
            3'b111: branch_taken = (rdata1 >= rdata2);
            default: branch_taken = 1'b0;
        endcase
    end

    // Load data formatting
    reg [31:0] load_data;
    wire [1:0] l_offset = mem_addr_reg[1:0];
    always @(*) begin
        case (funct3)
            3'b000: begin // LB
                case (l_offset)
                    2'b00: load_data = {{24{d_rdata[7]}},  d_rdata[7:0]};
                    2'b01: load_data = {{24{d_rdata[15]}}, d_rdata[15:8]};
                    2'b10: load_data = {{24{d_rdata[23]}}, d_rdata[23:16]};
                    2'b11: load_data = {{24{d_rdata[31]}}, d_rdata[31:24]};
                endcase
            end
            3'b001: begin // LH
                case (l_offset[1])
                    1'b0: load_data = {{16{d_rdata[15]}}, d_rdata[15:0]};
                    1'b1: load_data = {{16{d_rdata[31]}}, d_rdata[31:16]};
                endcase
            end
            3'b010: load_data = d_rdata; // LW
            3'b100: begin // LBU
                case (l_offset)
                    2'b00: load_data = {24'b0, d_rdata[7:0]};
                    2'b01: load_data = {24'b0, d_rdata[15:8]};
                    2'b10: load_data = {24'b0, d_rdata[23:16]};
                    2'b11: load_data = {24'b0, d_rdata[31:24]};
                endcase
            end
            3'b101: begin // LHU
                case (l_offset[1])
                    1'b0: load_data = {16'b0, d_rdata[15:0]};
                    1'b1: load_data = {16'b0, d_rdata[31:16]};
                endcase
            end
            default: load_data = d_rdata;
        endcase
    end

    // Writeback data mux
    reg [31:0] wb_data_w;
    always @(*) begin
        case (opcode)
            7'b0110111: wb_data_w = imm_u;                          // LUI
            7'b0010111: wb_data_w = pc + imm_u;                     // AUIPC
            7'b1101111,                                             // JAL
            7'b1100111: wb_data_w = pc + 32'd4;                     // JALR
            7'b0000011: wb_data_w = load_data;                      // LOAD
            7'b0010011: wb_data_w = alu_res;                        // OP-IMM
            7'b0110011: begin                                       // OP / MUL
                if (funct7 == 7'b0000001 && funct3 == 3'b000)
                    wb_data_w = mul_res;                            // MUL
                else
                    wb_data_w = alu_res;
            end
            7'b0001011: begin                                       // CUSTOM_0 (Accelerators)
                if (funct3 == 3'b000)
                    wb_data_w = fmul16_res;                         // FMUL16 (DOOM)
                else if (funct3 == 3'b001)
                    wb_data_w = dotp8_res;                          // DOTP8 (TinyML)
                else
                    wb_data_w = 32'b0;
            end
            default:    wb_data_w = 32'b0;
        endcase
    end

    // ---------------- Instruction and Data Bus Signals ----------------
    assign i_addr  = pc;
    assign i_req   = (state == S_IF);

    assign d_addr  = mem_addr_reg;
    assign d_wdata = mem_wdata_reg;
    assign d_be    = mem_be_reg;
    assign d_we    = mem_we_reg;
    assign d_req   = mem_req_reg;

    // ---------------- Pipeline State Machine ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc          <= RESET_VEC;
            state       <= S_IF;
            instr       <= 32'h0000_0013; // NOP
            mem_req_reg <= 1'b0;
            mem_we_reg  <= 1'b0;
            wb_en_reg   <= 1'b0;
            for (r_i = 1; r_i < 16; r_i = r_i + 1)
                regs[r_i] <= 32'b0;
        end else begin
            wb_en_reg <= 1'b0; // Default clear single-cycle write strobe

            case (state)
                S_IF: begin
                    if (i_ack) begin
                        instr <= i_rdata;
                        state <= S_EX_MEM;
                    end
                end

                S_EX_MEM: begin
                    case (opcode)
                        // LUI, AUIPC, OP-IMM, OP, CUSTOM_0
                        7'b0110111, 7'b0010111, 7'b0010011, 7'b0110011, 7'b0001011: begin
                            if (rd != 4'd0) begin
                                regs[rd] <= wb_data_w;
                                wb_rd_reg <= rd;
                                wb_en_reg <= 1'b1;
                            end
                            pc    <= pc + 32'd4;
                            state <= S_IF;
                        end

                        // JAL
                        7'b1101111: begin
                            if (rd != 4'd0) begin
                                regs[rd] <= pc + 32'd4;
                                wb_rd_reg <= rd;
                                wb_en_reg <= 1'b1;
                            end
                            pc    <= pc + imm_j;
                            state <= S_IF;
                        end

                        // JALR
                        7'b1100111: begin
                            if (rd != 4'd0) begin
                                regs[rd] <= pc + 32'd4;
                                wb_rd_reg <= rd;
                                wb_en_reg <= 1'b1;
                            end
                            pc    <= (rdata1 + imm_i) & ~32'd1;
                            state <= S_IF;
                        end

                        // BRANCH
                        7'b1100011: begin
                            if (branch_taken)
                                pc <= pc + imm_b;
                            else
                                pc <= pc + 32'd4;
                            state <= S_IF;
                        end

                        // LOAD
                        7'b0000011: begin
                            mem_addr_reg <= rdata1 + imm_i;
                            mem_req_reg  <= 1'b1;
                            mem_we_reg   <= 1'b0;
                            mem_be_reg   <= 4'b1111;
                            state        <= S_WAIT_M;
                        end

                        // STORE
                        7'b0100011: begin
                            mem_addr_reg <= store_addr;
                            mem_req_reg  <= 1'b1;
                            mem_we_reg   <= 1'b1;
                            case (funct3)
                                3'b000: begin // SB
                                    case (store_offset)
                                        2'b00: begin mem_be_reg <= 4'b0001; mem_wdata_reg <= {24'b0, rdata2[7:0]}; end
                                        2'b01: begin mem_be_reg <= 4'b0010; mem_wdata_reg <= {16'b0, rdata2[7:0], 8'b0}; end
                                        2'b10: begin mem_be_reg <= 4'b0100; mem_wdata_reg <= {8'b0,  rdata2[7:0], 16'b0}; end
                                        2'b11: begin mem_be_reg <= 4'b1000; mem_wdata_reg <= {rdata2[7:0], 24'b0}; end
                                    endcase
                                end
                                3'b001: begin // SH
                                    case (store_offset[1])
                                        1'b0: begin mem_be_reg <= 4'b0011; mem_wdata_reg <= {16'b0, rdata2[15:0]}; end
                                        1'b1: begin mem_be_reg <= 4'b1100; mem_wdata_reg <= {rdata2[15:0], 16'b0}; end
                                    endcase
                                end
                                default: begin // SW
                                    mem_be_reg    <= 4'b1111;
                                    mem_wdata_reg <= rdata2;
                                end
                            endcase
                            state <= S_WAIT_M;
                        end

                        default: begin
                            // NOP / unsupported fallback
                            pc    <= pc + 32'd4;
                            state <= S_IF;
                        end
                    endcase
                end

                S_WAIT_M: begin
                    if (d_ack) begin
                        mem_req_reg <= 1'b0;
                        if (!mem_we_reg && rd != 4'd0) begin
                            regs[rd]  <= load_data;
                            wb_rd_reg <= rd;
                            wb_en_reg <= 1'b1;
                        end
                        pc    <= pc + 32'd4;
                        state <= S_IF;
                    end
                end
                default: state <= S_IF;
            endcase
        end
    end

endmodule
