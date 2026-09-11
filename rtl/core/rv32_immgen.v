//-----------------------------------------------------------------------------
// rv32_immgen.v - RISC-V immediate generator
// Expands the five RV32I immediate encodings (I,S,B,U,J) to 32 bits.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module rv32_immgen (
    input  [31:0] instr,
    input  [2:0]  imm_type,   // IMT_* below
    output [31:0] imm
);
    localparam IMT_I = 3'd0,
               IMT_S = 3'd1,
               IMT_B = 3'd2,
               IMT_U = 3'd3,
               IMT_J = 3'd4;

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7],
                          instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
                          instr[20], instr[30:21], 1'b0};

    reg [31:0] sel;
    always @(*) begin
        case (imm_type)
            IMT_I:   sel = imm_i;
            IMT_S:   sel = imm_s;
            IMT_B:   sel = imm_b;
            IMT_U:   sel = imm_u;
            IMT_J:   sel = imm_j;
            default: sel = 32'b0;
        endcase
    end
    assign imm = sel;
endmodule
