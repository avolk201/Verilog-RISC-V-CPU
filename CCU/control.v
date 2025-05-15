module control (
  input  [2:0] opcode,
  output reg       reg_write,
  output reg       mem_read,
  output reg       mem_write,
  output reg [1:0] alu_op,
  output reg       alu_src,     // choose immediate vs. reg
  output reg       branch,
  output reg       ldpc
);
