module fsm (
    input         clk,
    input         reset,
    input  [3:0]  opcode,
    input         zero,
    output reg    reg_write,
    output reg    mem_read,
    output reg    mem_write,
    output reg [2:0] alu_op,
    output reg    alu_src,
    output reg    branch,
    output reg    ldpc,
    output reg    halt
);

    // FSM states
	localparam FETCH   = 3'b000,
				  DECODE  = 3'b001,
              EXECUTE = 3'b010,
              MEM     = 3'b011,
              WB      = 3'b100;

	reg [2:0] state, next_state;

    // State transition logic
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= FETCH;
        else
            state <= next_state;
    end

    // Next state logic
    always @(*) begin
        case (state)
            FETCH:   next_state = DECODE;
            DECODE:  next_state = EXECUTE;
            EXECUTE: next_state = MEM;
            MEM:     next_state = WB;
            WB:      next_state = FETCH;
            default: next_state = FETCH;
        endcase
    end

    // Output logic (control signals)
    always @(*) begin
        // Default all outputs
        reg_write = 0; mem_read = 0; mem_write = 0;
        alu_src = 0; branch = 0; ldpc = 0; halt = 0;
        alu_op = 3'b000;

        // --- Always decode control signals from opcode ---
        case (opcode)
            4'b0000: begin // ADD
                reg_write = 1; alu_op = 3'b000;
            end
            4'b0001: begin // SUB
                reg_write = 1; alu_op = 3'b011;
            end
            4'b0010: begin // LDI
                reg_write = 1; alu_src = 1; alu_op = 3'b010;
            end
            4'b0011: begin // XOR
                reg_write = 1; alu_op = 3'b001;
            end
            4'b0100: begin // AND
                reg_write = 1; alu_op = 3'b100;
            end
            4'b0110: begin // JMP
                alu_src = 1; alu_op = 3'b010; ldpc = 1;
            end
            4'b0111: begin // HALT
                halt = 1;
            end
            4'b1000: begin // BEQZ
                alu_op = 3'b011; branch = zero; ldpc = zero;
            end
            4'b1110: begin // BNE
                alu_op = 3'b011; branch = ~zero; ldpc = ~zero;
            end
            4'b1001: begin // STR
                mem_write = 1; alu_src = 1; alu_op = 3'b010;
            end
            4'b1010: begin // LOAD
                reg_write = 1; mem_read = 1; alu_src = 1; alu_op = 3'b010;
            end
            4'b1011: begin // MOV
                reg_write = 1; alu_op = 3'b010;
            end
            4'b1100: begin // JAL
                reg_write = 1; alu_src = 1; alu_op = 3'b010; ldpc = 1;
            end
            4'b1101: begin // JR
                alu_op = 3'b010; ldpc = 1;
            end
            4'b1111: begin // MUL
                reg_write = 1; alu_op = 3'b101;
            end
            4'b0101: begin // DIV
                reg_write = 1; alu_op = 3'b110;
            end
            default: begin
                // NOP
            end
        endcase
    end

endmodule
