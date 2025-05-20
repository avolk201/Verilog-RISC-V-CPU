`timescale 1ns / 1ps

//----------------------------------------------------------------------------
// Module: cpu.v
// Top-level pipelined CPU integrating IF, ID, EX, MEM, WB stages
//----------------------------------------------------------------------------
module cpu #(
    parameter WIDTH       = 12,  // instruction and PC width
    parameter DATA_WIDTH  = 16,  // data path width
    parameter REGADDR_W   = 3,
    parameter IMEM_DEPTH  = 256,
    parameter DMEM_DEPTH  = 256
) (
    input                 clk,
    input                 reset
);

// ---------- IF Stage Signals ----------
wire [WIDTH-1:0] pc_next, pc_current;
wire [WIDTH-1:0] instr;

// Instantiate program counter
pc #(.WIDTH(WIDTH)) PC (
    .clk(clk),
    .reset(reset),
    .pc_write(1'b1),       // will be gated by hazard unit later
    .pc_in(pc_next),
    .pc_out(pc_current)
);

// Instruction memory (read-only)
instr_mem #(
    .ADDR_WIDTH($clog2(IMEM_DEPTH)),
    .DATA_WIDTH(WIDTH)
) IMEM (
    .addr(pc_current),
    .instr(instr)
);

// IF/ID pipeline register
wire [WIDTH-1:0] if_id_pc, if_id_instr;
if_id #(
    .PC_WIDTH(WIDTH),
    .INSTR_WIDTH(WIDTH)
) IF_ID (
    .clk(clk),
    .reset(reset),
    .stall(1'b0),          // from hazard detection
    .flush(1'b0),          // from branch control
    .if_pc(pc_current),
    .if_instr(instr),
    .id_pc(if_id_pc),
    .id_instr(if_id_instr)
);

// ---------- ID Stage Signals ----------
// Instruction decoding
wire [2:0] id_opcode = if_id_instr[11:9];   // bits [11:9]
wire [2:0] id_rd     = if_id_instr[ 8:6];   // bits [8:6]
wire [2:0] id_rs     = if_id_instr[ 5:3];   // bits [5:3] (R‑type Rs)
wire [2:0] id_rt     = if_id_instr[ 2:0];   // bits [2:0] (R‑type Rt)

// Immediate generation
wire [5:0] id_imm6   = if_id_instr[5:0];   // 6-bit immediate field
wire [DATA_WIDTH-1:0] id_imm_ext;          // Sign-extended immediate
imm_gen #(
    .IN_WIDTH(6),
    .OUT_WIDTH(DATA_WIDTH)
) IMM_GEN (
    .imm_in  (id_imm6),
    .imm_out (id_imm_ext)
);

// Control unit
wire reg_write, alu_src, mem_read, mem_write, branch;
wire [1:0] alu_op;
control CONTROL (
    .opcode   (id_opcode),
    .reg_write(reg_write),
    .alu_src  (alu_src),
    .mem_read (mem_read),
    .mem_write(mem_write),
    .branch   (branch),
    .alu_op   (alu_op)
);

// Register file
wire [DATA_WIDTH-1:0] reg_data1, reg_data2;
regfile #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(REGADDR_W)
) REGFILE (
    .clk        (clk),
    .reset      (reset),
    .read_reg1  (id_rs),
    .read_reg2  (id_rt),
    .write_reg  (/* from WB stage */),
    .write_data (/* from WB stage */),
    .reg_write  (reg_write),
    .read_data1 (reg_data1),
    .read_data2 (reg_data2)
);

// ---------- ID/EX Pipeline Register ----------
wire id_ex_reg_write, id_ex_alu_src, id_ex_mem_read, id_ex_mem_write, id_ex_branch;
wire [1:0] id_ex_alu_op;
wire [DATA_WIDTH-1:0] id_ex_reg_data1, id_ex_reg_data2, id_ex_imm_ext;
wire [2:0] id_ex_rs, id_ex_rt, id_ex_rd;
wire [WIDTH-1:0] id_ex_pc;

id_ex #(
    .PC_WIDTH       (WIDTH),
    .DATA_WIDTH     (DATA_WIDTH),
    .REGADDR_WIDTH  (REGADDR_W)
) ID_EX (
    .clk            (clk),
    .reset          (reset),
    .flush          (1'b0),          // wire in your branch flush
    .id_reg_write   (reg_write),
    .id_mem_read    (mem_read),
    .id_mem_write   (mem_write),
    .id_alu_op      (alu_op),
    .id_alu_src     (alu_src),
    .id_branch      (branch),
    .id_pc          (if_id_pc),
    .id_read_data1  (reg_data1),
    .id_read_data2  (reg_data2),
    .id_imm         (id_imm_ext),
    .id_rs          (id_rs),
    .id_rt          (id_rt),
    .id_rd          (id_rd),
    .ex_reg_write   (id_ex_reg_write),
    .ex_mem_read    (id_ex_mem_read),
    .ex_mem_write   (id_ex_mem_write),
    .ex_alu_op      (id_ex_alu_op),
    .ex_alu_src     (id_ex_alu_src),
    .ex_branch      (id_ex_branch),
    .ex_pc          (id_ex_pc),
    .ex_read_data1  (id_ex_reg_data1),
    .ex_read_data2  (id_ex_reg_data2),
    .ex_imm         (id_ex_imm_ext),
    .ex_rs          (id_ex_rs),
    .ex_rt          (id_ex_rt),
    .ex_rd          (id_ex_rd)
);

// TODO: instantiate ID stage (control, regfile, imm_gen)
// TODO: instantiate ID/EX reg
// TODO: instantiate EX stage (forwarding, ALU)
// TODO: instantiate EX/MEM reg

// ---------- MEM Stage ----------
wire [DATA_WIDTH-1:0] mem_read_data;
data_mem #(
    .ADDR_WIDTH($clog2(DMEM_DEPTH)),
    .DATA_WIDTH(DATA_WIDTH)
) DMEM (
    .clk        (clk),
    .mem_read   (mem_mem_read),
    .mem_write  (mem_mem_write),
    .addr       (mem_alu_result[$clog2(DMEM_DEPTH)-1:0]),
    .write_data (mem_write_data),
    .read_data  (mem_read_data)
);

// MEM/WB pipeline register
wire        wb_reg_write, wb_mem_to_reg;
wire [DATA_WIDTH-1:0] wb_read_data, wb_alu_result;
wire [REGADDR_W-1:0]  wb_rd;

mem_wb #(
    .DATA_WIDTH     (DATA_WIDTH),
    .REGADDR_WIDTH  (REGADDR_W)
) MEM_WB (
    .clk            (clk),
    .reset          (reset),
    .mem_reg_write  (mem_reg_write),
    .mem_mem_read   (mem_mem_read),
    .mem_read_data  (mem_read_data),
    .mem_alu_result (mem_alu_result),
    .mem_rd         (mem_rd),
    .wb_reg_write   (wb_reg_write),
    .wb_mem_to_reg  (wb_mem_to_reg),
    .wb_read_data   (wb_read_data),
    .wb_alu_result  (wb_alu_result),
    .wb_rd          (wb_rd)
);

// final write‐back MUX
wire [DATA_WIDTH-1:0] wb_write_data = wb_mem_to_reg ? wb_read_data : wb_alu_result;

// ---------- Update RegFile ports to use WB results ----------
regfile #(
    .DATA_WIDTH  (DATA_WIDTH),
    .ADDR_WIDTH  (REGADDR_W)
) REGFILE (
    .clk         (clk),
    .reset       (reset),
    .read_reg1   (id_rs),
    .read_reg2   (id_rt),
    .write_reg   (wb_rd),          // ← from MEM/WB
    .write_data  (wb_write_data),  // ← select ALU vs. MEM
    .reg_write   (wb_reg_write),
    .read_data1  (reg_data1),
    .read_data2  (reg_data2)
);

// TODO: instantiate MEM stage (data_mem)
// TODO: instantiate MEM/WB reg
// TODO: instantiate WB stage (write-back to regfile)

// TODO: PC update logic: PC + 1 or branch target
assign pc_next = pc_current + 1;

endmodule

// End of cpu.v


    parameter WIDTH = 12       // program counter width
) (
    input                   clk,
    input                   reset,
    input                   pc_write,   // enable update
    input  [WIDTH-1:0]      pc_in,
    output reg [WIDTH-1:0]  pc_out
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_out <= {WIDTH{1'b0}};
        else if (pc_write)
            pc_out <= pc_in;
    end
endmodule