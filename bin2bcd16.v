module bin2bcd16(
    input  [15:0] binary,
    output reg [3:0] bcd4,  // 10⁴’s
    output reg [3:0] bcd3,  // 10³’s
    output reg [3:0] bcd2,  // 10²’s
    output reg [3:0] bcd1,  // 10¹’s
    output reg [3:0] bcd0   // 10⁰’s
);
    integer i;
    reg [19:0] shift;  // 5×4 bits = 20 bits
    always @* begin
        // preload shift with binary in LSBs
        shift = 20'd0;
        shift[15:0] = binary;
        // double-dabble
        for (i = 0; i < 16; i = i + 1) begin
            if (shift[19:16] > 4) shift[19:16] = shift[19:16] + 3;
            if (shift[15:12] > 4) shift[15:12] = shift[15:12] + 3;
            if (shift[11:8]  > 4) shift[11:8]  = shift[11:8]  + 3;
            if (shift[7:4]   > 4) shift[7:4]   = shift[7:4]   + 3;
            if (shift[3:0]   > 4) shift[3:0]   = shift[3:0]   + 3;
            shift = shift << 1;
        end
        {bcd4, bcd3, bcd2, bcd1, bcd0} = shift[19:0];
    end
endmodule