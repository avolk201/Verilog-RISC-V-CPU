//-----------------------------------------------------------------------------
// uart.v - Minimal 16550-compatible UART (8N1) with baud generator and FIFOs
//
// Register map (offset within the UART region):
//   DLAB=0:  0x00 RBR(r)/THR(w)   0x04 IER   0x08 IIR(r)/FCR(w)
//            0x0C LCR             0x14 LSR
//   DLAB=1:  0x00 DLL             0x04 DLM
// LCR bit7 = DLAB. `divisor` sets the bit period in clock cycles.
// TX/RX are real serial lines; the testbench loops tx->rx for a full round-trip.
// irq asserts per IER on RX-data-ready or TX-empty.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module uart #(
    parameter FIFO_DEPTH  = 16,
    parameter DEFAULT_DIV = 16'd8
) (
    input              clk,
    input              rst,

    input              s_cyc,
    input              s_we,
    input      [31:0]  s_addr,
    input      [31:0]  s_wdata,
    input      [3:0]   s_be,
    output             s_ack,
    output reg [31:0]  s_rdata,

    input              rx,
    output             tx,
    output             irq
);
    localparam FPTRW = (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH) : 1;

    reg [15:0] divisor;
    reg [7:0]  ier, lcr;
    wire dlab = lcr[7];
    wire [7:0] off = s_addr[7:0];

    // ---------------- FIFOs ----------------
    reg [7:0]     txf [0:FIFO_DEPTH-1];
    reg [FPTRW:0] tx_count; reg [FPTRW-1:0] tx_rp, tx_wp;
    reg [7:0]     rxf [0:FIFO_DEPTH-1];
    reg [FPTRW:0] rx_count; reg [FPTRW-1:0] rx_rp, rx_wp;

    wire tx_full  = (tx_count == FIFO_DEPTH);
    wire tx_empty = (tx_count == 0);
    wire rx_empty = (rx_count == 0);
    wire rx_full  = (rx_count == FIFO_DEPTH);

    // ---------------- TX serializer ----------------
    reg        tx_busy;
    reg [9:0]  tx_shift;
    reg [3:0]  tx_bits;
    reg [15:0] tx_baud;
    assign tx = tx_busy ? tx_shift[0] : 1'b1;

    // ---------------- RX deserializer ----------------
    localparam RX_IDLE=2'd0, RX_START=2'd1, RX_DATA=2'd2, RX_STOP=2'd3;
    reg [1:0]  rx_state;
    reg [15:0] rx_baud;
    reg [3:0]  rx_bit;
    reg [7:0]  rx_shift;
    reg        rx_pin;

    // ---------------- FIFO push/pop conditions ----------------
    wire tx_push = s_cyc &  s_we & (off==8'h00) & ~dlab & ~tx_full;
    wire tx_pop  = ~tx_busy & ~tx_empty;                    // serializer loads a byte
    wire rx_pop  = s_cyc & ~s_we & (off==8'h00) & ~dlab & ~rx_empty;
    wire rx_stop_done = (rx_state==RX_STOP) & (rx_baud==divisor-1);
    wire rx_push = rx_stop_done & rx_pin & ~rx_full;
    wire fcr_clr_tx = s_cyc & s_we & (off==8'h08) & s_wdata[2];
    wire fcr_clr_rx = s_cyc & s_we & (off==8'h08) & s_wdata[1];

    // ---------------- line status ----------------
    wire [7:0] lsr = {1'b0, (tx_empty & ~tx_busy), tx_empty, 4'b0, ~rx_empty};

    // ---------------- bus read mux ----------------
    assign s_ack = s_cyc;
    always @(*) begin
        s_rdata = 32'b0;
        if (s_cyc && !s_we) begin
            case (off)
                8'h00: s_rdata = dlab ? {16'b0, divisor[7:0]}  : {24'b0, rxf[rx_rp]};
                8'h04: s_rdata = dlab ? {16'b0, divisor[15:8]} : {24'b0, ier};
                8'h08: s_rdata = 32'b1;                       // IIR (simplified)
                8'h0C: s_rdata = {24'b0, lcr};
                8'h14: s_rdata = {24'b0, lsr};
                default: s_rdata = 32'b0;
            endcase
        end
    end

    integer i;
    initial begin
        divisor = DEFAULT_DIV; ier = 0; lcr = 0;
        tx_count = 0; tx_rp = 0; tx_wp = 0;
        rx_count = 0; rx_rp = 0; rx_wp = 0;
        tx_busy = 0; rx_state = RX_IDLE;
    end

    // ---------------- sequential ----------------
    always @(posedge clk) begin
        if (rst) begin
            tx_busy <= 0; tx_bits <= 0; tx_baud <= 0;
            rx_state <= RX_IDLE; rx_baud <= 0; rx_bit <= 0; rx_pin <= 1;
            tx_count <= 0; tx_rp <= 0; tx_wp <= 0;
            rx_count <= 0; rx_rp <= 0; rx_wp <= 0;
            ier <= 0; lcr <= 0; divisor <= DEFAULT_DIV;
        end else begin
            rx_pin <= rx;

            // ---- register writes ----
            if (s_cyc && s_we) begin
                case (off)
                    8'h00: if (dlab) divisor[7:0]  <= s_wdata[7:0];
                    8'h04: if (dlab) divisor[15:8] <= s_wdata[7:0];
                           else      ier           <= s_wdata[7:0];
                    8'h08: begin // FCR
                        if (s_wdata[1]) begin rx_count<=0; rx_rp<=0; rx_wp<=0; end
                        if (s_wdata[2]) begin tx_count<=0; tx_rp<=0; tx_wp<=0; tx_busy<=0; end
                    end
                    8'h0C: lcr <= s_wdata[7:0];
                    default: ;
                endcase
            end

            // ---- TX FIFO ----
            if (tx_push) begin
                txf[tx_wp] <= s_wdata[7:0];
                tx_wp <= (tx_wp==FIFO_DEPTH-1) ? {FPTRW{1'b0}} : tx_wp + 1;
            end
            if (rx_push) begin
                rxf[rx_wp] <= rx_shift;
                rx_wp <= (rx_wp==FIFO_DEPTH-1) ? {FPTRW{1'b0}} : rx_wp + 1;
            end
            if (tx_pop) tx_rp <= (tx_rp==FIFO_DEPTH-1) ? {FPTRW{1'b0}} : tx_rp + 1;
            if (rx_pop) rx_rp <= (rx_rp==FIFO_DEPTH-1) ? {FPTRW{1'b0}} : rx_rp + 1;

            // counts (combine simultaneous push/pop; FCR clear takes precedence)
            if (fcr_clr_tx) tx_count <= tx_push ? {{FPTRW{1'b0}},1'b1} : {(FPTRW+1){1'b0}};
            else            tx_count <= tx_count + (tx_push?1:0) - (tx_pop?1:0);
            if (fcr_clr_rx) rx_count <= rx_push ? {{FPTRW{1'b0}},1'b1} : {(FPTRW+1){1'b0}};
            else            rx_count <= rx_count + (rx_push?1:0) - (rx_pop?1:0);

            // ---- TX serializer ----
            if (!tx_busy) begin
                if (!tx_empty) begin
                    tx_shift <= {1'b1, txf[tx_rp], 1'b0};  // stop, data[7:0], start
                    tx_bits  <= 4'd10;
                    tx_baud  <= 0;
                    tx_busy  <= 1'b1;
                end
            end else begin
                if (tx_baud == divisor-1) begin
                    tx_baud  <= 0;
                    tx_shift <= {1'b1, tx_shift[9:1]};
                    tx_bits  <= tx_bits - 1;
                    if (tx_bits == 1) tx_busy <= 1'b0;
                end else tx_baud <= tx_baud + 1;
            end

            // ---- RX deserializer ----
            case (rx_state)
                RX_IDLE:  if (rx_pin==1'b0) begin rx_state<=RX_START; rx_baud<=0; end
                RX_START: begin
                    if (rx_baud == (divisor>>1)) begin
                        if (rx_pin==1'b0) begin rx_state<=RX_DATA; rx_bit<=0; rx_baud<=0; end
                        else               rx_state<=RX_IDLE;
                    end else rx_baud <= rx_baud + 1;
                end
                RX_DATA: begin
                    if (rx_baud == divisor-1) begin
                        rx_baud <= 0;
                        rx_shift[rx_bit[2:0]] <= rx_pin;
                        if (rx_bit==7) begin rx_state<=RX_STOP; rx_baud<=0; end
                        else            rx_bit <= rx_bit + 1;
                    end else rx_baud <= rx_baud + 1;
                end
                RX_STOP: begin
                    if (rx_baud == divisor-1) begin rx_state<=RX_IDLE; rx_baud<=0; end
                    else rx_baud <= rx_baud + 1;
                end
            endcase
        end
    end

    // ---------------- interrupt ----------------
    assign irq = (ier[0] & ~rx_empty) | (ier[1] & tx_empty);
endmodule
