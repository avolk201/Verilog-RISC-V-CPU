//----------------------------------------------------------------------------
// Module: mem_wb.v
// Pipeline register between MEM and WB stages
//----------------------------------------------------------------------------
module mem_wb #(
  parameter DATA_WIDTH     = 16,
  parameter REGADDR_WIDTH  = 4
) (
  input                         clk,
  input                         reset,
  // control
  input                         mem_reg_write,
  input                         mem_mem_read,
  input                         mem_is_jal,
  // data
  input      [DATA_WIDTH-1:0]   mem_read_data,
  input      [DATA_WIDTH-1:0]   mem_alu_result,
  input      [DATA_WIDTH-1:0]   mem_jal_link_value,
  input      [REGADDR_WIDTH-1:0] mem_rd,
  // outputs to WB
  output reg                    wb_reg_write,
  output reg                    wb_mem_to_reg,
  output reg                    wb_is_jal,
  output reg [DATA_WIDTH-1:0]   wb_read_data,
  output reg [DATA_WIDTH-1:0]   wb_alu_result,
  output reg [DATA_WIDTH-1:0]   wb_jal_link_value,
  output reg [REGADDR_WIDTH-1:0] wb_rd
);

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      wb_reg_write   <= 0;
      wb_mem_to_reg  <= 0;
      wb_is_jal         <= 0;
      wb_read_data   <= 0;
      wb_alu_result  <= 0;
      wb_jal_link_value <= 0;
      wb_rd          <= 0;
    end else begin
      wb_reg_write   <= mem_reg_write;
      wb_mem_to_reg  <= mem_mem_read;
      wb_is_jal         <= mem_is_jal;
      wb_read_data   <= mem_read_data;
      wb_alu_result  <= mem_alu_result;
      wb_jal_link_value <= mem_jal_link_value;
      wb_rd          <= mem_rd;
    end
  end
endmodule