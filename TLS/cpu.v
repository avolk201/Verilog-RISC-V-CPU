`timescale 1ns / 1ps

//----------------------------------------------------------------------------
// Module: cpu.v
// Top-level pipelined CPU
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
    .DATA_WIDTH(WIDTH),
    .MEMFILE("../IDM/instr_init.hex")  // <<< point up into IDM/
) IMEM (
    .addr  ( pc_current[$clog2(IMEM_DEPTH)-1:0] ),  // <<< slice off the top bits
    .instr ( instr )
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

// … up in your ID‐stage declarations
wire [DATA_WIDTH-1:0] id_reg_data1, id_reg_data2;  

// ────────────────────────────────────────────────────────────────────────────
// add these so wb_* are real buses, not 1-bit scalars
wire                      wb_reg_write, wb_mem_to_reg;
wire [DATA_WIDTH-1:0]     wb_read_data, wb_alu_result;
wire [REGADDR_W-1:0]      wb_rd;

// final write‐back MUX — now available before regfile
wire [DATA_WIDTH-1:0] wb_write_data = wb_mem_to_reg ? wb_read_data : wb_alu_result;

// instantiate register file in ID stage
regfile #(
    .DATA_WIDTH     (DATA_WIDTH),
    .REGADDR_WIDTH  (REGADDR_W)
) ID_REGFILE (
  .clk        (clk),
  .reset      (reset),
  .reg_write  (wb_reg_write),
  .read_reg1  (id_rs),
  .read_reg2  (id_rt),
  .write_reg  (wb_rd),
  .write_data (wb_write_data),
  .read_data1 (id_reg_data1),
  .read_data2 (id_reg_data2)
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
    .id_read_data1  (id_reg_data1),
    .id_read_data2  (id_reg_data2),
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

// … then later, after you’ve declared your ID/EX wires …
// add these two lines so reg_data1/reg_data2 exist at the right width
wire [DATA_WIDTH-1:0] reg_data1, reg_data2;

// TODO: instantiate ID stage (control, regfile, imm_gen)
// TODO: instantiate ID/EX reg
// TODO: instantiate EX stage (forwarding, ALU)
// TODO: instantiate EX/MEM reg

// 1) EX stage: ALU + select between reg_data2 vs. imm
wire [DATA_WIDTH-1:0] ex_operand2   = id_ex_alu_src ? id_ex_imm_ext : id_ex_reg_data2;
wire [DATA_WIDTH-1:0] ex_alu_result;
wire                 zero_flag;

alu #(
    .DATA_WIDTH(DATA_WIDTH)
) ALU (
    .a      (id_ex_reg_data1),   // <<< lower-case port names
    .b      (ex_operand2),
    .alu_op (id_ex_alu_op),
    .result (ex_alu_result),
    .zero   (zero_flag)
);

// 2) EX→MEM pipeline register
wire                  mem_reg_write, mem_mem_read, mem_mem_write, mem_branch;
wire [WIDTH-1:0]      mem_pc;
wire [DATA_WIDTH-1:0] mem_alu_result, mem_write_data;
wire [REGADDR_W-1:0]  mem_rd;

ex_mem #(
    .PC_WIDTH      (WIDTH),
    .DATA_WIDTH    (DATA_WIDTH),
    .REGADDR_WIDTH (REGADDR_W)
) EX_MEM (
    .clk             (clk),
    .reset           (reset),
    .ex_reg_write    (id_ex_reg_write),
    .ex_mem_read     (id_ex_mem_read),
    .ex_mem_write    (id_ex_mem_write),
    .ex_branch       (id_ex_branch),
    .ex_pc           (id_ex_pc),
    .ex_alu_result   (ex_alu_result),
    .ex_read_data2   (id_ex_reg_data2),
    .ex_rd           (id_ex_rd),
    .mem_reg_write   (mem_reg_write),
    .mem_mem_read    (mem_mem_read),
    .mem_mem_write   (mem_mem_write),
    .mem_branch      (mem_branch),
    .mem_pc          (mem_pc),
    .mem_alu_result  (mem_alu_result),
    .mem_write_data  (mem_write_data),
    .mem_rd          (mem_rd)
);

// … after you’ve declared mem_rd …
wire [DATA_WIDTH-1:0] mem_read_data;    // <<< add this so .read_data is 16 bits

// 3) MEM stage now drives DMEM with real signals
data_mem #(
    .ADDR_WIDTH($clog2(DMEM_DEPTH)),
    .DATA_WIDTH(DATA_WIDTH),
    .MEMFILE("../IDM/data_init.hex")   // <<< point up into IDM/
) DMEM (
    .clk        (clk),
    .mem_read   (mem_mem_read),
    .mem_write  (mem_mem_write),
    .addr       (mem_alu_result[$clog2(DMEM_DEPTH)-1:0]),
    .write_data (mem_write_data),
    .read_data  (mem_read_data)         // now matches 16‐bit port
);

// MEM/WB pipeline register
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

// TODO: PC update logic: PC + 1 or branch target
assign pc_next = pc_current + 1;

endmodule