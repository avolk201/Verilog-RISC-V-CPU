//----------------------------------------------------------------------------
// Module: ex_mem.v
// Pipeline register between EX and MEM stages
//----------------------------------------------------------------------------
module ex_mem #(
    parameter PC_WIDTH     = 12,
    parameter DATA_WIDTH   = 16,
    parameter REGADDR_WIDTH = 3
) (
    input                    clk,
    input                    reset,
    // control
    input                    ex_reg_write,
    input                    ex_mem_read,
    input                    ex_mem_write,
    input                    ex_branch,
    // data
    input  [PC_WIDTH-1:0]        ex_pc,
    input  [DATA_WIDTH-1:0]      ex_alu_result,
    input  [DATA_WIDTH-1:0]      ex_read_data2,
    input  [REGADDR_WIDTH-1:0]   ex_rd,
    // outputs to MEM
    output reg               mem_reg_write,
    output reg               mem_mem_read,
    output reg               mem_mem_write,
    output reg               mem_branch,
    output reg [PC_WIDTH-1:0]      mem_pc,
    output reg [DATA_WIDTH-1:0]    mem_alu_result,
    output reg [DATA_WIDTH-1:0]    mem_write_data,
    output reg [REGADDR_WIDTH-1:0] mem_rd
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            { mem_reg_write, mem_mem_read, mem_mem_write,
              mem_branch } <= 0;
            mem_pc         <= 0;
            mem_alu_result <= 0;
            mem_write_data <= 0;
            mem_rd         <= 0;
        end else begin
            mem_reg_write   <= ex_reg_write;
            mem_mem_read    <= ex_mem_read;
            mem_mem_write   <= ex_mem_write;
            mem_branch      <= ex_branch;
            mem_pc          <= ex_pc;
            mem_alu_result  <= ex_alu_result;
            mem_write_data  <= ex_read_data2;
            mem_rd          <= ex_rd;
        end
    end
endmodule