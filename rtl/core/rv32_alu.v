//-----------------------------------------------------------------------------
// rv32_alu.v - RISC-V arithmetic/logic unit (RV32I base + M extension)
// Combinational. ALU_* encodings are defined below and produced by the main
// decoder. The `zero` output supports branch fast-paths.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module rv32_alu #(
    parameter SYNTHETIC = 1   // 0 = behavioural (fast sim), 1 = synth-friendly
) (
    input  [31:0] a,
    input  [31:0] b,
    input  [4:0]  alu_op,
    output reg [31:0] result,
    output        zero
);
    // ALU operation encodings
    localparam ALU_ADD    = 5'd0,
               ALU_SUB    = 5'd1,
               ALU_SLL    = 5'd2,
               ALU_SLT    = 5'd3,
               ALU_SLTU   = 5'd4,
               ALU_XOR    = 5'd5,
               ALU_SRL    = 5'd6,
               ALU_SRA    = 5'd7,
               ALU_OR     = 5'd8,
               ALU_AND    = 5'd9,
               ALU_MUL    = 5'd10,
               ALU_MULH   = 5'd11,
               ALU_MULHSU = 5'd12,
               ALU_MULHU  = 5'd13,
               ALU_DIV    = 5'd14,
               ALU_DIVU   = 5'd15,
               ALU_REM    = 5'd16,
               ALU_REMU   = 5'd17,
               ALU_PASS_B = 5'd18;   // result = b (LUI)

    // 64-bit products / dividends
    wire signed [63:0] p_ss = $signed(a)        * $signed(b);
    wire signed [63:0] p_su = $signed(a)        * $signed({1'b0, b});
    wire        [63:0] p_uu = {32'b0, a}        * {32'b0, b};

    // Division-by-zero results follow the RISC-V spec:
    //   DIV/REM  by 0 -> -1 / dividend ;  DIVU/REMU by 0 -> all-ones / dividend
    wire signed [31:0] div_s  = (b == 0) ? -32'sd1            : ($signed(a) / $signed(b));
    wire signed [31:0] rem_s  = (b == 0) ? $signed(a)         : ($signed(a) % $signed(b));
    wire        [31:0] div_u  = (b == 0) ? 32'hFFFFFFFF       : (a / b);
    wire        [31:0] rem_u  = (b == 0) ? a                  : (a % b);

    always @(*) begin
        case (alu_op)
            ALU_ADD:    result = a + b;
            ALU_SUB:    result = a - b;
            ALU_SLL:    result = a << b[4:0];
            ALU_SLT:    result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU:   result = (a < b) ? 32'd1 : 32'd0;
            ALU_XOR:    result = a ^ b;
            ALU_SRL:    result = a >> b[4:0];
            ALU_SRA:    result = $unsigned($signed(a) >>> b[4:0]);
            ALU_OR:     result = a | b;
            ALU_AND:    result = a & b;
            ALU_MUL:    result = p_ss[31:0];
            ALU_MULH:   result = p_ss[63:32];
            ALU_MULHSU: result = p_su[63:32];
            ALU_MULHU:  result = p_uu[63:32];
            ALU_DIV:    result = div_s;
            ALU_DIVU:   result = div_u;
            ALU_REM:    result = rem_s;
            ALU_REMU:   result = rem_u;
            ALU_PASS_B: result = b;
            default:    result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
endmodule
