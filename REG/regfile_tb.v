`timescale 1ns / 1ps

module tb_regfile;
  // Parameters must match your regfile
  localparam DATA_WIDTH    = 16;
  localparam REGADDR_WIDTH = 3;
  localparam NUM_REGS      = 1 << REGADDR_WIDTH;

  // DUT I/O
  reg                          clk;
  reg                          reset;
  reg                          reg_write;
  reg  [REGADDR_WIDTH-1:0]     read_reg1;
  reg  [REGADDR_WIDTH-1:0]     read_reg2;
  reg  [REGADDR_WIDTH-1:0]     write_reg;
  reg  [DATA_WIDTH-1:0]        write_data;
  wire [DATA_WIDTH-1:0]        read_data1;
  wire [DATA_WIDTH-1:0]        read_data2;

  // Instantiate the register file
  regfile #(
    .DATA_WIDTH(DATA_WIDTH),
    .REGADDR_WIDTH(REGADDR_WIDTH)
  ) DUT (
    .clk(clk),
    .reset(reset),
    .reg_write(reg_write),
    .read_reg1(read_reg1),
    .read_reg2(read_reg2),
    .write_reg(write_reg),
    .write_data(write_data),
    .read_data1(read_data1),
    .read_data2(read_data2)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100 MHz clock
  end

  // Test sequence
  integer i;
  reg [DATA_WIDTH-1:0] golden [0:NUM_REGS-1];

  initial begin
    $dumpfile("regfile_tb.vcd");
    $dumpvars(0, tb_regfile);

    // 1) Reset and check all regs = 0
    reset = 1; reg_write = 0;
    read_reg1 = 0; read_reg2 = 1;
    #10;
    for (i = 0; i < NUM_REGS; i = i + 1) begin
      read_reg1 = i; #1;
      if (read_data1 !== 0) $display("ERROR: R%0d != 0 after reset (got %h)", i, read_data1);
    end

    // deassert reset
    reset = 0; #10;

    // 2) Write distinct values into each register
    for (i = 0; i < NUM_REGS; i = i + 1) begin
      golden[i]   = i * 16'h1111;  // some pattern
      reg_write   = 1;
      write_reg   = i;
      write_data  = golden[i];
      #10;                         // wait one clock
    end

    // turn off writes
    reg_write = 0; #10;

    // 3) Read back all registers (two at a time) and compare
    for (i = 0; i < NUM_REGS; i = i + 2) begin
      read_reg1 = i;
      read_reg2 = i+1;
      #1;  // combinational read
      if (read_data1 !== golden[i]) $display("ERROR: R%0d = %h, expected %h", i, read_data1, golden[i]);
      if (read_data2 !== golden[i+1]) $display("ERROR: R%0d = %h, expected %h", i+1, read_data2, golden[i+1]);
      else $display("PASS: R%0d=%h, R%0d=%h", i, read_data1, i+1, read_data2);
      #9;  // move to next clock boundary
    end

    $display("regfile test complete");
    $finish;
  end
endmodule
