`timescale 1ns / 1ps

module fsm_tb;

    // Testbench signals
    reg clk;
    reg reset;
    reg [3:0] opcode; // Opcode input (not used in this FSM but can be extended)
    wire [2:0] state; // Current state output
    wire [7:0] control_signals; // Control signals output

    // Instantiate the FSM module
    fsm uut (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .state(state),
        .control_signals(control_signals)
    );

    // Clock generation
    always #5 clk = ~clk; // 10ns clock period

    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        reset = 0;
        opcode = 4'b0000;

        // Enable waveform dump for GTKWave
        $dumpfile("fsm_tb.vcd"); // Specify the dump file name
        $dumpvars(0, fsm_tb);    // Dump all variables in the testbench

        // Apply reset
        $display("Applying reset...");
        reset = 1;
        #10;
        reset = 0;

        // Wait for state transitions
        $display("Starting FSM test...");
        #10; // Wait for FETCH
        $display("State: %b, Control Signals: %b", state, control_signals);

        #10; // Wait for DECODE
        $display("State: %b, Control Signals: %b", state, control_signals);

        #10; // Wait for EXECUTE
        $display("State: %b, Control Signals: %b", state, control_signals);

        #10; // Wait for WRITEBACK
        $display("State: %b, Control Signals: %b", state, control_signals);

        #10; // Back to FETCH
        $display("State: %b, Control Signals: %b", state, control_signals);

        // End simulation
        $display("FSM test completed.");
        $stop;
    end

endmodule