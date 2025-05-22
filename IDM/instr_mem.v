`timescale 1ns/1ps

//----------------------------------------------------------------------------
// Module: instr_mem.v
// Description: Instruction Memory
//----------------------------------------------------------------------------

module instr_mem #(
    parameter ADDR_WIDTH = 8,          // = $clog2(IMEM_DEPTH)
    parameter DATA_WIDTH = 12,         // instruction width
    parameter MEMFILE    = "instr_init.hex"
) (
    input  [ADDR_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] instr
);

    // real memory array
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // preload from hex file (no “//…” comments in the .hex!)
    initial begin
        $readmemh(MEMFILE, mem);
    end

    // asynchronous read
    assign instr = mem[addr];

endmodule

