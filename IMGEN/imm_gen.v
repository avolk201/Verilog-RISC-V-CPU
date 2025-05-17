//----------------------------------------------------------------------------
// Module: imm_gen.v
// Immediate generator: sign-extend or zero-extend instruction immediate
//----------------------------------------------------------------------------
module imm_gen #(
    parameter IN_WIDTH  = 6,   // immediate bits in instruction
    parameter OUT_WIDTH = 16   // full data-path width
) (
    input  [IN_WIDTH-1:0] imm_in,
    output [OUT_WIDTH-1:0] imm_out
);

    // Sign-extend: replicate MSB of imm_in
    assign imm_out = {{(OUT_WIDTH-IN_WIDTH){imm_in[IN_WIDTH-1]}}, imm_in};

endmodule