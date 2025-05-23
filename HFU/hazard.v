module hazard(
  input            id_ex_mem_read,
  input      [3:0] id_ex_rd,
  input      [3:0] if_id_rs,
  input      [3:0] if_id_rt,
  input      [3:0] ex_rd,
  input            ex_is_jal,
  input            id_is_jr,
  output reg       stall,
  output reg       pc_write,
  output reg       if_id_write
);
  always @(*) begin
    // Existing load-use hazard
    if (id_ex_mem_read && ((id_ex_rd==if_id_rs)||(id_ex_rd==if_id_rt))) begin
      stall        = 1;
      pc_write     = 0;
      if_id_write  = 0;
    end
    // --- NEW: JAL→JR hazard ---
    else if (id_is_jr && ex_is_jal && (ex_rd == if_id_rs)) begin
      stall        = 1;
      pc_write     = 0;
      if_id_write  = 0;
    end
    else begin
      stall        = 0;
      pc_write     = 1;
      if_id_write  = 1;
    end
  end
endmodule