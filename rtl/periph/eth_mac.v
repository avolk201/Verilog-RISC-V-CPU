//-----------------------------------------------------------------------------
// eth_mac.v - Simplified Ethernet MAC (GMII-style, single clock domain)
//
// Provides a register/FIFO interface to the CPU and streams Ethernet frames on a
// GMII-like 8-bit-per-clock interface. The MAC builds a full frame on transmit
// (preamble + SFD + DA/SA/Type/Payload + CRC-32 FCS) and parses/validates an
// incoming frame on receive (SFD detect, CRC check, FCS strip).
//
// For simulation the testbench loops gmii_tx -> gmii_rx so a transmitted frame
// is received back, exercising the complete TX and RX datapaths including CRC.
//
// Register map (offset within the ETH region):
//   0x00 CTRL    : [0] enable  [1] start_tx (self-clearing)  [2] soft_reset
//   0x04 STATUS  : [0] tx_busy [1] rx_avail [2] tx_done [3] rx_ok [4] rx_err
//   0x08 TXLEN   : number of frame bytes staged in the TX buffer (RW)
//   0x0C RXLEN   : number of received frame bytes (RO, excludes FCS)
//   0x10 IRQSTAT : [0] tx_done [1] rx  (write-1-clear)
//   0x14 IRQMASK : [0] tx_done [1] rx
//   0x20 TXDATA  : write a byte (auto-increment) into the TX frame buffer
//   0x24 RXDATA  : read a byte (auto-increment) from the RX frame buffer
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "eth_crc32.vh"

