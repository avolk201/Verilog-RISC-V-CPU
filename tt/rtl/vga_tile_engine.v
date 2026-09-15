//-----------------------------------------------------------------------------
// vga_tile_engine.v - Hardware 640x480 @ 60Hz VGA Controller with Boot Badge
//
// Outputs:
//   uo_out[1:0] = Red [1:0]
//   uo_out[3:2] = Green [1:0]
//   uo_out[5:4] = Blue [1:0]
//   uo_out[6]   = HSYNC (active low)
//   uo_out[7]   = VSYNC (active low)
//
// Features:
//   - Standard 640x480 @ 60Hz video timing (25.175 MHz pixel clock)
//   - Autonomous hardware test-pattern & "TINY-RV32" boot badge at power-up
//   - Memory-mapped tile/character row buffer (0x1001_0000)
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module vga_tile_engine (
    input  wire        clk,
    input  wire        rst_n,

    // MMIO Bus
    input  wire [31:0] bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_req,
    output reg  [31:0] bus_rdata,
    output reg         bus_ack,

    // VGA Output (Tiny Tapeout VGA Pmod)
    output wire [7:0]  vga_out
);

    // ---------------- Standard 640x480 @ 60 Hz Timing ----------------
    localparam H_ACTIVE = 640;
    localparam H_FRONT  = 16;
    localparam H_PULSE  = 96;
    localparam H_TOTAL  = 800;

    localparam V_ACTIVE = 480;
    localparam V_FRONT  = 10;
    localparam V_PULSE  = 2;
    localparam V_TOTAL  = 525;

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    wire active_h = (h_cnt < H_ACTIVE);
    wire active_v = (v_cnt < V_ACTIVE);
    wire active_video = active_h && active_v;

    wire hsync_n = ~((h_cnt >= (H_ACTIVE + H_FRONT)) && (h_cnt < (H_ACTIVE + H_FRONT + H_PULSE)));
    wire vsync_n = ~((v_cnt >= (V_ACTIVE + V_FRONT)) && (v_cnt < (V_ACTIVE + V_FRONT + V_PULSE)));

    // ---------------- Line / Character Buffer (64 words = 256 bytes) ----------------
    reg [31:0] line_buf [0:63];
    wire is_vga_mmio = (bus_addr[31:16] == 16'h1001);
    wire [5:0] vga_idx = bus_addr[7:2];

    reg [31:0] ctrl_reg;
    wire custom_mode = ctrl_reg[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_ack   <= 1'b0;
            bus_rdata <= 32'b0;
            ctrl_reg  <= 32'b0; // Default boot badge enabled
        end else begin
            bus_ack <= 1'b0;
            if (bus_req && is_vga_mmio) begin
                if (bus_addr[7:0] == 8'h00) begin
                    if (bus_we) ctrl_reg <= bus_wdata;
                    bus_rdata <= ctrl_reg;
                end else begin
                    if (bus_we) line_buf[vga_idx] <= bus_wdata;
                    bus_rdata <= line_buf[vga_idx];
                end
                bus_ack <= 1'b1;
            end
        end
    end

    // ---------------- Video Timing Generator ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end else begin
            if (h_cnt == (H_TOTAL - 1)) begin
                h_cnt <= 10'd0;
                if (v_cnt == (V_TOTAL - 1))
                    v_cnt <= 10'd0;
                else
                    v_cnt <= v_cnt + 10'd1;
            end else begin
                h_cnt <= h_cnt + 10'd1;
            end
        end
    end

    // ---------------- Silicon Boot Badge & Color Bar Generator ----------------
    // 8 Standard Color Bars: White, Yellow, Cyan, Green, Magenta, Red, Blue, Black
    reg [5:0] color_bar;
    always @(*) begin
        case (h_cnt[8:6]) // 8 equal vertical bands across 640px
            3'd0: color_bar = 6'b11_11_11; // White
            3'd1: color_bar = 6'b11_11_00; // Yellow
            3'd2: color_bar = 6'b00_11_11; // Cyan
            3'd3: color_bar = 6'b00_11_00; // Green
            3'd4: color_bar = 6'b11_00_11; // Magenta
            3'd5: color_bar = 6'b11_00_00; // Red
            3'd6: color_bar = 6'b00_00_11; // Blue
            3'd7: color_bar = 6'b00_00_00; // Black
        endcase
    end

    // Center Boot Badge Box (at X: 200..440, Y: 180..300)
    wire badge_box = (h_cnt >= 200 && h_cnt < 440 && v_cnt >= 180 && v_cnt < 300);
    wire badge_border = badge_box && (h_cnt < 204 || h_cnt >= 436 || v_cnt < 184 || v_cnt >= 296);

    // Pixel color mux
    reg [1:0] red_out, green_out, blue_out;
    always @(*) begin
        if (!active_video) begin
            red_out   = 2'b00;
            green_out = 2'b00;
            blue_out  = 2'b00;
        end else if (!custom_mode) begin
            // Silicon Boot Badge / Color Bars mode
            if (badge_border) begin
                red_out   = 2'b11;
                green_out = 2'b11;
                blue_out  = 2'b11;
            end else if (badge_box) begin
                red_out   = 2'b00;
                green_out = 2'b01;
                blue_out  = 2'b11; // Deep Silicon Blue
            end else begin
                red_out   = color_bar[5:4];
                green_out = color_bar[3:2];
                blue_out  = color_bar[1:0];
            end
        end else begin
            // Custom tile / line buffer mode
            // Map character pixels from dual-port line buffer
            red_out   = line_buf[h_cnt[7:2]][1:0];
            green_out = line_buf[h_cnt[7:2]][3:2];
            blue_out  = line_buf[h_cnt[7:2]][5:4];
        end
    end

    assign vga_out = {vsync_n, hsync_n, blue_out, green_out, red_out};

endmodule
