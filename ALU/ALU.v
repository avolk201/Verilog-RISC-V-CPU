`timescale 1ns / 1ps

//----------------------------------------------------------------------------
// Module: alu.v
// A simple 2‑operand ALU with add, xor, pass‑through, and subtract (for mov/ldpc).
//----------------------------------------------------------------------------
module alu #(
    parameter DATA_WIDTH = 16
) (
    input  [DATA_WIDTH-1:0] a,      // operand A (e.g. Rs)
    input  [DATA_WIDTH-1:0] b,      // operand B (e.g. Rt or imm)
    input  [1:0]       alu_op, // 00 = add, 01 = xor, 10 = pass B, others = reserved/zero
    output reg [DATA_WIDTH-1:0] result,
    output                zero  // high if result == 0
);

    // combinational operation
    always @(*) begin
        case (alu_op)
            2'b00: result = a + b;       // ADD
            2'b01: result = a ^ b;       // XOR
            2'b10: result = b;           // PASS‑B (mov/ldpc/load)
            2'b11: result = a - b;       // SUBTRACTION
            default: result = {DATA_WIDTH{1'b0}}; // <<< use DATA_WIDTH not WIDTH
        endcase
    end

    // zero flag
    assign zero = (result == {DATA_WIDTH{1'b0}});

endmodule
