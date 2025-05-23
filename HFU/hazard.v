module hazard #(
  parameter REGADDR_WIDTH = 4
) (
  input                    id_ex_mem_read,
  input  [REGADDR_WIDTH-1:0] id_ex_rd,
  input  [REGADDR_WIDTH-1:0] if_id_rs,
  input  [REGADDR_WIDTH-1:0] if_id_rt,
  output reg               stall,
  output reg               pc_write,
  output reg               if_id_write
);
  always @(*) begin
    if (id_ex_mem_read && ((id_ex_rd==if_id_rs)||(id_ex_rd==if_id_rt))) begin
      stall        = 1;
      pc_write     = 0;
      if_id_write  = 0;
    end else begin
      stall        = 0;
      pc_write     = 1;
      if_id_write  = 1;
    end
  end
endmodule