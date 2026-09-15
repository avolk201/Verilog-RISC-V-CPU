//-----------------------------------------------------------------------------
// mini_uart.v - Lightweight UART Transceiver for Tiny Tapeout
//
// MMIO Mapping (0x1000_0000):
//   0x1000_0000: DATA (Write to TX, Read to RX)
//   0x1000_0004: STATUS (Bit 0: RX Data Ready, Bit 1: TX Buffer Empty)
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module mini_uart #(
    parameter CLK_FREQ  = 25_175_000,
    parameter BAUD_RATE = 115_200
) (
    input  wire        clk,
    input  wire        rst_n,

    // MMIO Bus
    input  wire [31:0] bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_req,
    output reg  [31:0] bus_rdata,
    output reg         bus_ack,

    // Serial lines
    input  wire        rx,
    output reg         tx
);

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
    wire is_uart_mmio = (bus_addr[31:16] == 16'h1000);

    // ---------------- Transmitter ----------------
    reg [11:0] tx_baud_cnt;
    reg [3:0]  tx_bit_cnt;
    reg [8:0]  tx_shift;
    reg        tx_busy;

    // ---------------- Receiver ----------------
    reg [11:0] rx_baud_cnt;
    reg [3:0]  rx_bit_cnt;
    reg [7:0]  rx_shift;
    reg        rx_busy;
    reg [7:0]  rx_fifo;
    reg        rx_ready;
    reg [1:0]  rx_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_ack     <= 1'b0;
            bus_rdata   <= 32'b0;
            tx          <= 1'b1;
            tx_busy     <= 1'b0;
            tx_baud_cnt <= 12'd0;
            tx_bit_cnt  <= 4'd0;
            rx_sync     <= 2'b11;
            rx_busy     <= 1'b0;
            rx_ready    <= 1'b0;
            rx_fifo     <= 8'd0;
        end else begin
            bus_ack <= 1'b0;
            rx_sync <= {rx_sync[0], rx};

            // MMIO reads & writes
            if (bus_req && is_uart_mmio) begin
                if (bus_addr[2] == 1'b0) begin
                    // Data register (0x1000_0000)
                    if (bus_we && !tx_busy) begin
                        tx_shift    <= {bus_wdata[7:0], 1'b0}; // Start bit + data
                        tx_busy     <= 1'b1;
                        tx_baud_cnt <= BAUD_DIV - 1;
                        tx_bit_cnt  <= 4'd10;                  // 1 start, 8 data, 1 stop
                    end
                    bus_rdata <= {24'b0, rx_fifo};
                    rx_ready  <= 1'b0; // Read clears ready flag
                end else begin
                    // Status register (0x1000_0004)
                    bus_rdata <= {30'b0, !tx_busy, rx_ready};
                end
                bus_ack <= 1'b1;
            end

            // TX engine
            if (tx_busy) begin
                if (tx_baud_cnt == 12'd0) begin
                    tx_baud_cnt <= BAUD_DIV - 1;
                    tx          <= tx_shift[0];
                    tx_shift    <= {1'b1, tx_shift[8:1]};
                    tx_bit_cnt  <= tx_bit_cnt - 4'd1;
                    if (tx_bit_cnt == 4'd1) begin
                        tx_busy <= 1'b0;
                        tx      <= 1'b1;
                    end
                end else begin
                    tx_baud_cnt <= tx_baud_cnt - 12'd1;
                end
            end

            // RX engine
            if (!rx_busy) begin
                if (rx_sync == 2'b10) begin // Start bit
                    rx_busy     <= 1'b1;
                    rx_baud_cnt <= BAUD_DIV + (BAUD_DIV / 2);
                    rx_bit_cnt  <= 4'd0;
                end
            end else begin
                if (rx_baud_cnt == 12'd0) begin
                    rx_baud_cnt <= BAUD_DIV - 1;
                    rx_shift    <= {rx_sync[1], rx_shift[7:1]};
                    if (rx_bit_cnt < 4'd7) begin
                        rx_bit_cnt <= rx_bit_cnt + 4'd1;
                    end else begin
                        rx_busy  <= 1'b0;
                        rx_fifo  <= {rx_sync[1], rx_shift[7:1]};
                        rx_ready <= 1'b1;
                    end
                end else begin
                    rx_baud_cnt <= rx_baud_cnt - 12'd1;
                end
            end
        end
    end

endmodule
