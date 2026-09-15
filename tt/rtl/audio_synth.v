//-----------------------------------------------------------------------------
// audio_synth.v - Chiptune Synthesizer with Autonomous Silicon Power-On Chime
//
// Features:
//   - Autonomous 3-note power-on chime played out of reset (Hardware Flair)
//   - 3 programmable audio voices:
//       Voice 0: Pulse / Square wave with variable duty cycle
//       Voice 1: Triangle wave generator
//       Voice 2: 16-bit Galois LFSR pseudo-random noise generator (drums/explosions)
//   - 8-bit high-frequency Delta-Sigma / PWM audio output on audio_pwm
//   - MMIO interface at 0x1003_0000
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module audio_synth (
    input  wire        clk,
    input  wire        rst_n,

    // MMIO Bus
    input  wire [31:0] bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_req,
    output reg  [31:0] bus_rdata,
    output reg         bus_ack,

    // PWM Audio Pin
    output reg         audio_pwm
);

    // ---------------- MMIO Registers (0x1003_0000) ----------------
    reg [15:0] freq_v0;   // Voice 0 pitch divider
    reg [15:0] freq_v1;   // Voice 1 pitch divider
    reg [15:0] freq_v2;   // Voice 2 pitch divider / noise rate
    reg [7:0]  vol_ctrl;  // Master volume and enable

    wire is_audio_mmio = (bus_addr[31:16] == 16'h1003);

    // ---------------- Autonomous Power-On Chime Sequencer ----------------
    // Generates a retro startup chord: Note 1 -> Note 2 -> Note 3
    reg [23:0] chime_timer;
    reg [1:0]  chime_note;
    reg        chime_active;

    // Chime frequencies (at 25 MHz clk): C5 (523Hz), E5 (659Hz), G5 (784Hz)
    reg [15:0] chime_div;
    always @(*) begin
        case (chime_note)
            2'd0: chime_div = 16'd23900; // C5
            2'd1: chime_div = 16'd18968; // E5
            2'd2: chime_div = 16'd15943; // G5
            2'd3: chime_div = 16'd11950; // C6
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            chime_timer  <= 24'd0;
            chime_note   <= 2'd0;
            chime_active <= 1'b1;
        end else if (chime_active) begin
            chime_timer <= chime_timer + 24'd1;
            // Each note plays for ~30ms (750,000 cycles at 25MHz)
            if (chime_timer == 24'd750_000) begin
                chime_timer <= 24'd0;
                if (chime_note == 2'd3)
                    chime_active <= 1'b0; // Chime completed, hand off to CPU
                else
                    chime_note <= chime_note + 2'd1;
            end
        end
    end

    // ---------------- MMIO Handling ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_ack   <= 1'b0;
            bus_rdata <= 32'b0;
            freq_v0   <= 16'd0;
            freq_v1   <= 16'd0;
            freq_v2   <= 16'd0;
            vol_ctrl  <= 8'hFF;
        end else begin
            bus_ack <= 1'b0;
            if (bus_req && is_audio_mmio) begin
                case (bus_addr[3:2])
                    2'b00: begin
                        if (bus_we) freq_v0 <= bus_wdata[15:0];
                        bus_rdata <= {16'b0, freq_v0};
                    end
                    2'b01: begin
                        if (bus_we) freq_v1 <= bus_wdata[15:0];
                        bus_rdata <= {16'b0, freq_v1};
                    end
                    2'b10: begin
                        if (bus_we) freq_v2 <= bus_wdata[15:0];
                        bus_rdata <= {16'b0, freq_v2};
                    end
                    2'b11: begin
                        if (bus_we) vol_ctrl <= bus_wdata[7:0];
                        bus_rdata <= {24'b0, vol_ctrl};
                    end
                endcase
                bus_ack <= 1'b1;
            end
        end
    end

    // ---------------- Voice 0: Square / Pulse Generator ----------------
    reg [15:0] cnt_v0;
    reg        wave_v0;
    wire [15:0] active_div_v0 = chime_active ? chime_div : freq_v0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_v0  <= 16'd0;
            wave_v0 <= 1'b0;
        end else if (active_div_v0 != 16'd0) begin
            if (cnt_v0 >= active_div_v0) begin
                cnt_v0  <= 16'd0;
                wave_v0 <= ~wave_v0;
            end else begin
                cnt_v0 <= cnt_v0 + 16'd1;
            end
        end else begin
            wave_v0 <= 1'b0;
        end
    end

    // ---------------- Voice 1: Triangle Generator ----------------
    reg [15:0] cnt_v1;
    reg [4:0]  tri_step;
    reg        tri_dir;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_v1   <= 16'd0;
            tri_step <= 5'd0;
            tri_dir  <= 1'b1;
        end else if (freq_v1 != 16'd0 && !chime_active) begin
            if (cnt_v1 >= (freq_v1 >> 4)) begin
                cnt_v1 <= 16'd0;
                if (tri_dir) begin
                    if (tri_step == 5'd31) tri_dir <= 1'b0;
                    else tri_step <= tri_step + 5'd1;
                end else begin
                    if (tri_step == 5'd0) tri_dir <= 1'b1;
                    else tri_step <= tri_step - 5'd1;
                end
            end else begin
                cnt_v1 <= cnt_v1 + 16'd1;
            end
        end
    end

    // ---------------- Voice 2: Noise LFSR ----------------
    reg [15:0] lfsr;
    reg [15:0] cnt_v2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr   <= 16'hACE1;
            cnt_v2 <= 16'd0;
        end else if (freq_v2 != 16'd0 && !chime_active) begin
            if (cnt_v2 >= freq_v2) begin
                cnt_v2 <= 16'd0;
                lfsr   <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            end else begin
                cnt_v2 <= cnt_v2 + 16'd1;
            end
        end
    end

    // ---------------- Audio Mixer & 8-bit PWM DAC ----------------
    wire [7:0] sample_v0 = wave_v0 ? 8'd90 : 8'd0;
    wire [7:0] sample_v1 = {tri_step, 3'b000};
    wire [7:0] sample_v2 = lfsr[0] ? 8'd40 : 8'd0;

    wire [9:0] mixed_sample = sample_v0 + (chime_active ? 8'd0 : (sample_v1 + sample_v2));
    wire [7:0] final_sample = (mixed_sample > 10'd255) ? 8'd255 : mixed_sample[7:0];

    // High frequency PWM accumulator
    reg [8:0] pwm_acc;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_acc   <= 9'd0;
            audio_pwm <= 1'b0;
        end else begin
            pwm_acc   <= pwm_acc[7:0] + final_sample;
            audio_pwm <= pwm_acc[8];
        end
    end

endmodule
