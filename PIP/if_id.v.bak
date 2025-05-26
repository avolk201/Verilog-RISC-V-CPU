//----------------------------------------------------------------------------
// Module: if_id.v
// Pipeline register between IF and ID stages
//----------------------------------------------------------------------------
module if_id #(
    parameter PC_WIDTH    = 12,
    parameter INSTR_WIDTH = 12
) (
    input                   clk,
    input                   reset,
    input                   stall,      // hold
    input                   flush,      // clear
    input  [PC_WIDTH-1:0]   if_pc,
    input  [INSTR_WIDTH-1:0] if_instr,
    output reg [PC_WIDTH-1:0]   id_pc,
    output reg [INSTR_WIDTH-1:0] id_instr
);
    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            id_pc    <= {PC_WIDTH{1'b0}};
            id_instr <= {INSTR_WIDTH{1'b0}};
        end else if (!stall) begin
            id_pc    <= if_pc;
            id_instr <= if_instr;
        end
        // else hold previous values
    end
endmodule