module eth_mac #(
    parameter BUF_BYTES = 2048
) (
    input              clk,
    input              rst,

    // bus slave
    input              s_cyc,
    input              s_we,
    input      [31:0]  s_addr,
    input      [31:0]  s_wdata,
    input      [3:0]   s_be,
    output             s_ack,
    output reg [31:0]  s_rdata,

    // GMII-style media interface (single clock domain)
    output reg         gmii_tx_en,
    output reg [7:0]   gmii_tx_data,
    input              gmii_rx_dv,
    input      [7:0]   gmii_rx_data,

    output             irq
);
    localparam BPTR = $clog2(BUF_BYTES);
    wire [11:0] off = s_addr[11:0];

    // ---------------- registers ----------------
    reg        enable, tx_done, rx_avail, rx_ok, rx_err;
    reg [15:0] txlen, rxlen;
    reg [1:0]  irqstat, irqmask;

    // ---------------- frame buffers ----------------
    reg [7:0]  txbuf [0:BUF_BYTES-1];
    reg [7:0]  rxbuf [0:BUF_BYTES-1];
    reg [BPTR-1:0] tx_wp, tx_rp;
    reg [BPTR-1:0] rx_wp, rx_rp;

    // ---------------- control pulses from bus ----------------
    wire wr = s_cyc & s_we;
    wire start_tx_pulse = wr & (off==12'h00) & s_wdata[1];
    wire soft_reset     = wr & (off==12'h00) & s_wdata[2];
    wire txdata_wr      = wr & (off==12'h20);

    // ---------------- TX FSM ----------------
    localparam TX_IDLE=3'd0, TX_PRE=3'd1, TX_SFD=3'd2, TX_FRAME=3'd3,
               TX_FCS=3'd4, TX_DONE=3'd5;
    reg [2:0]  tx_state;
    reg [3:0]  pre_cnt;
    reg [BPTR-1:0] tx_cnt;
    reg [31:0] tx_crc;
    reg [31:0] fcs;
    reg [2:0]  fcs_cnt;
    reg        tx_busy;

    // ---------------- RX FSM ----------------
    localparam RX_IDLE=3'd0, RX_PRE=3'd1, RX_FRAME=3'd2, RX_VERIFY=3'd3,
               RX_DONE=3'd4;
    reg [2:0]  rx_state;
    reg [BPTR-1:0] rx_cnt;       // total captured (frame + FCS)
    reg [BPTR-1:0] v_ptr;        // verify pointer
    reg [BPTR-1:0] frame_len;    // captured minus 4
    reg [31:0] rx_crc;
    reg [7:0]  rxd_q;
    reg        dv_q;

    assign s_ack = s_cyc;

    // ---------------- bus read mux ----------------
    always @(*) begin
        s_rdata = 32'b0;
        if (s_cyc && !s_we) begin
            case (off)
                12'h00: s_rdata = {30'b0, 1'b0, enable};
                12'h04: s_rdata = {27'b0, rx_err, rx_ok, tx_done, rx_avail, tx_busy};
                12'h08: s_rdata = {16'b0, txlen};
                12'h0C: s_rdata = {16'b0, rxlen};
                12'h10: s_rdata = {30'b0, irqstat};
                12'h14: s_rdata = {30'b0, irqmask};
                12'h24: s_rdata = {24'b0, rxbuf[rx_rp]};
                default: s_rdata = 32'b0;
            endcase
        end
    end

    // RXDATA read auto-increments rx_rp
    wire rxdata_rd = s_cyc & ~s_we & (off==12'h24);

    integer k;
    initial begin
        enable=0; tx_done=0; rx_avail=0; rx_ok=0; rx_err=0;
        txlen=0; rxlen=0; irqstat=0; irqmask=0;
        tx_state=TX_IDLE; rx_state=RX_IDLE; tx_busy=0;
        tx_wp=0; tx_rp=0; rx_wp=0; rx_rp=0;
        gmii_tx_en=0; gmii_tx_data=0;
    end

    always @(posedge clk) begin
        if (rst || soft_reset) begin
            tx_state <= TX_IDLE; rx_state <= RX_IDLE;
            tx_busy <= 0; gmii_tx_en <= 0; gmii_tx_data <= 0;
            tx_done <= 0; rx_avail <= 0; rx_ok <= 0; rx_err <= 0;
            irqstat <= 0; tx_wp <= 0; tx_rp <= 0; rx_wp <= 0; rx_rp <= 0;
            txlen <= 0; rxlen <= 0;
        end else begin
            // ---------------- register writes ----------------
            if (wr) begin
                case (off)
                    12'h00: enable <= s_wdata[0];
                    12'h08: txlen  <= s_wdata[15:0];
                    12'h10: irqstat <= irqstat & ~s_wdata[1:0]; // W1C
                    12'h14: irqmask <= s_wdata[1:0];
                    default: ;
                endcase
            end
            // TX buffer byte write (auto-increment)
            if (txdata_wr) begin
                txbuf[tx_wp] <= s_wdata[7:0];
                tx_wp <= tx_wp + 1;
            end
            // RX buffer byte read (auto-increment)
            if (rxdata_rd) rx_rp <= rx_rp + 1;

            // ---------------- TX FSM ----------------
            case (tx_state)
                TX_IDLE: begin
                    gmii_tx_en <= 0;
                    if (start_tx_pulse && enable && (txlen != 0)) begin
                        tx_rp    <= 0;
                        tx_cnt   <= 0;
                        tx_crc   <= 32'hFFFFFFFF;
                        pre_cnt  <= 0;
                        tx_busy  <= 1;
                        tx_done  <= 0;
                        tx_state <= TX_PRE;
                    end
                end
                TX_PRE: begin
                    gmii_tx_en   <= 1;
                    gmii_tx_data <= 8'h55;
                    if (pre_cnt == 6) begin pre_cnt <= 0; tx_state <= TX_SFD; end
                    else              pre_cnt <= pre_cnt + 1;
                end
                TX_SFD: begin
                    gmii_tx_en   <= 1;
                    gmii_tx_data <= 8'hD5;
                    tx_state     <= TX_FRAME;
                end
                TX_FRAME: begin
                    gmii_tx_en   <= 1;
                    gmii_tx_data <= txbuf[tx_rp];
                    tx_crc       <= crc32_byte(tx_crc, txbuf[tx_rp]);
                    tx_rp        <= tx_rp + 1;
                    tx_cnt       <= tx_cnt + 1;
                    if (tx_cnt == txlen-1) begin
                        fcs      <= ~crc32_byte(tx_crc, txbuf[tx_rp]);
                        fcs_cnt  <= 0;
                        tx_state <= TX_FCS;
                    end
                end
                TX_FCS: begin
                    gmii_tx_en   <= 1;
                    gmii_tx_data <= fcs[fcs_cnt*8 +: 8];
                    fcs_cnt      <= fcs_cnt + 1;
                    if (fcs_cnt == 3) tx_state <= TX_DONE;
                end
                TX_DONE: begin
                    gmii_tx_en <= 0;
                    tx_busy    <= 0;
                    tx_done    <= 1;
                    irqstat[0] <= 1;
                    tx_wp      <= 0;   // ready for the next frame
                    tx_rp      <= 0;
                    tx_state   <= TX_IDLE;
                end
                default: tx_state <= TX_IDLE;
            endcase

            // ---------------- RX FSM ----------------
            dv_q <= gmii_rx_dv;
            case (rx_state)
                RX_IDLE: begin
                    if (gmii_rx_dv && (gmii_rx_data == 8'h55)) begin
                        rx_state <= RX_PRE;
                    end
                    rx_wp  <= 0;
                    rx_cnt <= 0;
                end
                RX_PRE: begin
                    if (!gmii_rx_dv)               rx_state <= RX_IDLE;
                    else if (gmii_rx_data==8'hD5) begin
                        rx_state <= RX_FRAME;
                        rx_wp    <= 0;
                        rx_cnt   <= 0;
                    end
                end
                RX_FRAME: begin
                    if (gmii_rx_dv) begin
                        rxbuf[rx_wp] <= gmii_rx_data;
                        rx_wp <= rx_wp + 1;
                        rx_cnt<= rx_cnt + 1;
                    end else begin
                        // end of frame: rx_cnt bytes captured (frame + FCS)
                        if (rx_cnt > 4) begin
                            frame_len <= rx_cnt - 4;
                            v_ptr     <= 0;
                            rx_crc    <= 32'hFFFFFFFF;
                            rx_state  <= RX_VERIFY;
                        end else rx_state <= RX_IDLE;   // runt
                    end
                end
                RX_VERIFY: begin
                    if (v_ptr == frame_len) begin
                        // compare computed FCS with the captured one (low byte first)
                        rx_ok    <= (~rx_crc[7:0]  == rxbuf[frame_len])   &&
                                    (~rx_crc[15:8] == rxbuf[frame_len+1]) &&
                                    (~rx_crc[23:16]== rxbuf[frame_len+2]) &&
                                    (~rx_crc[31:24]== rxbuf[frame_len+3]);
                        rx_err   <= ~((~rx_crc[7:0]  == rxbuf[frame_len])   &&
                                      (~rx_crc[15:8] == rxbuf[frame_len+1]) &&
                                      (~rx_crc[23:16]== rxbuf[frame_len+2]) &&
                                      (~rx_crc[31:24]== rxbuf[frame_len+3]));
                        rx_state <= RX_DONE;
                    end else begin
                        rx_crc <= crc32_byte(rx_crc, rxbuf[v_ptr]);
                        v_ptr  <= v_ptr + 1;
                    end
                end
                RX_DONE: begin
                    if (rx_ok) begin
                        rx_avail    <= 1;
                        rxlen       <= frame_len;
                        rx_rp       <= 0;
                        irqstat[1]  <= 1;
                    end
                    rx_state <= RX_IDLE;
                end
                default: rx_state <= RX_IDLE;
            endcase

            // rx_avail cleared by W1C of irqstat[1]
            if (wr && (off==12'h10) && s_wdata[1]) rx_avail <= 0;
        end
    end

    assign irq = |(irqstat & irqmask);
endmodule
