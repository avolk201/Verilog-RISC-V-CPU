module ex_mem #(
    parameter PC_WIDTH      = 16,
    parameter DATA_WIDTH    = 16,
    parameter REGADDR_WIDTH = 4
) (
    input                        clk,
    input                        reset,
    // control
    input                        ex_reg_write,
    input                        ex_mem_read,
    input                        ex_mem_write,
    input                        ex_branch,
    input                        ex_is_jal,
    // data inputs
    input   [PC_WIDTH-1:0]       ex_pc,
    input   [DATA_WIDTH-1:0]     ex_alu_result,
    input   [DATA_WIDTH-1:0]     ex_reg_data2,
    input   [REGADDR_WIDTH-1:0]  ex_rd,
    input   [DATA_WIDTH-1:0]     ex_jal_link_value,
    // outputs to MEM
    output reg                   mem_reg_write,
    output reg                   mem_mem_read,
    output reg                   mem_mem_write,
    output reg                   mem_branch,
    output reg [PC_WIDTH-1:0]    mem_pc,
    output reg [DATA_WIDTH-1:0]  mem_alu_result,   // ← new
    output reg [DATA_WIDTH-1:0]  mem_write_data,    // ← new
    output reg [REGADDR_WIDTH-1:0] mem_rd,
    output reg                   mem_is_jal,
    output reg [DATA_WIDTH-1:0]  mem_jal_link_value
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_reg_write   <= 0;
            mem_mem_read    <= 0;
            mem_mem_write   <= 0;
            mem_branch      <= 0;
            mem_pc          <= {PC_WIDTH{1'b0}};
            mem_alu_result  <= {DATA_WIDTH{1'b0}};
            mem_write_data  <= {DATA_WIDTH{1'b0}};
            mem_rd          <= {REGADDR_WIDTH{1'b0}};
            mem_is_jal      <= 0;
            mem_jal_link_value <= 0;
        end else begin
            mem_reg_write   <= ex_reg_write;
            mem_mem_read    <= ex_mem_read;
            mem_mem_write   <= ex_mem_write;    // <-- add
            mem_branch      <= ex_branch;       // <-- add
            mem_pc          <= ex_pc;           // <-- add
            mem_alu_result  <= ex_alu_result;   // <-- add
            mem_write_data  <= ex_reg_data2;    // <-- add
            mem_rd          <= ex_rd;
            mem_is_jal      <= ex_is_jal;
            mem_jal_link_value <= ex_jal_link_value;
        end
    end

endmodule