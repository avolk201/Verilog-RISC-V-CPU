//----------------------------------------------------------------------------
// Module: regfile.v
// Register file with two read ports and one write port
//----------------------------------------------------------------------------
module regfile #(
    parameter DATA_WIDTH      = 16,
    parameter REGADDR_WIDTH   = 3,
    parameter NUM_REGS        = (1<<REGADDR_WIDTH)
) (
    input                         clk,
    input                         reset,
    input                         reg_write,
    input  [REGADDR_WIDTH-1:0]   read_reg1,
    input  [REGADDR_WIDTH-1:0]   read_reg2,
    input  [REGADDR_WIDTH-1:0]   write_reg,
    input  [DATA_WIDTH-1:0]       write_data,
    output [DATA_WIDTH-1:0]       read_data1,
    output [DATA_WIDTH-1:0]       read_data2
);
    // register array
    reg [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];

    // read ports (combinational)
    assign read_data1 = regs[read_reg1];
    assign read_data2 = regs[read_reg2];

    // write port
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= {DATA_WIDTH{1'b0}};
        end else if (reg_write) begin
            regs[write_reg] <= write_data;
        end
    end
endmodule