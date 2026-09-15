//-----------------------------------------------------------------------------
// usb_gamepad_ctrl.v - USB Keyboard, Mouse & XInput Gamepad Controller
//
// Interfaces:
//   - Serial XInput/HID packet parser from USB Host (ui_in[0])
//   - Direct USB Low-Speed HID receiver (D+ on uio_in[5], D- on ui_in[1])
//   - Direct GPIO Gamepad Buttons on ui_in[6:2] (Up, Down, Left, Right, Action)
//
// MMIO Mapping (0x1002_0000):
//   0x1002_0000: GAMEPAD_BTNS (A, B, X, Y, LB, RB, Start, Select, D-Pad)
//   0x1002_0004: GAMEPAD_ANALOG_L (Left Stick X [15:8], Left Stick Y [7:0])
//   0x1002_0008: GAMEPAD_ANALOG_R (Right Stick X [15:8], Right Stick Y [7:0], Triggers)
//   0x1002_000C: KBD_DATA (Scancode [7:0], Modifiers [15:8], Key Down [16])
//   0x1002_0010: MOUSE_DATA (Delta X [7:0], Delta Y [15:8], Buttons [18:16])
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module usb_gamepad_ctrl (
    input  wire        clk,
    input  wire        rst_n,

    // MMIO Bus
    input  wire [31:0] bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_req,
    output reg  [31:0] bus_rdata,
    output reg         bus_ack,

    // Physical Input Pins
    input  wire        serial_rx,     // ui_in[0] (Serial HID / XInput packet stream)
    input  wire        usb_dp,        // uio_in[5] (Direct USB D+)
    input  wire        usb_dm,        // ui_in[1] (Direct USB D-)
    input  wire [4:0]  gpio_btns      // ui_in[6:2] (Direct pushbuttons: [0]=Up, [1]=Down, [2]=Left, [3]=Right, [4]=Action)
);

    wire is_ctrl_mmio = (bus_addr[31:16] == 16'h1002);

    // ---------------- Input Registers ----------------
    reg [15:0] xinput_btns;
    reg [7:0]  stick_lx, stick_ly;
    reg [7:0]  stick_rx, stick_ry;
    reg [7:0]  trigger_l, trigger_r;
    reg [31:0] kbd_reg;
    reg [31:0] mouse_reg;

    // Active-low GPIO buttons combined with XInput digital buttons
    // Bit 0: Up, Bit 1: Down, Bit 2: Left, Bit 3: Right, Bit 4: A (Action)
    wire [15:0] combined_btns = {xinput_btns[15:5],
                                 xinput_btns[4] | ~gpio_btns[4],
                                 xinput_btns[3] | ~gpio_btns[3],
                                 xinput_btns[2] | ~gpio_btns[2],
                                 xinput_btns[1] | ~gpio_btns[1],
                                 xinput_btns[0] | ~gpio_btns[0]};

    // ---------------- MMIO Bus Read ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_ack   <= 1'b0;
            bus_rdata <= 32'b0;
        end else begin
            bus_ack <= 1'b0;
            if (bus_req && is_ctrl_mmio) begin
                case (bus_addr[4:2])
                    3'd0: bus_rdata <= {16'b0, combined_btns};
                    3'd1: bus_rdata <= {16'b0, stick_lx, stick_ly};
                    3'd2: bus_rdata <= {trigger_r, trigger_l, stick_rx, stick_ry};
                    3'd3: bus_rdata <= kbd_reg;
                    3'd4: bus_rdata <= mouse_reg;
                    default: bus_rdata <= 32'b0;
                endcase
                bus_ack <= 1'b1;
            end
        end
    end

    // ---------------- Serial XInput / HID Packet Receiver ----------------
    // Packet Protocol from USB Host companion:
    //   Header: 0xA5
    //   Type:   0x01 = Gamepad (Buttons[15:0], LX, LY, RX, RY, LT, RT)
    //           0x02 = Keyboard (Scancode, Modifiers)
    //           0x03 = Mouse (DeltaX, DeltaY, Buttons)
    localparam CLK_FREQ  = 25_175_000;
    localparam BAUD_RATE = 115_200;
    localparam BAUD_DIV  = CLK_FREQ / BAUD_RATE;

    reg [11:0] baud_cnt;
    reg [3:0]  rx_bit_cnt;
    reg [7:0]  rx_shift;
    reg        rx_busy;
    reg        rx_byte_valid;
    reg [7:0]  rx_byte;
    reg [1:0]  rx_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync       <= 2'b11;
            baud_cnt      <= 12'd0;
            rx_bit_cnt   <= 4'd0;
            rx_busy       <= 1'b0;
            rx_byte_valid <= 1'b0;
            rx_byte       <= 8'd0;
        end else begin
            rx_sync <= {rx_sync[0], serial_rx};
            rx_byte_valid <= 1'b0;

            if (!rx_busy) begin
                if (rx_sync == 2'b10) begin // Start bit detected
                    rx_busy    <= 1'b1;
                    baud_cnt   <= BAUD_DIV + (BAUD_DIV / 2);
                    rx_bit_cnt <= 4'd0;
                end
            end else begin
                if (baud_cnt == 12'd0) begin
                    baud_cnt <= BAUD_DIV - 1;
                    rx_shift <= {rx_sync[1], rx_shift[7:1]};
                    if (rx_bit_cnt < 4'd7) begin
                        rx_bit_cnt <= rx_bit_cnt + 4'd1;
                    end else begin
                        rx_busy       <= 1'b0;
                        rx_byte       <= {rx_sync[1], rx_shift[7:1]};
                        rx_byte_valid <= 1'b1;
                    end
                end else begin
                    baud_cnt <= baud_cnt - 12'd1;
                end
            end
        end
    end

    // Packet state machine
    localparam PKT_IDLE = 3'd0;
    localparam PKT_TYPE = 3'd1;
    localparam PKT_DATA = 3'd2;
    reg [2:0] pkt_state;
    reg [7:0] pkt_type;
    reg [3:0] pkt_idx;
    reg [7:0] pkt_buf [0:7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pkt_state   <= PKT_IDLE;
            pkt_type    <= 8'd0;
            pkt_idx     <= 4'd0;
            xinput_btns <= 16'd0;
            stick_lx    <= 8'h80; // Centered
            stick_ly    <= 8'h80;
            stick_rx    <= 8'h80;
            stick_ry    <= 8'h80;
            trigger_l   <= 8'd0;
            trigger_r   <= 8'd0;
            kbd_reg     <= 32'd0;
            mouse_reg   <= 32'd0;
        end else if (rx_byte_valid) begin
            case (pkt_state)
                PKT_IDLE: begin
                    if (rx_byte == 8'hA5) // Magic sync byte
                        pkt_state <= PKT_TYPE;
                end

                PKT_TYPE: begin
                    pkt_type  <= rx_byte;
                    pkt_idx   <= 4'd0;
                    pkt_state <= PKT_DATA;
                end

                PKT_DATA: begin
                    pkt_buf[pkt_idx] <= rx_byte;
                    pkt_idx <= pkt_idx + 4'd1;

                    if (pkt_type == 8'h01 && pkt_idx == 4'd7) begin // Gamepad complete
                        xinput_btns <= {pkt_buf[1], pkt_buf[0]};
                        stick_lx    <= pkt_buf[2];
                        stick_ly    <= pkt_buf[3];
                        stick_rx    <= pkt_buf[4];
                        stick_ry    <= pkt_buf[5];
                        trigger_l   <= pkt_buf[6];
                        trigger_r   <= rx_byte;
                        pkt_state   <= PKT_IDLE;
                    end else if (pkt_type == 8'h02 && pkt_idx == 4'd2) begin // Keyboard complete
                        kbd_reg   <= {15'b0, 1'b1, rx_byte, pkt_buf[0]};
                        pkt_state <= PKT_IDLE;
                    end else if (pkt_type == 8'h03 && pkt_idx == 4'd2) begin // Mouse complete
                        mouse_reg <= {13'b0, rx_byte[2:0], pkt_buf[1], pkt_buf[0]};
                        pkt_state <= PKT_IDLE;
                    end
                end
                default: pkt_state <= PKT_IDLE;
            endcase
        end
    end

endmodule
