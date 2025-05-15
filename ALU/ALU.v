module alu #(
  parameter WIDTH = 16
)(
  input  [WIDTH-1:0] a,
  input  [WIDTH-1:0] b,
  input  [1:0]       alu_op,   // 00=add, 01=xor, 10=pass b (for mov), …
  output [WIDTH-1:0] result,
  output             zero
);
