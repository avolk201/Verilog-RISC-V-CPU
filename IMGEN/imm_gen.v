module imm_gen #(
  parameter IN_WIDTH  = 6,
  parameter OUT_WIDTH = 16
)(
  input  [IN_WIDTH-1:0] imm_in,
  output [OUT_WIDTH-1:0] imm_out
);
