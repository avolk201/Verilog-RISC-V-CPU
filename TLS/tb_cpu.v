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
        #200;
        $finish;
    end

    // Monitor Program Counter and fetched instruction
    initial begin
        $display("Time    PC     INSTR        ALU_OUT");
        //  %0t = time, %0h = PC,   %0b = instr, %0d = ALU result
        $monitor("%0t   %0h   %0b   %0d",
                 $time,
                 DUT.PC.pc_out,
                 DUT.IMEM.instr,
                 DUT.ALU.result    );  // ← watch the ALU inside the CPU
    end

    integer i;
    initial begin
        #250;
        $display("final DMEM contents:");
        for (i = 0; i < 16; i = i + 1)
            $display("DMEM[%0d] = %0h", i, tb_cpu.DUT.DMEM.memory[i]);
    end
    initial begin
        #250;
        $display("final ID_REGFILE contents:");
        for (i = 0; i < 8; i = i + 1)
            $display("R[%0d] = %0h", i, tb_cpu.DUT.ID_REGFILE.regs[i]);
    end

endmodule