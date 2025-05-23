`timescale 1ns/1ps

module tb_cpu;
    // Parameters
    parameter WIDTH      = 12;
    parameter DATA_WIDTH = 16;

    // Clock and reset
    reg clk;
    reg reset;

    // Instantiate the CPU
    cpu #(
        .WIDTH      (WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) DUT (
        .clk   (clk),
        .reset (reset)
    );

    // Clock generation: 10 ns period
    always #5 clk = ~clk;

    // in tb_cpu.v (dump section)
    wire [DATA_WIDTH-1:0] r0 = DUT.ID_REGFILE.regs[0];
    wire [DATA_WIDTH-1:0] r1 = DUT.ID_REGFILE.regs[1];
    wire [DATA_WIDTH-1:0] r2 = DUT.ID_REGFILE.regs[2];
    wire [DATA_WIDTH-1:0] r3 = DUT.ID_REGFILE.regs[3];
    wire [DATA_WIDTH-1:0] r4 = DUT.ID_REGFILE.regs[4];
    wire [DATA_WIDTH-1:0] r5 = DUT.ID_REGFILE.regs[5];
    wire [DATA_WIDTH-1:0] r6 = DUT.ID_REGFILE.regs[6];
    wire [DATA_WIDTH-1:0] r7 = DUT.ID_REGFILE.regs[7];
    wire [15:0] alu_in1 = DUT.alu_in1;
    wire [15:0] alu_in2 = DUT.alu_in2;

    wire        ex_wb       = DUT.EX_MEM.mem_reg_write;
    wire [2:0]  ex_rd       = DUT.EX_MEM.mem_rd;
    wire        wb_wb       = DUT.MEM_WB.wb_reg_write;
    wire [2:0]  wb_rd       = DUT.MEM_WB.wb_rd;
    wire [2:0] fwd_rs = DUT.ID_EX.ex_rs;
    wire [2:0] fwd_rt = DUT.ID_EX.ex_rt;
    wire [1:0] fwdA   = DUT.FORWARD_UNIT.forwardA;
    wire [1:0] fwdB   = DUT.FORWARD_UNIT.forwardB;

    initial begin
        // Dump waveforms
        $dumpfile("tb_cpu.vcd");
        // dump the entire DUT plus both memories one level deeper
        $dumpvars(0, tb_cpu);
        // now dump your tapped wires
        $dumpvars(1, r0, r1, r2, r3, r4, r5, r6, r7);

        // Initialize
        clk   = 0;
        reset = 1;
        #1       reset = 0;   // deassert *before* first posedge at t=5ns
        #400;
        $finish;
    end

    // Monitor Program Counter and fetched instruction
    always @(negedge clk) begin
        $display("T=%0t | ID_EX: rs=%0d rt=%0d | EX_MEM: rd=%0d | MEM_WB: rd=%0d | fwdA=%b fwdB=%b | stall=%b flush=%b",
            $time, fwd_rs, fwd_rt, ex_rd, wb_rd, fwdA, fwdB, DUT.stall, DUT.id_ex_flush);
        $display("    REGFILE: r0=%0d r1=%0d r2=%0d r3=%0d r4=%0d r5=%0d r6=%0d r7=%0d",
            r0, r1, r2, r3, r4, r5, r6, r7);
        $display("    WB: reg_write=%b rd=%0d write_data=%0d", DUT.wb_reg_write, DUT.wb_rd, DUT.wb_write_data);
        $display("    ALU: in1=%0d in2=%0d result=%0d", DUT.alu_in1, DUT.alu_in2, DUT.ALU_I.result);
    end
    integer i;
    initial begin
        #450;
        $display("final ID_REGFILE contents:");
        for (i = 0; i < 8; i = i + 1)
            $display("R[%0d] = %0h", i, tb_cpu.DUT.ID_REGFILE.regs[i]);
    end

endmodule