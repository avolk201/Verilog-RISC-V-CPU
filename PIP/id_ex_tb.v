`timescale 1ns / 1ps

module tb_id_ex;

    // Parameters
    parameter PC_WIDTH = 12;
    parameter DATA_WIDTH = 16;
    parameter REGADDR_WIDTH = 3;

    // Inputs
    reg clk;
    reg reset;
    reg flush;
    reg id_reg_write;
    reg id_mem_read;
    reg id_mem_write;
    reg [1:0] id_alu_op;
    reg id_alu_src;
    reg id_branch;
    reg [PC_WIDTH-1:0] id_pc;
    reg [DATA_WIDTH-1:0] id_read_data1;
    reg [DATA_WIDTH-1:0] id_read_data2;
    reg [DATA_WIDTH-1:0] id_imm;
    reg [REGADDR_WIDTH-1:0] id_rs;
    reg [REGADDR_WIDTH-1:0] id_rt;
    reg [REGADDR_WIDTH-1:0] id_rd;

    // Outputs
    wire ex_reg_write;
    wire ex_mem_read;
    wire ex_mem_write;
    wire [1:0] ex_alu_op;
    wire ex_alu_src;
    wire ex_branch;
    wire [PC_WIDTH-1:0] ex_pc;
    wire [DATA_WIDTH-1:0] ex_read_data1;
    wire [DATA_WIDTH-1:0] ex_read_data2;
    wire [DATA_WIDTH-1:0] ex_imm;
    wire [REGADDR_WIDTH-1:0] ex_rs;
    wire [REGADDR_WIDTH-1:0] ex_rt;
    wire [REGADDR_WIDTH-1:0] ex_rd;

    // Instantiate the id_ex module
    id_ex #(
        .PC_WIDTH(PC_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .REGADDR_WIDTH(REGADDR_WIDTH)
    ) DUT (
        .clk(clk),
        .reset(reset),
        .flush(flush),
        .id_reg_write(id_reg_write),
        .id_mem_read(id_mem_read),
        .id_mem_write(id_mem_write),
        .id_alu_op(id_alu_op),
        .id_alu_src(id_alu_src),
        .id_branch(id_branch),
        .id_pc(id_pc),
        .id_read_data1(id_read_data1),
        .id_read_data2(id_read_data2),
        .id_imm(id_imm),
        .id_rs(id_rs),
        .id_rt(id_rt),
        .id_rd(id_rd),
        .ex_reg_write(ex_reg_write),
        .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_alu_op(ex_alu_op),
        .ex_alu_src(ex_alu_src),
        .ex_branch(ex_branch),
        .ex_pc(ex_pc),
        .ex_read_data1(ex_read_data1),
        .ex_read_data2(ex_read_data2),
        .ex_imm(ex_imm),
        .ex_rs(ex_rs),
        .ex_rt(ex_rt),
        .ex_rd(ex_rd)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Testbench logic
    initial begin
        // Initialize inputs
        clk = 0;
        reset = 1;
        flush = 0;
        id_reg_write = 0;
        id_mem_read = 0;
        id_mem_write = 0;
        id_alu_op = 2'b00;
        id_alu_src = 0;
        id_branch = 0;
        id_pc = 12'h000;
        id_read_data1 = 16'h0000;
        id_read_data2 = 16'h0000;
        id_imm = 16'h0000;
        id_rs = 3'b000;
        id_rt = 3'b000;
        id_rd = 3'b000;

        // Apply reset
        #10 reset = 0;

        // Apply test values
        #10 id_reg_write = 1;
            id_mem_read = 1;
            id_mem_write = 0;
            id_alu_op = 2'b10;
            id_alu_src = 1;
            id_branch = 1;
            id_pc = 12'hABC;
            id_read_data1 = 16'hAAAA;
            id_read_data2 = 16'hBBBB;
            id_imm = 16'h1234;
            id_rs = 3'b001;
            id_rt = 3'b010;
            id_rd = 3'b011;

        // Observe outputs
        #10 $display("ex_reg_write: %b", ex_reg_write);
            $display("ex_mem_read: %b", ex_mem_read);
            $display("ex_mem_write: %b", ex_mem_write);
            $display("ex_alu_op: %b", ex_alu_op);
            $display("ex_alu_src: %b", ex_alu_src);
            $display("ex_branch: %b", ex_branch);
            $display("ex_pc: %h", ex_pc);
            $display("ex_read_data1: %h", ex_read_data1);
            $display("ex_read_data2: %h", ex_read_data2);
            $display("ex_imm: %h", ex_imm);
            $display("ex_rs: %b", ex_rs);
            $display("ex_rt: %b", ex_rt);
            $display("ex_rd: %b", ex_rd);

        // End simulation
        #20 $finish;
    end

endmodule