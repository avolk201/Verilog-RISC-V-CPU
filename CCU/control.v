module control (
  input  [3:0] opcode,
  input        zero,        
  output reg       reg_write,
  output reg       mem_read,
  output reg       mem_write,
  output reg [2:0] alu_op,
  output reg       alu_src,
  output reg       branch,   
  output reg       ldpc,
  output reg       halt        // new
);

  always @(*) begin
    // defaults
    reg_write = 0;  mem_read = 0;  mem_write = 0;
    alu_src   = 0;  branch   = 0;  ldpc      = 0;
    alu_op    = 3'b000;  // ADD
    halt      = 0;    // default: not halted

    case(opcode)
      4'b0000: begin // ADD
        reg_write = 1;
        alu_src   = 0;
        alu_op    = 3'b000;
      end

      4'b0001: begin // SUB
        reg_write = 1;
        alu_src   = 0;
        alu_op    = 3'b011;
      end

      4'b0010: begin // LDI
        reg_write = 1;
        alu_src   = 1;
        alu_op    = 3'b010;
      end

      4'b0011: begin // XOR
        reg_write = 1;
        alu_src   = 0;
        alu_op    = 3'b001;
      end

      4'b0100: begin // AND
        reg_write = 1;
        alu_src   = 0;
        alu_op    = 3'b100;
      end

      4'b0110: begin // JMP
        reg_write = 0;
        alu_src   = 1;
        alu_op    = 3'b010;
        ldpc      = 1;
      end

      4'b0111: begin // HALT
        halt = 1;
      end

      4'b1000: begin // BEQZ
        alu_src   = 0;
        alu_op    = 3'b011;
        branch    = zero;
        ldpc      = zero;
      end

      4'b1110: begin // BNE
        alu_src   = 0;
        alu_op    = 3'b011;   // subtract
        branch    = ~zero;
        ldpc      = ~zero;
      end

      4'b1001: begin // STR
        mem_write = 1;
        reg_write = 0;
        alu_src   = 1; // Use immediate or register as address
        alu_op    = 3'b010; // pass-through (address)
      end

      4'b1010: begin // READ
        reg_write = 1;  // Write to register
        mem_read  = 1;  // Enable memory read
        alu_src   = 1;  // Use immediate as address
        alu_op    = 3'b010; // Pass-through
      end

      4'b1011: begin // MOV
        reg_write = 1;  // Enable register write
        alu_src   = 0;  // Use register as source
        alu_op    = 3'b010; // Pass-through (B)
      end

      4'b1100: begin // JAL
        reg_write = 1; // write link register
        alu_src   = 1;
        alu_op    = 3'b010;
        ldpc      = 1;
      end

      4'b1101: begin // JR
        reg_write = 0;
        alu_src   = 0;
        alu_op    = 3'b010;
        ldpc      = 1;
      end

      4'b1111: begin // MUL
        reg_write = 1;
        alu_src   = 0;      // two-register multiply
        alu_op    = 3'b101; // new ALU code
      end

      4'b0101: begin // DIV
        reg_write = 1;
        alu_src   = 0;       // two-register divide
        alu_op    = 3'b110;  // new DIV code
      end

      default: begin
        reg_write = 0;
      end
    endcase
  end

endmodule
