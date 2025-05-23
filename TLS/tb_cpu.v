`timescale 1ns/1ps

module tb_cpu;
    // Parameters
    parameter WIDTH      = 16;
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
    wire [DATA_WIDTH-1:0] r8  = DUT.ID_REGFILE.regs[8];
    wire [DATA_WIDTH-1:0] r9  = DUT.ID_REGFILE.regs[9];
    wire [DATA_WIDTH-1:0] r10 = DUT.ID_REGFILE.regs[10];
    wire [DATA_WIDTH-1:0] r11 = DUT.ID_REGFILE.regs[11];
    wire [DATA_WIDTH-1:0] r12 = DUT.ID_REGFILE.regs[12];
    wire [DATA_WIDTH-1:0] r13 = DUT.ID_REGFILE.regs[13];
    wire [DATA_WIDTH-1:0] r14 = DUT.ID_REGFILE.regs[14];
    wire [DATA_WIDTH-1:0] r15 = DUT.ID_REGFILE.regs[15];

    initial begin
        // Dump waveforms
        $dumpfile("tb_cpu.vcd");
        // dump the entire DUT plus both memories one level deeper
        $dumpvars(0, tb_cpu);

        // Initialize
        clk   = 0;
        reset = 1;
        #1       reset = 0;   // deassert *before* first posedge at t=5ns
        #1000;
        $finish;
    end

    // Print the final register values
    initial begin
        #1000;
        $display("Final register values:");
        $display("r0: %d", r0);
        $display("r1: %d", r1);
        $display("r2: %d", r2);
        $display("r3: %d", r3);
        $display("r4: %d", r4);
        $display("r5: %d", r5);
        $display("r6: %d", r6);
        $display("r7: %d", r7);
        $display("r8 : %d", r8);
        $display("r9 : %d", r9);
        $display("r10: %d", r10);
        $display("r11: %d", r11);
        $display("r12: %d", r12);
        $display("r13: %d", r13);
        $display("r14: %d", r14);
        $display("r15: %d", r15);
    end

    initial begin
        #1000;
        $writememh("data_mem_out.hex", DUT.DMEM.memory);
    end

endmodule