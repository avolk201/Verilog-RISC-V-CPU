`timescale 1ns / 1ps

//----------------------------------------------------------------------------
// Module: alu.v
// A simple 2‑operand ALU with add, xor, pass‑through, subtract, and more.
//----------------------------------------------------------------------------
module alu #(
    parameter DATA_WIDTH = 16
) (
    input  [DATA_WIDTH-1:0] a,      // operand A (e.g. Rs)
    input  [DATA_WIDTH-1:0] b,      // operand B (e.g. Rt or imm)
    input  [2:0]            alu_op, // 3 bits: 000 = add, 001 = xor, 010 = pass B, 011 = sub, 100 = and, etc.
    output reg [DATA_WIDTH-1:0] result,
    output                zero  // high if result == 0
);

    // combinational operation
    always @(*) begin
        case (alu_op)
            3'b000: result = a + b;         // ADD
            3'b001: result = a ^ b;         // XOR
            3'b010: result = b;             // PASS‑B (mov/ldpc/load)
            3'b011: result = a - b;         // SUBTRACTION
            3'b100: result = a & b;         // AND
            3'b101:  result = a * b;        // MUL
            3'b110: result = a / b;
            // Add more operations here as needed
            default: result = {DATA_WIDTH{1'b0}};
        endcase
    end

    // zero flag
    assign zero = (result == {DATA_WIDTH{1'b0}});

endmodule