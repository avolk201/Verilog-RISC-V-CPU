module control (
  input  [2:0] opcode,
  output reg       reg_write,
  output reg       mem_read,
  output reg       mem_write,
  output reg [1:0] alu_op,
  output reg       alu_src,
  output reg       branch,
  output reg       ldpc
);

  always @(*) begin
    // defaults
    reg_write = 0;  mem_read = 0;  mem_write = 0;
    alu_src   = 0;  branch   = 0;  ldpc      = 0;
    alu_op    = 2'b00;  // ADD

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



      default: begin
        // NOP
        reg_write = 0;
      end
    endcase
  end

endmodule