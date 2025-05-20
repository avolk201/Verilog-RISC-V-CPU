//----------------------------------------------------------------------------
// Module: data_mem.v
// Description: Data Memory with synchronous write and asynchronous read
//              16 words deep by default (ADDR_WIDTH = 4)
//----------------------------------------------------------------------------
module data_mem #(
    parameter ADDR_WIDTH = 4,   // 4-bit address for 16 memory locations
    parameter DATA_WIDTH = 16   // data bus width
) (
    input                       clk,
    input                       mem_read,   // enable read
    input                       mem_write,  // enable write
    input   [ADDR_WIDTH-1:0]    addr,       // memory address
    input   [DATA_WIDTH-1:0]    write_data, // data to write
    output  [DATA_WIDTH-1:0]    read_data   // data read
);

    // Memory array
    reg [DATA_WIDTH-1:0] memory [0:(1<<ADDR_WIDTH)-1];

    // Synchronous write
    always @(posedge clk) begin
        if (mem_write) begin
            memory[addr] <= write_data;
        end
    end

    // Asynchronous read
    assign read_data = (mem_read) ? memory[addr] : {DATA_WIDTH{1'b0}};

endmodule