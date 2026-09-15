//-----------------------------------------------------------------------------
// tt_um_tiny_rv32.v - Tiny Tapeout Top-Level Wrapper
//
// Project: Tiny Silicon Computer — RV32E with SPI XIP, PSRAM, VGA, Audio & USB
// Target:  Tiny Tapeout (SkyWater Sky130, 3x2 tile)
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module tt_um_tiny_rv32 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs (VGA Pmod)
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (1 = output, 0 = input)
    input  wire       ena,      // always 1 when powered
    input  wire       clk,      // 25.175 MHz pixel / system clock
    input  wire       rst_n     // active-low reset
);

    // ---------------- Heartbeat Counter ----------------
    reg [23:0] heartbeat_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) heartbeat_cnt <= 24'd0;
        else        heartbeat_cnt <= heartbeat_cnt + 24'd1;
    end
    wire heartbeat_led = heartbeat_cnt[23];

    // ---------------- Interconnect Wiring ----------------
    // Core instruction bus
    wire [31:0] core_i_addr;
    wire        core_i_req;
    wire [31:0] core_i_rdata;
    wire        core_i_ack;

    // Core data bus
    wire [31:0] core_d_addr;
    wire [31:0] core_d_wdata;
    wire [3:0]  core_d_be;
    wire        core_d_we;
    wire        core_d_req;
    reg  [31:0] core_d_rdata;
    reg         core_d_ack;

    // Peripheral buses
    wire [31:0] spi_rdata;
    wire        spi_ack;
    reg  [31:0] spi_addr;
    reg  [31:0] spi_wdata;
    reg  [3:0]  spi_be;
    reg         spi_we;
    reg         spi_req;

    wire [31:0] uart_rdata;
    wire        uart_ack;
    wire        uart_tx;

    wire [31:0] vga_rdata;
    wire        vga_ack;

    wire [31:0] ctrl_rdata;
    wire        ctrl_ack;

    wire [31:0] audio_rdata;
    wire        audio_ack;
    wire        audio_pwm;

    // ---------------- Subsystem Decode ----------------
    wire d_is_spi   = (core_d_addr[31:24] == 8'h00 || core_d_addr[31:24] == 8'h20 || core_d_addr[31:28] == 4'h8);
    wire d_is_uart  = (core_d_addr[31:16] == 16'h1000);
    wire d_is_vga   = (core_d_addr[31:16] == 16'h1001);
    wire d_is_ctrl  = (core_d_addr[31:16] == 16'h1002);
    wire d_is_audio = (core_d_addr[31:16] == 16'h1003);

    // ---------------- SPI Arbiter (Instruction Fetch vs Data Access) ----------------
    // Data accesses take priority; otherwise instruction fetches are routed to SPI
    wire data_spi_active = core_d_req && d_is_spi;

    always @(*) begin
        if (data_spi_active) begin
            spi_addr  = core_d_addr;
            spi_wdata = core_d_wdata;
            spi_be    = core_d_be;
            spi_we    = core_d_we;
            spi_req   = 1'b1;
        end else begin
            spi_addr  = core_i_addr;
            spi_wdata = 32'b0;
            spi_be    = 4'b1111;
            spi_we    = 1'b0;
            spi_req   = core_i_req;
        end
    end

    assign core_i_rdata = spi_rdata;
    assign core_i_ack   = core_i_req && !data_spi_active && spi_ack;

    // Data Read Mux
    always @(*) begin
        if (d_is_spi) begin
            core_d_rdata = spi_rdata;
            core_d_ack   = data_spi_active && spi_ack;
        end else if (d_is_uart) begin
            core_d_rdata = uart_rdata;
            core_d_ack   = uart_ack;
        end else if (d_is_vga) begin
            core_d_rdata = vga_rdata;
            core_d_ack   = vga_ack;
        end else if (d_is_ctrl) begin
            core_d_rdata = ctrl_rdata;
            core_d_ack   = ctrl_ack;
        end else if (d_is_audio) begin
            core_d_rdata = audio_rdata;
            core_d_ack   = audio_ack;
        end else begin
            core_d_rdata = 32'b0;
            core_d_ack   = core_d_req; // Immediate dummy ack for unmapped space
        end
    end

    // ---------------- Submodule Instantiations ----------------

    // 1. CPU Core (RV32E with DOOM fmul16 and TinyML dotp8)
    tiny_rv32_core #(
        .RESET_VEC(32'h0000_0000)
    ) u_core (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_addr  (core_i_addr),
        .i_req   (core_i_req),
        .i_rdata (core_i_rdata),
        .i_ack   (core_i_ack),
        .d_addr  (core_d_addr),
        .d_wdata (core_d_wdata),
        .d_be    (core_d_be),
        .d_we    (core_d_we),
        .d_req   (core_d_req),
        .d_rdata (core_d_rdata),
        .d_ack   (core_d_ack)
    );

    // 2. Dual SPI Flash & PSRAM Controller with 256B I-Cache
    wire spi_sclk_w, spi_flash_cs_n_w, spi_psram_cs_n_w, spi_mosi_w;
    wire bus_is_instr = !data_spi_active;
    spi_xip_controller u_spi (
        .clk            (clk),
        .rst_n          (rst_n),
        .bus_addr       (spi_addr),
        .bus_wdata      (spi_wdata),
        .bus_be         (spi_be),
        .bus_we         (spi_we),
        .bus_req        (spi_req),
        .bus_is_instr   (bus_is_instr),
        .bus_rdata      (spi_rdata),
        .bus_ack        (spi_ack),
        .spi_sclk       (spi_sclk_w),
        .spi_flash_cs_n (spi_flash_cs_n_w),
        .spi_psram_cs_n (spi_psram_cs_n_w),
        .spi_mosi       (spi_mosi_w),
        .spi_miso       (uio_in[3])
    );

    // 3. Hardware VGA 640x480 Controller (Direct Tiny Tapeout VGA Pmod)
    vga_tile_engine u_vga (
        .clk       (clk),
        .rst_n     (rst_n),
        .bus_addr  (core_d_addr),
        .bus_wdata (core_d_wdata),
        .bus_we    (core_d_we),
        .bus_req   (core_d_req && d_is_vga),
        .bus_rdata (vga_rdata),
        .bus_ack   (vga_ack),
        .vga_out   (uo_out)
    );

    // 4. Chiptune Synthesizer with Autonomous Silicon Boot Chime
    audio_synth u_audio (
        .clk       (clk),
        .rst_n     (rst_n),
        .bus_addr  (core_d_addr),
        .bus_wdata (core_d_wdata),
        .bus_we    (core_d_we),
        .bus_req   (core_d_req && d_is_audio),
        .bus_rdata (audio_rdata),
        .bus_ack   (audio_ack),
        .audio_pwm (audio_pwm)
    );

    // 5. USB Keyboard, Mouse & XInput Gamepad Controller
    usb_gamepad_ctrl u_gamepad (
        .clk       (clk),
        .rst_n     (rst_n),
        .bus_addr  (core_d_addr),
        .bus_wdata (core_d_wdata),
        .bus_we    (core_d_we),
        .bus_req   (core_d_req && d_is_ctrl),
        .bus_rdata (ctrl_rdata),
        .bus_ack   (ctrl_ack),
        .serial_rx (ui_in[0]),
        .usb_dp    (uio_in[5]),
        .usb_dm    (ui_in[1]),
        .gpio_btns (ui_in[6:2])
    );

    // 6. Mini UART
    mini_uart u_uart (
        .clk       (clk),
        .rst_n     (rst_n),
        .bus_addr  (core_d_addr),
        .bus_wdata (core_d_wdata),
        .bus_we    (core_d_we),
        .bus_req   (core_d_req && d_is_uart),
        .bus_rdata (uart_rdata),
        .bus_ack   (uart_ack),
        .rx        (ui_in[0]),
        .tx        (uart_tx)
    );

    // ---------------- Pinout Mapping ----------------
    // uio[0]: SCLK, uio[1]: Flash CS#, uio[2]: MOSI, uio[3]: MISO (input)
    // uio[4]: PSRAM CS#, uio[5]: USB D+ (input), uio[6]: Audio PWM, uio[7]: Status / UART TX
    assign uio_out = {
        uart_tx ^ heartbeat_led, // Blinking TX indicator / Heartbeat
        audio_pwm,
        1'b0,                    // uio[5] input (USB D+)
        spi_psram_cs_n_w,
        1'b0,                    // uio[3] input (MISO)
        spi_mosi_w,
        spi_flash_cs_n_w,
        spi_sclk_w
    };

    assign uio_oe = 8'b1101_0111; // Pin directions (1 = output, 0 = input)

endmodule
