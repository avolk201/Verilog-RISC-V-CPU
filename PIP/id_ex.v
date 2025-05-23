//----------------------------------------------------------------------------
// Module: id_ex.v
// Pipeline register between ID and EX stages
//----------------------------------------------------------------------------
module id_ex #(
  parameter PC_WIDTH       = 15,
  parameter DATA_WIDTH     = 16,
  parameter REGADDR_WIDTH  = 4
) (
  input                          clk,
  input                          reset,
  input                          flush,
  // control
  input                          id_reg_write,
  input                          id_mem_read,
  input                          id_mem_write,
  input          [1:0]           id_alu_op,
  input                          id_alu_src,
  input                          id_branch,
  // data
  input   [PC_WIDTH-1:0]         id_pc,
  input   [DATA_WIDTH-1:0]       id_read_data1,
  input   [DATA_WIDTH-1:0]       id_read_data2,
  input   [DATA_WIDTH-1:0]       id_imm,
  input   [REGADDR_WIDTH-1:0]    id_rs,
  input   [REGADDR_WIDTH-1:0]    id_rt,
  input   [REGADDR_WIDTH-1:0]    id_rd,
  // outputs
  output reg                     ex_reg_write,
  output reg                     ex_mem_read,
  output reg                     ex_mem_write,
  output reg [1:0]               ex_alu_op,
  output reg                     ex_alu_src,
  output reg                     ex_branch,
  output reg [PC_WIDTH-1:0]      ex_pc,
  output reg [DATA_WIDTH-1:0]    ex_reg_data1,
  output reg [DATA_WIDTH-1:0]    ex_reg_data2,
  output reg [DATA_WIDTH-1:0]    ex_imm_ext,
  output reg [REGADDR_WIDTH-1:0] ex_rs,
  output reg [REGADDR_WIDTH-1:0] ex_rt,
  output reg [REGADDR_WIDTH-1:0] ex_rd
);

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      ex_reg_write  <= 0;
      ex_mem_read   <= 0;
      ex_mem_write  <= 0;
      ex_alu_op     <= 2'b00;
      ex_alu_src    <= 0;
      ex_branch     <= 0;
      ex_pc         <= 0;
      ex_reg_data1  <= 0;
      ex_reg_data2  <= 0;
      ex_imm_ext    <= 0;
      ex_rs         <= 0;
      ex_rt         <= 0;
      ex_rd         <= 0;
    end else if (flush) begin
      // squash everything on a bubble
      ex_reg_write  <= 0;
      ex_mem_read   <= 0;
      ex_mem_write  <= 0;
      ex_branch     <= 0;
      ex_alu_op     <= 2'b00;
      ex_alu_src    <= 0;
      ex_pc         <= 0;
      ex_reg_data1  <= 0;
      ex_reg_data2  <= 0;
      ex_imm_ext    <= 0;
      ex_rs         <= 0;
      ex_rt         <= 0;
      ex_rd         <= 0;
    end else begin
      ex_reg_write  <= id_reg_write;
      ex_mem_read   <= id_mem_read;
      ex_mem_write  <= id_mem_write;
      ex_alu_op     <= id_alu_op;
      ex_alu_src    <= id_alu_src;
      ex_branch     <= id_branch;
      ex_pc         <= id_pc;
      ex_reg_data1  <= id_read_data1;
      ex_reg_data2  <= id_read_data2;
      ex_imm_ext    <= id_imm;
      ex_rs         <= id_rs;
      ex_rt         <= id_rt;
      ex_rd         <= id_rd;
    end
  end
endmodule