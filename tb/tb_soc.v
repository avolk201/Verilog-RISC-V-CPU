//-----------------------------------------------------------------------------
// tb_soc.v - Self-checking testbench for the multi-core SoC
//
// Runs a program from the boot ROM, polls the `tohost` word in shared SRAM for a
// result code, and reports PASS/FAIL. Also:
//   * loops UART tx -> rx so serial programs can self-verify, and decodes the
//     tx line to echo characters to the console;
//   * loops Ethernet GMII tx -> rx (1-cycle delayed) to exercise the MAC.
//
// Configuration:
//   compile-time:  -P tb_soc.NUM_CORES=<n>
//   run-time:      +ROM=<program.rom.hex>  [+RAM=<data.ram.hex>]  [+TIMEOUT=<cycles>]
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_soc;
    parameter NUM_CORES   = 1;
    parameter ROM_DEPTH   = 16384;
    parameter RAM_DEPTH   = 16384;
    parameter TOHOST_WORD = 16380;        // SRAM word holding the result code
    parameter PASS_CODE   = 32'h600D600D;

    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;                 // 100 MHz

    // UART serial loopback + console echo
    wire uart_tx;
    reg  uart_rx = 1;
    always @(posedge clk) uart_rx <= uart_tx;   // loop tx back into rx

    // Ethernet GMII loopback (1-cycle delay models the PHY/cable)
    wire       eth_tx_en;
    wire [7:0] eth_tx_data;
    reg        eth_rx_dv = 0;
    reg  [7:0] eth_rx_data = 0;
    always @(posedge clk) begin
        eth_rx_dv   <= eth_tx_en;
        eth_rx_data <= eth_tx_data;
    end

    wire uart_irq, eth_irq;

    // Memory images are loaded by boot_rom/sram directly from +ROM / +RAM.
    soc_top #(
        .NUM_CORES (NUM_CORES),
        .ROM_DEPTH (ROM_DEPTH),
        .RAM_DEPTH (RAM_DEPTH),
        .ROM_FILE  (""),
        .RAM_FILE  ("")
    ) dut (
        .clk(clk), .rst(rst),
        .uart_rx(uart_rx), .uart_tx(uart_tx), .uart_irq(uart_irq),
        .eth_tx_en(eth_tx_en), .eth_tx_data(eth_tx_data),
        .eth_rx_dv(eth_rx_dv), .eth_rx_data(eth_rx_data), .eth_irq(eth_irq)
    );

    // ---- UART tx line monitor: decode serial bytes and echo to console ----
    parameter UART_DIV = 8;
    reg [15:0] mon_baud = 0;
    reg [3:0]  mon_bit  = 0;
    reg [7:0]  mon_byte = 0;
    reg [1:0]  mon_state = 0;
    integer    nchars = 0;
    always @(posedge clk) begin
        case (mon_state)
            0: if (uart_tx == 0) begin mon_state <= 1; mon_baud <= 0; end
            1: if (mon_baud == UART_DIV/2) begin
                   if (uart_tx == 0) begin mon_state <= 2; mon_bit <= 0; mon_baud <= 0; end
                   else mon_state <= 0;
               end else mon_baud <= mon_baud + 1;
            2: if (mon_baud == UART_DIV-1) begin
                   mon_baud <= 0;
                   mon_byte[mon_bit[2:0]] <= uart_tx;
                   if (mon_bit == 7) begin mon_state <= 3; mon_baud <= 0; end
                   else mon_bit <= mon_bit + 1;
               end else mon_baud <= mon_baud + 1;
            3: if (mon_baud == UART_DIV-1) begin
                   mon_state <= 0; mon_baud <= 0;
                   $write("%c", mon_byte);
                   nchars = nchars + 1;
               end else mon_baud <= mon_baud + 1;
        endcase
    end

    // ---- reset, run, poll for result ----
    integer cycles = 0;
    integer timeout = 200000;
    reg [31:0]  tohost = 0;
    reg [1023:0] rom_name = "program";

    initial begin
        $dumpfile("sim/dump.vcd");
        $dumpvars(0, tb_soc);
        if (!$value$plusargs("ROM=%s", rom_name)) rom_name = "program";
        if (!$value$plusargs("TIMEOUT=%d", timeout)) timeout = 200000;
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;
    end

    initial begin
        wait (rst == 0);
        forever begin
            @(posedge clk);
            cycles = cycles + 1;
            tohost = dut.RAM.mem[TOHOST_WORD];
            if (tohost != 0) begin
                #1;
                if (tohost == PASS_CODE)
                    $display("\n[  PASSED  ] %0s  (cores=%0d, %0d cycles)",
                             rom_name, NUM_CORES, cycles);
                else
                    $display("\n[  FAILED  ] %0s -> 0x%08h (test #%0d, %0d cycles)",
                             rom_name, tohost, tohost & 32'hFF, cycles);
                $finish;
            end
            if (cycles > timeout) begin
                $display("\n[  TIMEOUT ] %0s after %0d cycles (tohost=0x%08h)",
                         rom_name, cycles, tohost);
                $finish;
            end
        end
    end
endmodule
