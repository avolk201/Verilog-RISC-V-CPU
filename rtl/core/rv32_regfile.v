//-----------------------------------------------------------------------------
// rv32_regfile.v - RISC-V register file
// 32 x 32-bit registers, two asynchronous read ports, one synchronous write
// port. x0 is hard-wired to zero. Implements internal write-through so a
// read of the register being written this cycle returns the new value
// (removes the common WB->ID bypass case for back-to-back producers).
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module rv32_regfile (
    input              clk,
    input              we,        // write enable
    input  [4:0]       waddr,     // rd
    input  [31:0]      wdata,
    input  [4:0]       raddr1,    // rs1
    input  [4:0]       raddr2,    // rs2
    output [31:0]      rdata1,
    output [31:0]      rdata2
);
    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) regs[i] = 32'b0;
    end

    always @(posedge clk) begin
        if (we && (waddr != 5'b0))
            regs[waddr] <= wdata;
    end

    // x0 always reads zero; otherwise write-through then memory.
    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 :
                    (we && (waddr == raddr1)) ? wdata : regs[raddr1];
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 :
                    (we && (waddr == raddr2)) ? wdata : regs[raddr2];
endmodule
