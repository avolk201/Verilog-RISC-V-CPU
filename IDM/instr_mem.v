`timescale 1ns/1ps

//----------------------------------------------------------------------------
// Module: instr_mem.v
// Description: Instruction Memory
//----------------------------------------------------------------------------

module instr_mem #(
    parameter ADDR_WIDTH = 8,          // = $clog2(IMEM_DEPTH)
    parameter DATA_WIDTH = 16,         // instruction width
    parameter MEMFILE    = "instr_init.hex"
) (
    input  [ADDR_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] instr
);

    // real memory array
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // preload memory with instructions (no $readmemh)
    initial begin
        integer i;
        // Clear all memory to NOP (0)
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1)
            mem[i] = {DATA_WIDTH{1'b0}};
        // Manually load instructions
        mem[0]  = 16'h2000;
        mem[1]  = 16'h2101;
        mem[2]  = 16'h2200;
        mem[3]  = 16'h2300;
        mem[4]  = 16'h2401;
        mem[5]  = 16'h2519;
        mem[6]  = 16'h2601;
        mem[7]  = 16'h0996;
        mem[8]  = 16'h9081;
        mem[9]  = 16'h0201;
        mem[10] = 16'h0446;
        mem[11] = 16'hB001;
        mem[12] = 16'hB102;
        mem[13] = 16'h1556;
        mem[14] = 16'hE008;
        mem[15] = 16'h7000;
        // The rest remain NOP (0)
    end

    // asynchronous read
    assign instr = mem[addr];

endmodule

