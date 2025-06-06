//----------------------------------------------------------------------------
// Module: regfile.v
// Register file with two read ports and one write port
//----------------------------------------------------------------------------
module regfile #(
  parameter DATA_WIDTH    = 16,
  parameter REGADDR_WIDTH = 4,
  parameter NUM_REGS      = (1<<REGADDR_WIDTH)
) (
  input                        clk,
  input                        reset,
  input      [REGADDR_WIDTH-1:0] read_reg1,
  input      [REGADDR_WIDTH-1:0] read_reg2,
  output     [DATA_WIDTH-1:0]    read_data1,
  output     [DATA_WIDTH-1:0]    read_data2,
  input      [REGADDR_WIDTH-1:0] write_reg,
  input      [DATA_WIDTH-1:0]    write_data,
  input                        reg_write
);

  reg [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];

  // write-first (forward write_data on a matched read_reg)
  assign read_data1 = (reg_write && (write_reg == read_reg1))
                      ? write_data
                      : regs[read_reg1];
  assign read_data2 = (reg_write && (write_reg == read_reg2))
                      ? write_data
                      : regs[read_reg2];

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      integer i;
      for (i=0; i<NUM_REGS; i=i+1)
        regs[i] <= 0;
    end else if (reg_write) begin
      regs[write_reg] <= write_data;
    end
  end

endmodule