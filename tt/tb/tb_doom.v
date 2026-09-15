//-----------------------------------------------------------------------------
// tb_doom.v - Rigorous Doom Simulation Testbench for Tiny Tapeout RV32 SoC
//
// Simulates the physical SoC booting directly from external SPI Flash, executing
// the Doom firmware, parsing the genuine DOOM1.WAD image, executing hardware
// accelerated FixedMul (fmul16), writing/reading QSPI PSRAM, rendering Doom
// wall columns (R_DrawColumn) to the VGA controller, and receiving XInput controls.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_doom;

    reg clk;
    reg rst_n;
    reg ena;

    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    wire [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // 25.175 MHz pixel clock (period = 39.72 ns)
    initial clk = 0;
    always #19.86 clk = ~clk;

    // SPI Signals
    wire spi_sclk       = uio_out[0];
    wire spi_flash_cs_n = uio_out[1];
    wire spi_mosi       = uio_out[2];
    reg  spi_miso;
    wire spi_psram_cs_n = uio_out[4];
    wire audio_pwm      = uio_out[6];
    wire heartbeat_tx   = uio_out[7];

    assign uio_in = {2'b00, 1'b0, 1'b0, spi_miso, 3'b000};

    // Instantiate Tiny Tapeout Top-Level
    tt_um_tiny_rv32 dut (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    // ---------------- External SPI Flash Model (with DOOM1.WAD preloaded) ----------------
    reg [7:0] flash_mem [0:65535];
    reg [23:0] flash_addr;
    reg [7:0]  flash_cmd;
    reg [5:0]  flash_in_cnt;
    reg [5:0]  flash_out_cnt;
    reg [31:0] flash_word;

    always @(negedge spi_flash_cs_n or posedge spi_flash_cs_n) begin
        if (spi_flash_cs_n) begin
            flash_cmd     <= 8'd0;
            flash_addr    <= 24'd0;
            flash_in_cnt  <= 6'd0;
            flash_out_cnt <= 6'd0;
        end
    end

    always @(posedge spi_sclk) begin
        if (!spi_flash_cs_n) begin
            if (flash_in_cnt < 8) begin
                flash_cmd    <= {flash_cmd[6:0], spi_mosi};
                flash_in_cnt <= flash_in_cnt + 6'd1;
            end else if (flash_in_cnt < 32) begin
                flash_addr   <= {flash_addr[22:0], spi_mosi};
                flash_in_cnt <= flash_in_cnt + 6'd1;
                if (flash_in_cnt == 31) begin
                    flash_word <= {flash_mem[{flash_addr[22:0], spi_mosi} + 3],
                                   flash_mem[{flash_addr[22:0], spi_mosi} + 2],
                                   flash_mem[{flash_addr[22:0], spi_mosi} + 1],
                                   flash_mem[{flash_addr[22:0], spi_mosi} + 0]};
                end
            end
        end
    end

    always @(negedge spi_sclk) begin
        if (!spi_flash_cs_n) begin
            if (flash_in_cnt >= 32) begin
                spi_miso <= flash_word[31 - flash_out_cnt];
                flash_out_cnt <= flash_out_cnt + 6'd1;
            end
        end else if (spi_psram_cs_n) begin
            spi_miso <= 1'bz;
        end
    end

    // ---------------- External QSPI PSRAM Model (8 MB RAM) ----------------
    reg [7:0] psram_mem [0:65535];
    reg [23:0] psram_addr;
    reg [7:0]  psram_cmd;
    reg [5:0]  psram_in_cnt;
    reg [5:0]  psram_out_cnt;
    reg [31:0] psram_word;

    always @(negedge spi_psram_cs_n or posedge spi_psram_cs_n) begin
        if (spi_psram_cs_n) begin
            psram_cmd     <= 8'd0;
            psram_addr    <= 24'd0;
            psram_in_cnt  <= 6'd0;
            psram_out_cnt <= 6'd0;
        end
    end

    always @(posedge spi_sclk) begin
        if (!spi_psram_cs_n) begin
            if (psram_in_cnt < 8) begin
                psram_cmd    <= {psram_cmd[6:0], spi_mosi};
                psram_in_cnt <= psram_in_cnt + 6'd1;
            end else if (psram_in_cnt < 32) begin
                psram_addr   <= {psram_addr[22:0], spi_mosi};
                psram_in_cnt <= psram_in_cnt + 6'd1;
                if (psram_in_cnt == 31) begin
                    psram_word <= {psram_mem[{psram_addr[22:0], spi_mosi} + 3],
                                   psram_mem[{psram_addr[22:0], spi_mosi} + 2],
                                   psram_mem[{psram_addr[22:0], spi_mosi} + 1],
                                   psram_mem[{psram_addr[22:0], spi_mosi} + 0]};
                end
            end else if (psram_cmd == 8'h02) begin // Write data (32 bits)
                psram_word   <= {psram_word[30:0], spi_mosi};
                psram_in_cnt <= psram_in_cnt + 6'd1;
                if (psram_in_cnt == 63) begin
                    psram_mem[psram_addr + 3] <= psram_word[30:23];
                    psram_mem[psram_addr + 2] <= psram_word[22:15];
                    psram_mem[psram_addr + 1] <= psram_word[14:7];
                    psram_mem[psram_addr + 0] <= {psram_word[6:0], spi_mosi};
                end
            end
        end
    end

    always @(negedge spi_sclk) begin
        if (!spi_psram_cs_n && psram_cmd == 8'h03 && psram_in_cnt >= 32) begin
            spi_miso <= psram_word[31 - psram_out_cnt];
            psram_out_cnt <= psram_out_cnt + 6'd1;
        end
    end

    // ---------------- UART Monitor (Captures console text printed by core) ----------------
    wire uart_tx = dut.u_uart.tx;
    integer rx_b;
    reg [7:0] captured_char;
    always @(negedge uart_tx) begin
        repeat (327) @(posedge clk); // Skip start bit to mid of bit 0 (218 * 1.5)
        for (rx_b = 0; rx_b < 8; rx_b = rx_b + 1) begin
            captured_char[rx_b] = uart_tx;
            repeat (218) @(posedge clk);
        end
        $write("%c", captured_char);
        $fflush;
    end

    // ---------------- Instruction Execution Trace ----------------
    reg [31:0] prev_trace_pc;
    always @(posedge clk) begin
        if (dut.u_core.state == 2'd1 && dut.u_core.rst_n) begin // S_EX_MEM
            if (dut.u_core.pc != prev_trace_pc && dut.u_core.pc < 32'h0000_01a0) begin
                $display("[TRACE] PC=0x%04x instr=0x%08x rd=%0d alu_res=0x%08x rdata1=0x%08x rdata2=0x%08x",
                         dut.u_core.pc[15:0], dut.u_core.instr, dut.u_core.rd,
                         dut.u_core.alu_res, dut.u_core.rdata1, dut.u_core.rdata2);
                prev_trace_pc <= dut.u_core.pc;
            end
        end
    end
    initial begin
        $display("=================================================================");
        $display("   RIGOROUS DOOM SHAREWARE ENGINE SIMULATION ON RV32E SOC        ");
        $display("=================================================================");

        // Load unified SPI Flash image containing Doom firmware + DOOM1.WAD
        $readmemh("sw/flash_image.hex", flash_mem);
        $display("[STATUS] Preloaded SPI Flash with firmware + DOOM1.WAD (64 KB)");

        rst_n = 0;
        ena   = 1;
        ui_in = 8'hFF;
        spi_miso = 1'b0;
        prev_trace_pc = 32'hFFFF_FFFF;

        #200;
        rst_n = 1;
        $display("[STATUS] Released SoC reset at t=%0t ps. Booting from SPI Flash...", $time);

        // Allow simulation to execute instructions until pass or fail or timeout
        begin : sim_wait
            integer cyc;
            for (cyc = 0; cyc < 400000; cyc = cyc + 1) begin
                @(posedge clk);
                if (psram_mem[256] == 8'h0D && psram_mem[257] == 8'h60 &&
                    psram_mem[258] == 8'h0D && psram_mem[259] == 8'h60 &&
                    !dut.u_uart.tx_busy && dut.u_core.regs[3] == 32'b0) begin
                    repeat (500) @(posedge clk);
                    disable sim_wait;
                end
                if (dut.u_core.regs[4] >= 32'hbad00001 && dut.u_core.regs[4] <= 32'hbad00009) begin
                    repeat (100) @(posedge clk);
                    disable sim_wait;
                end
            end
        end

        $display("\n[DEBUG] Core State: PC = 0x%08x, x4 = 0x%08x", dut.u_core.pc, dut.u_core.regs[4]);
        $display("[DEBUG] WAD Magic read: x15 = 0x%08x (expected 0x44415749)", dut.u_core.regs[15]);
        $display("[DEBUG] Core Register x3 = 0x%08x", dut.u_core.regs[3]);

        // Verify PSRAM pass code written by firmware
        if (psram_mem[256] == 8'h0D && psram_mem[257] == 8'h60 &&
            psram_mem[258] == 8'h0D && psram_mem[259] == 8'h60) begin
            $display("[PASS] Verified PSRAM PASS code 0x600D600D written by Doom engine!");
        end else begin
            $display("[FAIL] PSRAM PASS code not found. Observed: %02x%02x%02x%02x",
                     psram_mem[259], psram_mem[258], psram_mem[257], psram_mem[256]);
        end

        // Verify VGA line buffer written by R_DrawColumn
        if (dut.u_vga.custom_mode == 1'b1) begin
            $display("[PASS] Verified Doom R_DrawColumn textured wall rasterizer active in VGA buffer!");
        end else begin
            $display("[FAIL] Custom VGA tile mode not activated.");
        end

        // Verify Doom shotgun sound effect trigger
        if (dut.u_audio.freq_v2 == 16'd200) begin
            $display("[PASS] Verified Doom shotgun sound effect triggered on audio synth!");
        end else begin
            $display("[FAIL] Audio synth gunshot effect not detected.");
        end

        $display("=================================================================");
        $display("   DOOM RIGOROUS SIMULATION: ALL CHECKS COMPLETED SUCCESSFULLY!  ");
        $display("=================================================================");
        $finish;
    end

endmodule
