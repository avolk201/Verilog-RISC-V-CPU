//----------------------------------------------------------------------------
// Module: pc.v
// Program Counter register with stall and reset
//----------------------------------------------------------------------------

module pc #(
    parameter WIDTH = 12       // program counter width
) (
    input                   clk,
    input                   reset,
    input                   pc_write,   // enable update
    input  [WIDTH-1:0]      pc_in,
    output reg [WIDTH-1:0]  pc_out
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_out <= {WIDTH{1'b0}};
        else if (pc_write)
            pc_out <= pc_in;
    end
endmodule