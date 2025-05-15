`timescale 1ns / 1ps

module tb_alu;
  // parameters must match your alu.v
  parameter WIDTH = 16;
  
  // DUT I/O
  reg  [WIDTH-1:0] a;
  reg  [WIDTH-1:0] b;
  reg  [1:0]       alu_op;
  wire [WIDTH-1:0] result;
  wire             zero;
  
  // loop counter
  integer i;
  
  // Instantiate the ALU
  alu #(.WIDTH(WIDTH)) DUT (
    .a(a),
    .b(b),
    .alu_op(alu_op),
    .result(result),
    .zero(zero)
  );
  
  // Test vectors
  reg [WIDTH-1:0] a_vec [0:7];
  reg [WIDTH-1:0] b_vec [0:7];
  reg [1:0]       op_vec[0:7];
  reg [WIDTH-1:0] expected [0:7];
  reg             exp_zero [0:7];
  
  initial begin
    // Dump for GTKWave
    $dumpfile("alu_tb.vcd");
    $dumpvars(0, tb_alu);
    
    // Define 8 test cases
    // format: {a, b, alu_op, expected_result, expected_zero}
    a_vec[0] = 16'h0001; b_vec[0] = 16'h0001; op_vec[0] = 2'b00; expected[0] = 16'h0002; exp_zero[0] = 1'b0; // 1+1=2
    a_vec[1] = 16'h0005; b_vec[1] = 16'h0003; op_vec[1] = 2'b01; expected[1] = 16'h0006; exp_zero[1] = 1'b0; // 5^3=6
    a_vec[2] = 16'h00FF; b_vec[2] = 16'h0001; op_vec[2] = 2'b10; expected[2] = 16'h0001; exp_zero[2] = 1'b0; // pass B
    a_vec[3] = 16'h000A; b_vec[3] = 16'h0003; op_vec[3] = 2'b11; expected[3] = 16'h0007; exp_zero[3] = 1'b0; // 10-3=7
    a_vec[4] = 16'h0008; b_vec[4] = 16'h0008; op_vec[4] = 2'b11; expected[4] = 16'h0000; exp_zero[4] = 1'b1; // 8-8=0 -> zero
    a_vec[5] = 16'h1234; b_vec[5] = 16'h4321; op_vec[5] = 2'b00; expected[5] = 16'h5555; exp_zero[5] = 1'b0; // add
    a_vec[6] = 16'hFFFF; b_vec[6] = 16'h0000; op_vec[6] = 2'b01; expected[6] = 16'hFFFF; exp_zero[6] = 1'b0; // xor
    a_vec[7] = 16'hABCD; b_vec[7] = 16'h0010; op_vec[7] = 2'b10; expected[7] = 16'h0010; exp_zero[7] = 1'b0; // pass B
    
    // Apply test vectors
    for (i = 0; i < 8; i = i + 1) begin
      // drive inputs
      a      = a_vec[i];
      b      = b_vec[i];
      alu_op = op_vec[i];
      
      // wait for combinational result to settle
      #5;
      
      // check
      if (result !== expected[i] || zero !== exp_zero[i]) begin
        $display("FAILED case %0d: a=%h b=%h op=%b => got result=%h zero=%b, expected %h/%b",
                 i, a, b, alu_op, result, zero, expected[i], exp_zero[i]);
      end else begin
        $display("PASSED case %0d", i);
      end
    end
    
    $display("All tests done.");
    $finish;
  end
endmodule
