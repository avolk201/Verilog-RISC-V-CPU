module binary_to_7Seg(binary, sevenSeg);

    input [3:0] binary;
    output reg [6:0] sevenSeg;

    always @(binary) begin
        case (binary)
            4'b0000: sevenSeg = 7'b1000000; // 0
            4'b0001: sevenSeg = 7'b1111001; // 1
            4'b0010: sevenSeg = 7'b0100100; // 2
            4'b0011: sevenSeg = 7'b0110000; // 3
            4'b0100: sevenSeg = 7'b0011001; // 4
            4'b0101: sevenSeg = 7'b0010010; // 5
            4'b0110: sevenSeg = 7'b0000010; // 6
            4'b0111: sevenSeg = 7'b1111000; // 7
            4'b1000: sevenSeg = 7'b0000000; // 8
            4'b1001: sevenSeg = 7'b0010000; // 9
				4'b1010:	sevenSeg = 7'b0001000; //a
				4'b1011: sevenSeg = 7'b0000011; //b
				4'b1100: sevenSeg = 7'b1000110; //c
				4'b1101: sevenSeg = 7'b0100001;
				4'b1110: sevenSeg = 7'b0000110;
				4'b1111: sevenSeg = 7'b0001110;
            default: sevenSeg = 7'b1111111; // Don't care (all segments off)
        endcase
    end

endmodule

module dual_binary_to_7Seg(binary1, binary0, sevenSeg1, sevenSeg0);

    input [3:0] binary1, binary0;
    output [6:0] sevenSeg1, sevenSeg0;

    // Instantiate two binary_to_7Seg modules
    binary_to_7Seg display1 (
        .binary(binary1),
        .sevenSeg(sevenSeg1)
    );

    binary_to_7Seg display0 (
        .binary(binary0),
        .sevenSeg(sevenSeg0)
    );

endmodule