`timescale 1ns / 1ps

//----------------------------------------------------------------------------
// Module: alu.v
// A simple 2‑operand ALU with add, xor, and pass‑through (for mov/ldpc).
//----------------------------------------------------------------------------
module alu #(
    parameter WIDTH = 16
) (
    input  [WIDTH-1:0] a,      // operand A (e.g. Rs)
    input  [WIDTH-1:0] b,      // operand B (e.g. Rt or imm)
    input  [1:0]       alu_op, // 00 = add, 01 = xor, 10 = pass B, others = reserved/zero
    output reg [WIDTH-1:0] result,
    output                zero  // high if result == 0
);

    // combinational operation
    always @(*) begin
        case (alu_op)
            2'b00: result = a + b;       // ADD
            2'b01: result = a ^ b;       // XOR
            2'b10: result = b;           // PASS‑B (mov/ldpc/load)
            2'b11: result = a - b;       // SUBTRACTION
            default: result = {WIDTH{1'b0}};
        endcase
    end

    // zero flag
    assign zero = (result == {WIDTH{1'b0}});

endmodule
