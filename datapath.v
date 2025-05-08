module datapath (
    input wire clk,                // Clock signal
    input wire reset,              // Reset signal
    input wire [3:0] opcode,       // Instruction opcode
    input wire [2:0] src_reg,      // Source register address
    input wire [2:0] dest_reg,     // Destination register address
    input wire [15:0] immediate,   // Immediate value for load instruction
    output wire [15:0] result      // Result of the operation
);

    // Register file (8 registers, 16 bits each)
    reg [15:0] registers [7:0];

    // Internal signals
    reg [15:0] src_data;
    reg [15:0] dest_data;
    reg [15:0] alu_result;

    // Opcodes
    localparam LOAD = 4'b0001,
               MOV  = 4'b0010,
               ADD  = 4'b0011,
               XOR  = 4'b0100;

    // Read data from registers
    always @(*) begin
        src_data = registers[src_reg];
        dest_data = registers[dest_reg];
    end

    // ALU operation
    always @(*) begin
        case (opcode)
            LOAD: alu_result = immediate;          // Load immediate value
            MOV:  alu_result = src_data;           // Move source to destination
            ADD:  alu_result = src_data + dest_data; // Add source and destination
            XOR:  alu_result = src_data ^ dest_data; // XOR source and destination
            default: alu_result = 16'b0;           // Default to 0
        endcase
    end

    // Write data back to destination register
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all registers to 0
            registers[0] <= 16'b0;
            registers[1] <= 16'b0;
            registers[2] <= 16'b0;
            registers[3] <= 16'b0;
            registers[4] <= 16'b0;
            registers[5] <= 16'b0;
            registers[6] <= 16'b0;
            registers[7] <= 16'b0;
        end else begin
            case (opcode)
                LOAD, MOV, ADD, XOR: registers[dest_reg] <= alu_result;
                default: ; // No operation
            endcase
        end
    end

    // Output the result
    assign result = alu_result;

endmodule