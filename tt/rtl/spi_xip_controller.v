//-----------------------------------------------------------------------------
// spi_xip_controller.v - Dual SPI Flash XIP & PSRAM Controller with Cache
//
// Maps:
//   - 0x0000_0000 - 0x00FF_FFFF: External SPI Flash (16 MB) with 256B I-Cache
//   - 0x2000_0000 - 0x207F_FFFF: External QSPI PSRAM (8 MB read/write)
//   - 0x8000_0000 - 0x8000_01FF: Internal Zero-Wait Scratchpad (512 Bytes)
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module spi_xip_controller (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Bus Interface
    input  wire [31:0] bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire [3:0]  bus_be,
    input  wire        bus_we,
    input  wire        bus_req,
    input  wire        bus_is_instr,
    output reg  [31:0] bus_rdata,
    output reg         bus_ack,

    // External SPI Pins
    output reg         spi_sclk,
    output reg         spi_flash_cs_n,
    output reg         spi_psram_cs_n,
    output reg         spi_mosi,
    input  wire        spi_miso
);

    // ---------------- Internal Scratchpad (512 Bytes = 128 words) ----------------
    reg [31:0] scratchpad [0:127];
    wire is_scratch = (bus_addr[31:28] == 4'h8);
    wire [6:0] s_idx = bus_addr[8:2];

    // ---------------- Direct-Mapped I-Cache for Flash (64 words = 256 Bytes) ----------------
    reg [31:0] cache_data [0:63];
    reg [15:0] cache_tags [0:63];
    reg [63:0] cache_valid;

    wire is_flash = (bus_addr[31:24] == 8'h00);
    wire is_psram = (bus_addr[31:24] == 8'h20);

    wire [5:0]  cache_line = bus_addr[7:2];
    wire [15:0] cache_tag  = bus_addr[23:8];
    wire cache_hit = bus_is_instr && is_flash && !bus_we && cache_valid[cache_line] && (cache_tags[cache_line] == cache_tag);

    // ---------------- SPI Transfer State Machine ----------------
    localparam S_IDLE    = 3'd0;
    localparam S_CMD     = 3'd1;
    localparam S_ADDR    = 3'd2;
    localparam S_DATA_TX = 3'd3;
    localparam S_DATA_RX = 3'd4;
    localparam S_DONE    = 3'd5;
    reg [2:0] spi_state;

    reg [7:0]  cmd_shift;
    reg [23:0] addr_shift;
    reg [31:0] tx_shift;
    reg [31:0] rx_shift;
    reg [5:0]  bit_cnt;
    reg        sclk_phase;
    reg        target_is_psram;
    reg [31:0] req_addr;
    reg        req_we;
    reg        req_is_instr;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_ack         <= 1'b0;
            bus_rdata       <= 32'b0;
            spi_sclk        <= 1'b0;
            spi_flash_cs_n  <= 1'b1;
            spi_psram_cs_n  <= 1'b1;
            spi_mosi        <= 1'b0;
            spi_state       <= S_IDLE;
            cache_valid     <= 64'b0;
            sclk_phase      <= 1'b0;
            target_is_psram <= 1'b0;
            req_addr        <= 32'b0;
            req_we          <= 1'b0;
            req_is_instr    <= 1'b0;
            for (i = 0; i < 128; i = i + 1)
                scratchpad[i] <= 32'b0;
        end else begin
            bus_ack <= 1'b0;

            case (spi_state)
                S_IDLE: begin
                    spi_sclk       <= 1'b0;
                    spi_flash_cs_n <= 1'b1;
                    spi_psram_cs_n <= 1'b1;
                    sclk_phase     <= 1'b0;

                    if (bus_req && !bus_ack) begin
                        if (is_scratch) begin
                            // Fast zero-wait internal scratchpad
                            if (bus_we) begin
                                if (bus_be[0]) scratchpad[s_idx][7:0]   <= bus_wdata[7:0];
                                if (bus_be[1]) scratchpad[s_idx][15:8]  <= bus_wdata[15:8];
                                if (bus_be[2]) scratchpad[s_idx][23:16] <= bus_wdata[23:16];
                                if (bus_be[3]) scratchpad[s_idx][31:24] <= bus_wdata[31:24];
                            end
                            bus_rdata <= scratchpad[s_idx];
                            bus_ack   <= 1'b1;
                        end else if (cache_hit) begin
                            // Fast 1-cycle hit from Flash I-Cache
                            bus_rdata <= cache_data[cache_line];
                            bus_ack   <= 1'b1;
                        end else if (is_flash || is_psram) begin
                            // Begin external SPI transaction
                            target_is_psram <= is_psram;
                            if (is_psram)
                                spi_psram_cs_n <= 1'b0;
                            else
                                spi_flash_cs_n <= 1'b0;

                            // 0x03 for Read, 0x02 for Write
                            cmd_shift    <= bus_we ? 8'h02 : 8'h03;
                            addr_shift   <= {bus_addr[23:2], 2'b00};
                            req_addr     <= {bus_addr[31:2], 2'b00};
                            req_we       <= bus_we;
                            req_is_instr <= bus_is_instr;
                            tx_shift     <= bus_wdata;
                            rx_shift     <= 32'b0;
                            bit_cnt      <= 6'd8;
                            spi_state    <= S_CMD;
                        end
                    end
                end

                S_CMD: begin
                    // Shift out 8-bit command
                    sclk_phase <= ~sclk_phase;
                    if (!sclk_phase) begin
                        spi_mosi <= cmd_shift[7];
                        cmd_shift <= {cmd_shift[6:0], 1'b0};
                        spi_sclk <= 1'b0;
                    end else begin
                        spi_sclk <= 1'b1;
                        bit_cnt <= bit_cnt - 6'd1;
                        if (bit_cnt == 6'd1) begin
                            bit_cnt <= 6'd24;
                            spi_state <= S_ADDR;
                        end
                    end
                end

                S_ADDR: begin
                    // Shift out 24-bit address
                    sclk_phase <= ~sclk_phase;
                    if (!sclk_phase) begin
                        spi_mosi <= addr_shift[23];
                        addr_shift <= {addr_shift[22:0], 1'b0};
                        spi_sclk <= 1'b0;
                    end else begin
                        spi_sclk <= 1'b1;
                        bit_cnt <= bit_cnt - 6'd1;
                        if (bit_cnt == 6'd1) begin
                            bit_cnt <= 6'd32;
                            if (bus_we)
                                spi_state <= S_DATA_TX;
                            else
                                spi_state <= S_DATA_RX;
                        end
                    end
                end

                S_DATA_TX: begin
                    // Shift out 32-bit data (PSRAM write)
                    sclk_phase <= ~sclk_phase;
                    if (!sclk_phase) begin
                        spi_mosi <= tx_shift[31];
                        tx_shift <= {tx_shift[30:0], 1'b0};
                        spi_sclk <= 1'b0;
                    end else begin
                        spi_sclk <= 1'b1;
                        bit_cnt <= bit_cnt - 6'd1;
                        if (bit_cnt == 6'd1)
                            spi_state <= S_DONE;
                    end
                end

                S_DATA_RX: begin
                    // Shift in 32-bit data (Flash/PSRAM read)
                    sclk_phase <= ~sclk_phase;
                    if (!sclk_phase) begin
                        spi_sclk <= 1'b0;
                    end else begin
                        spi_sclk <= 1'b1;
                        rx_shift <= {rx_shift[30:0], spi_miso};
                        bit_cnt <= bit_cnt - 6'd1;
                        if (bit_cnt == 6'd1)
                            spi_state <= S_DONE;
                    end
                end

                S_DONE: begin
                    spi_sclk       <= 1'b0;
                    spi_flash_cs_n <= 1'b1;
                    spi_psram_cs_n <= 1'b1;

                    if (!req_we) begin
                        bus_rdata <= rx_shift;
                        // Fill Flash I-cache on instruction fetches from flash
                        if (req_addr[31:24] == 8'h00 && req_is_instr) begin
                            cache_data[req_addr[7:2]]  <= rx_shift;
                            cache_tags[req_addr[7:2]]  <= req_addr[23:8];
                            cache_valid[req_addr[7:2]] <= 1'b1;
                        end
                    end

                    bus_ack   <= 1'b1;
                    spi_state <= S_IDLE;
                end
                default: spi_state <= S_IDLE;
            endcase
        end
    end

endmodule
