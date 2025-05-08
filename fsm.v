module fsm (
    input wire clk,          // Clock signal
    input wire reset,        // Reset signal
    input wire [3:0] opcode, // Instruction opcode
    output reg [2:0] state,  // Current state
    output reg [7:0] control_signals // Control signals for datapath
);

    // State encoding
    localparam RESET     = 3'b000,
               FETCH     = 3'b001,
               DECODE    = 3'b010,
               EXECUTE   = 3'b011,
               WRITEBACK = 3'b100;

    // Control signal encoding (example)
    localparam CTRL_RESET     = 8'b00000001,
               CTRL_FETCH     = 8'b00000010,
               CTRL_DECODE    = 8'b00000100,
               CTRL_EXECUTE   = 8'b00001000,
               CTRL_WRITEBACK = 8'b00010000;

    // State transition logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= RESET; // Go to RESET state on reset
        end else begin
            case (state)
                RESET: begin
                    state <= FETCH; // Transition to FETCH after reset
                end
                FETCH: begin
                    state <= DECODE; // Transition to DECODE after fetching instruction
                end
                DECODE: begin
                    state <= EXECUTE; // Transition to EXECUTE based on opcode
                end
                EXECUTE: begin
                    state <= WRITEBACK; // Transition to WRITEBACK after execution
                end
                WRITEBACK: begin
                    state <= FETCH; // Transition back to FETCH for next instruction
                end
                default: begin
                    state <= RESET; // Default to RESET state
                end
            endcase
        end
    end

    // Control signal generation
    always @(*) begin
        case (state)
            RESET:     control_signals = CTRL_RESET;
            FETCH:     control_signals = CTRL_FETCH;
            DECODE:    control_signals = CTRL_DECODE;
            EXECUTE:   control_signals = CTRL_EXECUTE;
            WRITEBACK: control_signals = CTRL_WRITEBACK;
            default:   control_signals = 8'b00000000; // Default to no control signals
        endcase
    end

endmodule