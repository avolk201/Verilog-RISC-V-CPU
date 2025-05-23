`timescale 1ns / 1ps

//----------------------------------------------------------------------------
// Module: cpu.v
// Top-level pipelined CPU
//----------------------------------------------------------------------------
module cpu #(
    parameter WIDTH       = 15,  // ← was 12
    parameter DATA_WIDTH  = 16,  // data path width
    parameter REGADDR_W   = 4,   // ← now 4 bits
    parameter IMEM_DEPTH  = 256,
    parameter DMEM_DEPTH  = 256
) (
    input                 clk,
    input                 reset
);

// ---------- IF Stage Signals ----------
wire [WIDTH-1:0] pc_next, pc_current;
wire [WIDTH-1:0] instr;

// stall/flush from hazard & jumps
wire        stall, pc_write, if_id_write;
wire        halt;         // NEW from control
wire        real_pc_write = pc_write & ~halt; // real PC write = normal hazard.pc_write AND NOT halted
wire        ldpc;                          // from control
wire        if_id_flush = ldpc;            // flush IF/ID on jump
wire        id_ex_flush = stall || ldpc;   // flush ID/EX on jump

// real IF/ID write-enable: don’t capture any more instructions once halt is asserted
wire real_if_id_write = if_id_write & ~halt;
wire real_if_id_stall = ~real_if_id_write;

// Instantiate program counter
pc #(.WIDTH(WIDTH)) PC (
    .clk(clk),
    .reset(reset),
    .pc_write (real_pc_write),   // use gated write
    .pc_in(pc_next),
    .pc_out(pc_current)
);

// Instruction memory (read-only)
instr_mem #(
    .ADDR_WIDTH($clog2(IMEM_DEPTH)),
    .DATA_WIDTH(WIDTH),
    .MEMFILE("IDM/instr_init.hex")  // <<< point up into IDM/
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
    .stall(real_if_id_stall),          // from hazard detection
    .flush(if_id_flush),          // now flush on jump
    .if_pc(pc_current),
    .if_instr(instr),
    .id_pc(if_id_pc),
    .id_instr(if_id_instr)
);

// ---------- ID Stage Signals ----------
// Instruction decoding
wire [3:0] id_opcode = if_id_instr[15:12];   // bits [15:12]
wire [3:0] id_rd     = if_id_instr[11: 8];   // bits [11:8]
wire [3:0] id_rs     = if_id_instr[ 7: 4];   // bits [7:4] (R‑type Rs)
wire [3:0] id_rt     = if_id_instr[ 3: 0];   // bits [3:0] (R‑type Rt)
wire is_str_reg_indirect = (id_opcode == 4'b1001) && (if_id_instr[3:0] == 4'b0001);



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
wire [2:0] alu_op;
control CONTROL (
    .opcode   (id_opcode),
    .zero     (zero_flag),
    .reg_write(reg_write),
    .alu_src  (alu_src),
    .mem_read (mem_read),
    .mem_write(mem_write),
    .branch   (branch),
    .alu_op   (alu_op),
    .ldpc     (ldpc),                 // hook up new ldpc
    .halt     (halt)         // NEW
);

// build an absolute 12-bit jump target out of the lower 9 bits
wire [WIDTH-1:0] id_jump_target = { 3'b000, if_id_instr[8:0] };

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
wire [2:0] id_ex_alu_op;
wire [DATA_WIDTH-1:0] id_ex_reg_data1, id_ex_reg_data2, id_ex_imm_ext;
wire [3:0] id_ex_rs, id_ex_rt, id_ex_rd;
wire [WIDTH-1:0] id_ex_pc;

// and in the ID→EX boundary also flush on halt
wire real_id_ex_flush = id_ex_flush || halt;

id_ex #(
    .PC_WIDTH       (WIDTH),
    .DATA_WIDTH     (DATA_WIDTH),
    .REGADDR_WIDTH  (REGADDR_W)
) ID_EX (
    .clk            (clk),
    .reset          (reset),
    .flush          (real_id_ex_flush),
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
    // corrected output ports:
    .ex_reg_write   (id_ex_reg_write),
    .ex_mem_read    (id_ex_mem_read),
    .ex_mem_write   (id_ex_mem_write),
    .ex_alu_op      (id_ex_alu_op),
    .ex_alu_src     (id_ex_alu_src),
    .ex_branch      (id_ex_branch),
    .ex_pc          (id_ex_pc),
    .ex_reg_data1   (id_ex_reg_data1),
    .ex_reg_data2   (id_ex_reg_data2),
    .ex_imm_ext     (id_ex_imm_ext),
    .ex_rs          (id_ex_rs),
    .ex_rt          (id_ex_rt),
    .ex_rd          (id_ex_rd),
    .id_is_str_reg_indirect(is_str_reg_indirect),
    .ex_is_str_reg_indirect(ex_is_str_reg_indirect)
);

// … then later, after you’ve declared your ID/EX wires …
// add these two lines so reg_data1/reg_data2 exist at the right width
wire [DATA_WIDTH-1:0] reg_data1, reg_data2;

// hazard detect
hazard HAZARD_UNIT (
  .id_ex_mem_read(id_ex_mem_read),
  .id_ex_rd      (id_ex_rd),
  .if_id_rs      (id_rs),
  .if_id_rt      (id_rt),
  .stall         (stall),
  .pc_write      (pc_write),
  .if_id_write   (if_id_write)
);

// forward unit
wire [1:0] forwardA, forwardB;
forward FORWARD_UNIT (
  .ex_mem_reg_write(mem_reg_write),
  .ex_mem_rd       (mem_rd),
  .wb_reg_write    (wb_reg_write),
  .wb_rd           (wb_rd),
  .id_ex_rs        (id_ex_rs),   // <-- should be output of ID/EX register
  .id_ex_rt        (id_ex_rt),   // <-- should be output of ID/EX register
  .forwardA        (forwardA),
  .forwardB        (forwardB)
);

// after your forward unit instantiation
// --- EX stage forwarding MUXes ---
wire [DATA_WIDTH-1:0] ex_forw_A = 
      (forwardA == 2'b10) ? mem_alu_result :    // from EX/MEM
      (forwardA == 2'b01) ? wb_write_data  :    // from MEM/WB
                             id_ex_reg_data1;   // from ID/EX

wire [DATA_WIDTH-1:0] ex_forw_B = 
      (forwardB == 2'b10) ? mem_alu_result :    // from EX/MEM
      (forwardB == 2'b01) ? wb_write_data  :    // from MEM/WB
                             id_ex_reg_data2;   // from ID/EX

// Fix: use ex_forw_B for store address
wire [DATA_WIDTH-1:0] str_addr = ex_is_str_reg_indirect ? ex_forw_A : id_ex_imm_ext;

// Fix: ensure the correct value is written to memory
wire [DATA_WIDTH-1:0] alu_in2 = (id_ex_mem_write && id_ex_alu_op == 3'b010) ? ex_forw_B :
                                (id_ex_alu_src ? id_ex_imm_ext : ex_forw_B);

// 1) EX stage: forwarding muxes + ALU
// -------------------------------------------------
// use wb_write_data here so that on a “forward from WB” you
// grab the real thing being written (ALU or load data)
wire [DATA_WIDTH-1:0] alu_in1 = (forwardA == 2'b10) ? mem_alu_result :
                               (forwardA == 2'b01) ? wb_write_data :
                                                     id_ex_reg_data1;

wire [DATA_WIDTH-1:0] alu_in2_reg = (forwardB == 2'b10) ? mem_alu_result :
                                   (forwardB == 2'b01) ? wb_write_data :
                                                         id_ex_reg_data2;

wire [DATA_WIDTH-1:0] ex_alu_result;
wire                 zero_flag;

alu #(.DATA_WIDTH(DATA_WIDTH)) ALU_I (
    .a      (alu_in1),
    .b      (alu_in2),
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
    .PC_WIDTH       (WIDTH),
    .DATA_WIDTH     (DATA_WIDTH),
    .REGADDR_WIDTH  (REGADDR_W)
) EX_MEM (
    .clk            (clk),
    .reset          (reset),
    // control inputs from ID/EX
    .ex_reg_write   (id_ex_reg_write),
    .ex_mem_read    (id_ex_mem_read),
    .ex_mem_write   (id_ex_mem_write),
    .ex_branch      (id_ex_branch),
    // data inputs from ALU and ID/EX
    .ex_pc          (id_ex_pc),
    .ex_alu_result  (ex_alu_result),
    .ex_reg_data2   (ex_forw_B), // <-- Correctly forward the value to store
    .ex_rd          (id_ex_rd),
    // outputs to MEM stage
    .mem_reg_write  (mem_reg_write),
    .mem_mem_read   (mem_mem_read),
    .mem_mem_write  (mem_mem_write),
    .mem_branch     (mem_branch),
    .mem_pc         (mem_pc),
    .mem_alu_result (mem_alu_result),
    .mem_write_data (mem_write_data), // <-- Pass the forwarded value
    .mem_rd         (mem_rd)
);

// … after you’ve declared mem_rd …
wire [DATA_WIDTH-1:0] mem_read_data;    // 16-bit read data from DMEM

// 3) MEM stage now drives DMEM with real signals
data_mem #(
    .ADDR_WIDTH  ($clog2(DMEM_DEPTH)),
    .DATA_WIDTH  (DATA_WIDTH),
    .MEMFILE     ("IDM/data_init.hex")
) DMEM (
    .clk         (clk),
    .mem_read    (mem_mem_read),
    .mem_write   (mem_mem_write),
    .addr        (ex_forw_A), // Address from ALU result
    .write_data  (mem_alu_result), // <-- Correct value to write
    .read_data   (mem_read_data)
);

// Pass the correct value to the memory write data
assign mem_write_data = ex_forw_B; // Value from the source register (e.g., R1)

// MEM/WB pipeline register
mem_wb #(
    .DATA_WIDTH    (DATA_WIDTH),
    .REGADDR_WIDTH (REGADDR_W)
) MEM_WB (
    .clk            (clk),
    .reset          (reset),
    // control inputs from EX/MEM
    .mem_reg_write  (mem_reg_write),
    .mem_mem_read   (mem_mem_read),
    // data inputs from MEM stage
    .mem_read_data  (mem_read_data),    // <— and here
    .mem_alu_result (mem_alu_result),
    .mem_rd         (mem_rd),
    // outputs to WB stage / regfile
    .wb_reg_write   (wb_reg_write),
    .wb_mem_to_reg  (wb_mem_to_reg),
    .wb_read_data   (wb_read_data),
    .wb_alu_result  (wb_alu_result),
    .wb_rd          (wb_rd)
);

// PC update logic: either next sequential or a jump
assign pc_next = ldpc
                 ? id_jump_target        // jump target
                 : pc_current + 1;       // normal +1

endmodule