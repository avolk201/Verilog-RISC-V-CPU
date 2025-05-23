module control (
  input  [2:0] opcode,
  input        zero,        
  output reg       reg_write,
  output reg       mem_read,
  output reg       mem_write,
  output reg [1:0] alu_op,
  output reg       alu_src,
  output reg       branch,   
  output reg       ldpc,
  output reg       halt        // new
);

  always @(*) begin
    // defaults
    reg_write = 0;  mem_read = 0;  mem_write = 0;
    alu_src   = 0;  branch   = 0;  ldpc      = 0;
    alu_op    = 2'b00;  // ADD
    halt      = 0;    // default: not halted

    case(opcode)
      3'b000: begin
        // ADD: Rd <- Rs + Rt
        reg_write = 1;
        alu_src   = 0;       // B = reg_data2
        alu_op    = 2'b00;   // ADD
      end

      3'b010: begin
        // LDI: Rd <- imm
        reg_write = 1;
        alu_src   = 1;       // B = imm
        alu_op    = 2'b10;   // PASS-B
      end

      3'b001: begin
        // SUB: Rd <- Rs - Rt
        reg_write = 1;
        alu_src   = 0;
        alu_op    = 2'b11;  // SUBTRACTION
      end

      3'b011: begin
        // XOR: Rd <- Rs ^ Rt
        reg_write = 1;
        alu_src   = 0;
        alu_op    = 2'b01;  // XOR
      end

      3'b100: begin          // STR  (store)
        // compute address = Rs + imm
        mem_write = 1;
        alu_src   = 1;       // B = imm
        alu_op    = 2'b00;   // add
        reg_write = 0;       // no register write
      end

      3'b101: begin        // JMP / goto
        // load PC from immediate
        reg_write = 0;
        alu_src   = 1;       // B = imm
        alu_op    = 2'b10;   // PASS-B
        ldpc      = 1;       // trigger PC ← imm
      end

      3'b110: begin  // HALT
        halt = 1;
      end

      3'b111: begin      // BEQZ imm
        // compare Rs == 0
        alu_src   = 0;        // B = reg_data2 (we’ll put R3, the zero register there in the assembler)
        alu_op    = 2'b11;    // SUB
        branch    = zero;     // now zero = (Rs - 0)==0
        ldpc      = zero;     // and on zero take the branch
      end

      default: begin
        // NOP
        reg_write = 0;
      end
    endcase
  end

endmodule