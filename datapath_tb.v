`timescale 1ns / 1ps

module datapath_tb;

    // Testbench signals
    reg clk;
    reg reset;
    reg [3:0] opcode;
    reg [2:0] src_reg;
    reg [2:0] dest_reg;
    reg [15:0] immediate;
    wire [15:0] result;

    // Instantiate the datapath module
    datapath uut (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .src_reg(src_reg),
        .dest_reg(dest_reg),
        .immediate(immediate),
        .result(result)
    );

    // Clock generation
    always #5 clk = ~clk; // 10ns clock period

    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        reset = 0;
        opcode = 4'b0000;
        src_reg = 3'b000;
        dest_reg = 3'b000;
        immediate = 16'b0;

        // Apply reset
        $display("Applying reset...");
        reset = 1;
        #10;
        reset = 0;

        // Test LOAD instruction
        $display("Testing LOAD instruction...");
        opcode = 4'b0001; // LOAD opcode
        dest_reg = 3'b001; // Write to register 1
        immediate = 16'h00FF; // Load value 0x00FF
        #10;
        $display("Result: %h (Expected: 00FF)", result);

        // Test MOV instruction
        $display("Testing MOV instruction...");
        opcode = 4'b0010; // MOV opcode
        src_reg = 3'b001; // Read from register 1
        dest_reg = 3'b010; // Write to register 2
        #10;
        $display("Result: %h (Expected: 00FF)", result);

        // Test ADD instruction
        $display("Testing ADD instruction...");
        opcode = 4'b0011; // ADD opcode
        src_reg = 3'b001; // Read from register 1
        dest_reg = 3'b010; // Add to register 2
        #10;
        $display("Result: %h (Expected: 01FE)", result);

        // Test XOR instruction
        $display("Testing XOR instruction...");
        opcode = 4'b0100; // XOR opcode
        src_reg = 3'b001; // Read from register 1
        dest_reg = 3'b010; // XOR with register 2
        #10;
        $display("Result: %h (Expected: 01FF)", result);

        // End simulation
        $display("Datapath test completed.");
        $stop;
    end

endmodule