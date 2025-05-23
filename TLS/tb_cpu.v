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

        // Initialize
        clk   = 0;
        reset = 1;
        #1       reset = 0;   // deassert *before* first posedge at t=5ns
        #400;
        $finish;
    end

    // Print the final register values
    initial begin
        #400;
        $display("Final register values:");
        $display("r0: %d", r0);
        $display("r1: %d", r1);
        $display("r2: %d", r2);
        $display("r3: %d", r3);
        $display("r4: %d", r4);
        $display("r5: %d", r5);
        $display("r6: %d", r6);
        $display("r7: %d", r7);
    end

endmodule