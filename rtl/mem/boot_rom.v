//-----------------------------------------------------------------------------
// boot_rom.v - Shared instruction ROM with NUM_PORTS asynchronous read ports
// All cores execute the same image from a single physical ROM (true shared
// instruction memory). Reads never contend, so instruction fetch is stall-free.
// Unprogrammed locations default to a legal NOP (addi x0, x0, 0).
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module boot_rom #(
    parameter DEPTH     = 16384,          // words
    parameter NUM_PORTS = 2,
    parameter MEMFILE   = ""
) (
    input  [NUM_PORTS*32-1:0] addr,       // byte addresses, one per port
    output [NUM_PORTS*32-1:0] instr       // fetched words, one per port
);
    localparam AW = $clog2(DEPTH);

    reg [31:0] mem [0:DEPTH-1];

    reg [1023:0] fname;
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'h0000_0013; // NOP
        // +ROM=<file> at runtime overrides the MEMFILE parameter.
        if ($value$plusargs("ROM=%s", fname))
            $readmemh(fname, mem);
        else if (MEMFILE != "")
            $readmemh(MEMFILE, mem);
    end

    genvar p;
    generate
        for (p = 0; p < NUM_PORTS; p = p + 1) begin : g_port
            wire [31:0]  a    = addr[p*32 +: 32];
            wire [AW-1:0] idx = a[AW+1:2];   // word index
            assign instr[p*32 +: 32] = mem[idx];
        end
    endgenerate
endmodule
