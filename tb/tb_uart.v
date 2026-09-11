`timescale 1ns/1ps
// Minimal direct-drive testbench for the uart peripheral (bus + loopback).
module tb_uart;
    reg clk=0, rst=1;
    always #5 clk=~clk;

    reg        s_cyc=0, s_we=0;
    reg [31:0] s_addr=0, s_wdata=0;
    reg [3:0]  s_be=4'hF;
    wire       s_ack;
    wire [31:0] s_rdata;
    wire tx, irq;
    reg  rx=1;
    // loopback tx -> rx (1 cycle)
    always @(posedge clk) rx <= tx;

    uart #(.FIFO_DEPTH(16), .DEFAULT_DIV(8)) U (
        .clk(clk), .rst(rst),
        .s_cyc(s_cyc), .s_we(s_we), .s_addr(s_addr), .s_wdata(s_wdata),
        .s_be(s_be), .s_ack(s_ack), .s_rdata(s_rdata),
        .rx(rx), .tx(tx), .irq(irq)
    );

    task bus_write(input [31:0] a, input [31:0] d);
        begin
            @(negedge clk); s_addr=a; s_wdata=d; s_we=1; s_cyc=1;
            @(negedge clk); s_cyc=0; s_we=0;
        end
    endtask
    task bus_read(input [31:0] a, output [31:0] d);
        begin
            @(negedge clk); s_addr=a; s_we=0; s_cyc=1;
            @(posedge clk); #1 d=s_rdata;
            @(negedge clk); s_cyc=0;
        end
    endtask

    integer i;
    reg [31:0] v;
    reg [7:0] ch;
    initial begin
        $dumpfile("sim/tb_uart.vcd"); $dumpvars(0, tb_uart);
        rst=1; repeat(3) @(posedge clk); rst=0; @(posedge clk);
        // program divisor=8, 8N1
        bus_write(32'h0C, 32'h80);   // LCR DLAB
        bus_write(32'h00, 32'h08);   // DLL=8
        bus_write(32'h04, 32'h00);   // DLM=0
        bus_write(32'h0C, 32'h03);   // 8N1
        // send "Hi"
        for (i=0; i<2; i=i+1) begin
            ch = (i==0) ? "H" : "i";
            // wait THRE
            do begin bus_read(32'h14, v); end while ((v & 32'h20)==0);
            bus_write(32'h00, {24'b0,ch});
            // wait DR
            do begin bus_read(32'h14, v); end while ((v & 32'h01)==0);
            bus_read(32'h00, v);
            $display("sent %c got %c (LSR=%h)", ch, v[7:0], v);
            if (v[7:0] !== ch) $display("MISMATCH");
        end
        $display("UART unit test done");
        $finish;
    end
    initial begin #200000; $display("TB timeout tx=%b", tx); $finish; end
endmodule
