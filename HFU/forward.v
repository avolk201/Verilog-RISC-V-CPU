module forward #(
  parameter REGADDR_WIDTH = 4
) (
  input                   ex_mem_reg_write,
  input  [REGADDR_WIDTH-1:0] ex_mem_rd,
  input                   wb_reg_write,
  input  [REGADDR_WIDTH-1:0] wb_rd,
  input  [REGADDR_WIDTH-1:0] id_ex_rs,
  input  [REGADDR_WIDTH-1:0] id_ex_rt,
  output reg [1:0]        forwardA,
  output reg [1:0]        forwardB
);
  always @(*) begin
    // Default: no forwarding
    forwardA = 2'b00;
    forwardB = 2'b00;

    // EX hazard
    if (ex_mem_reg_write && ex_mem_rd != 0 && ex_mem_rd == id_ex_rs)
        forwardA = 2'b10;
    else if (wb_reg_write && wb_rd != 0 && wb_rd == id_ex_rs)
        forwardA = 2'b01;

    if (ex_mem_reg_write && ex_mem_rd != 0 && ex_mem_rd == id_ex_rt)
        forwardB = 2'b10;
    else if (wb_reg_write && wb_rd != 0 && wb_rd == id_ex_rt)
        forwardB = 2'b01;
  end
endmodule