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

// TODO: instantiate ID stage (control, regfile, imm_gen)
// TODO: instantiate ID/EX reg
// TODO: instantiate EX stage (forwarding, ALU)
// TODO: instantiate EX/MEM reg
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