//-----------------------------------------------------------------------------
// sram.v - Shared data memory with RV32A atomics support
//
// Single arbitrated port. Because the interconnect grants exactly one master at
// a time and a transaction completes in a single cycle, the read-modify-write
// performed for AMOs is inherently atomic with respect to the other cores.
//
// Load-Reserved / Store-Conditional use a single global reservation register
// (valid / master-id / word-address). Any write to the reserved word by anyone
// clears the reservation, so SC correctly fails if the line was touched.
//
// Byte lanes are honoured for sub-word stores via s_be.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module sram #(
    parameter DEPTH   = 16384,           // words
    parameter MEMFILE = ""
) (
    input              clk,
    input              s_cyc,
    input              s_we,
    input      [31:0]  s_addr,
    input      [31:0]  s_wdata,
    input      [3:0]   s_be,
    input      [3:0]   s_amo,            // AMO_* encoding
    input      [7:0]   s_master,         // requesting core id (for reservation)
    output             s_ack,
    output reg [31:0]  s_rdata
);
    localparam AW = $clog2(DEPTH);
    // AMO opcodes (match rv32_decoder)
    localparam AMO_NONE=4'd0, AMO_LR=4'd1, AMO_SC=4'd2, AMO_SWAP=4'd3,
               AMO_ADD=4'd4, AMO_AND=4'd5, AMO_OR=4'd6, AMO_XOR=4'd7,
               AMO_MIN=4'd8, AMO_MAX=4'd9, AMO_MINU=4'd10, AMO_MAXU=4'd11;

    reg [31:0] mem [0:DEPTH-1];
    reg [1023:0] fname;
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'b0;
        // +RAM=<file> at runtime overrides the MEMFILE parameter.
        if ($value$plusargs("RAM=%s", fname))
            $readmemh(fname, mem);
        else if (MEMFILE != "")
            $readmemh(MEMFILE, mem);
    end

    wire [AW-1:0] waddr = s_addr[AW+1:2];

    reg [31:0] dout;
    always @(posedge clk) begin
        dout <= mem[waddr];
    end
    wire [31:0] cur = dout; // available 1 cycle after address is presented

    // ---- reservation register ----
    reg          res_valid;
    reg  [7:0]   res_master;
    reg  [AW-1:0] res_addr;

    wire sc_ok = res_valid & (res_master == s_master) & (res_addr == waddr);

    // ---- byte-lane merge for normal stores ----
    reg [31:0] merged;
    always @(*) begin
        merged = cur; // for partial writes, we need cur! Wait, this means partial writes take 2 cycles.
        if (s_be[0]) merged[7:0]   = s_wdata[7:0];
        if (s_be[1]) merged[15:8]  = s_wdata[15:8];
        if (s_be[2]) merged[23:16] = s_wdata[23:16];
        if (s_be[3]) merged[31:24] = s_wdata[31:24];
    end

    // ---- AMO result ----
    reg [31:0] amo_result;
    always @(*) begin
        case (s_amo)
            AMO_SWAP: amo_result = s_wdata;
            AMO_ADD:  amo_result = cur + s_wdata;
            AMO_AND:  amo_result = cur & s_wdata;
            AMO_OR:   amo_result = cur | s_wdata;
            AMO_XOR:  amo_result = cur ^ s_wdata;
            AMO_MIN:  amo_result = ($signed(cur) < $signed(s_wdata)) ? cur : s_wdata;
            AMO_MAX:  amo_result = ($signed(cur) > $signed(s_wdata)) ? cur : s_wdata;
            AMO_MINU: amo_result = (cur < s_wdata) ? cur : s_wdata;
            AMO_MAXU: amo_result = (cur > s_wdata) ? cur : s_wdata;
            default:  amo_result = cur;
        endcase
    end

    reg [1:0] state;
    reg ack_q;
    assign s_ack = ack_q;

    reg [31:0] s_rdata_reg;
    assign s_rdata = s_rdata_reg;

    always @(posedge clk) begin
        if (!s_cyc) begin
            state <= 0;
            ack_q <= 0;
        end else if (ack_q) begin
            // Transaction acknowledged. If s_cyc is still high, it's a new transaction!
            // But to process it, we go back to state 0.
            state <= 0;
            ack_q <= 0;
        end else begin
            if (state == 0) begin
                if (s_amo != AMO_NONE) begin
                    state <= 1;
                end else begin
                    if (s_we) begin
                        if (s_be[0]) mem[waddr][7:0]   <= s_wdata[7:0];
                        if (s_be[1]) mem[waddr][15:8]  <= s_wdata[15:8];
                        if (s_be[2]) mem[waddr][23:16] <= s_wdata[23:16];
                        if (s_be[3]) mem[waddr][31:24] <= s_wdata[31:24];
                        if (res_valid & (res_addr == waddr)) res_valid <= 1'b0;
                    end
                    state <= 1;
                end
            end else if (state == 1) begin
                if (s_amo != AMO_NONE) begin
                    if (s_amo == AMO_LR) begin
                        res_valid  <= 1'b1;
                        res_master <= s_master;
                        res_addr   <= waddr;
                    end else if (s_amo == AMO_SC) begin
                        if (sc_ok) mem[waddr] <= s_wdata;
                        res_valid  <= 1'b0;
                    end else begin
                        mem[waddr] <= amo_result;
                        if (res_valid & (res_addr == waddr)) res_valid <= 1'b0;
                    end
                    s_rdata_reg <= (s_amo == AMO_SC) ? (sc_ok ? 32'd0 : 32'd1) : cur;
                    ack_q <= 1'b1;
                end else begin
                    s_rdata_reg <= cur;
                    ack_q <= 1'b1;
                end
            end
        end
    end
    
    always @(posedge clk) begin
        if (s_cyc && ack_q) begin
            $display("SRAM: cyc=%d we=%d addr=%x wdata=%x be=%x rdata=%x", s_cyc, s_we, waddr, s_wdata, s_be, s_rdata);
        end
    end
endmodule
