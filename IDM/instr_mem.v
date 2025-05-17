//----------------------------------------------------------------------------
// Module: instr_mem.v
// Description: Instruction Memory
//----------------------------------------------------------------------------

module instr_mem #(
    parameter ADDR_WIDTH = 9,  // Address width (log2 of memory depth)
    parameter DATA_WIDTH = 12  // Instruction width
) (
    input  [ADDR_WIDTH-1:0] addr,  // Address from PC
    output [DATA_WIDTH-1:0] instr  // Instruction output
);

    // Memory array to store instructions
    reg [DATA_WIDTH-1:0] memory [0:(1<<ADDR_WIDTH)-1];

    // Initialize memory with instructions (optional)
    initial begin
        // Example: Preload some instructions
        memory[0] = 12'b000_001_000001; // load R1, 1
        memory[1] = 12'b010_010_001_011; // add R2, R3
        memory[2] = 12'b101_000000001; // branch if Z
        // Add more instructions as needed
    end

    // Read instruction at the given address
    assign instr = memory[addr];

endmodule

