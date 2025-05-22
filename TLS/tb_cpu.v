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

    // expose each DMEM word as a wire so it *can* be dumped
    wire [DATA_WIDTH-1:0] dmem0  = DUT.DMEM.memory[0];
    wire [DATA_WIDTH-1:0] dmem1  = DUT.DMEM.memory[1];
    wire [DATA_WIDTH-1:0] dmem2  = DUT.DMEM.memory[2];
    wire [DATA_WIDTH-1:0] dmem3  = DUT.DMEM.memory[3];
    wire [DATA_WIDTH-1:0] dmem4  = DUT.DMEM.memory[4];
    wire [DATA_WIDTH-1:0] dmem5  = DUT.DMEM.memory[5];
    wire [DATA_WIDTH-1:0] dmem6  = DUT.DMEM.memory[6];
    wire [DATA_WIDTH-1:0] dmem7  = DUT.DMEM.memory[7];
    wire [DATA_WIDTH-1:0] dmem8  = DUT.DMEM.memory[8];
    wire [DATA_WIDTH-1:0] dmem9  = DUT.DMEM.memory[9];
    wire [DATA_WIDTH-1:0] dmem10 = DUT.DMEM.memory[10];
    wire [DATA_WIDTH-1:0] dmem11 = DUT.DMEM.memory[11];
    wire [DATA_WIDTH-1:0] dmem12 = DUT.DMEM.memory[12];
    wire [DATA_WIDTH-1:0] dmem13 = DUT.DMEM.memory[13];
    wire [DATA_WIDTH-1:0] dmem14 = DUT.DMEM.memory[14];
    wire [DATA_WIDTH-1:0] dmem15 = DUT.DMEM.memory[15];

    wire [DATA_WIDTH-1:0] r1 = DUT.ID_REGFILE.regs[1];
    wire [DATA_WIDTH-1:0] r2 = DUT.ID_REGFILE.regs[2];

    initial begin
        // Dump waveforms
        $dumpfile("tb_cpu.vcd");
        // dump the entire DUT plus both memories one level deeper
        $dumpvars(0, tb_cpu);
        // now dump your tapped wires
        $dumpvars(1, dmem0, dmem1, dmem2,dmem3,
                  dmem4, dmem5, dmem6,dmem7,
                  dmem8, dmem9, dmem10,dmem11,
                  dmem12,dmem13,dmem14,dmem15);

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
        #200 $display("R1=%0d, R2=%0d", r1, r2);
    end

    initial begin
        #250 $display("R1=%0d, R2=%0d", r1, r2);
    end

endmodule