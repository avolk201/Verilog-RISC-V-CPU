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
    wire [31:0]   cur   = mem[waddr];

    // ---- reservation register ----
    reg          res_valid;
    reg  [7:0]   res_master;
    reg  [AW-1:0] res_addr;

    wire sc_ok = res_valid & (res_master == s_master) & (res_addr == waddr);

    // ---- byte-lane merge for normal stores ----
    reg [31:0] merged;
    always @(*) begin
        merged = cur;
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

    // single-cycle acknowledge whenever selected
    assign s_ack = s_cyc;

    // ---- read data mux (combinational) ----
    always @(*) begin
        if (s_amo == AMO_SC) s_rdata = sc_ok ? 32'd0 : 32'd1;  // 0 = success
        else                 s_rdata = cur;                     // load / LR / AMO old
    end

    // ---- synchronous write / reservation update ----
    always @(posedge clk) begin
        if (s_cyc) begin
            if (s_amo == AMO_LR) begin
                res_valid  <= 1'b1;
                res_master <= s_master;
                res_addr   <= waddr;
            end else if (s_amo == AMO_SC) begin
                if (sc_ok) mem[waddr] <= s_wdata;
                res_valid  <= 1'b0;                 // SC clears reservation
            end else if (s_amo != AMO_NONE) begin   // arithmetic AMO
                mem[waddr] <= amo_result;
                if (res_valid & (res_addr == waddr)) res_valid <= 1'b0;
            end else if (s_we) begin                // normal store
                mem[waddr] <= merged;
                if (res_valid & (res_addr == waddr)) res_valid <= 1'b0;
            end
        end
    end
endmodule
