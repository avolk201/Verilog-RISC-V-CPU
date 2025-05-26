module instatiate(
    input [3:0] KEY,
    output [9:0] LEDR,
    input [9:0] SW,
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
	 output [6:0] HEX4
);

wire [15:0] out;

cpu cpu(.clk(KEY0), .reset(KEY1), .debug_addr(SW[3:0]), .debug_data(out));

decoder decoder(.v(out), .seg4(HEX4), .seg3(HEX3), .seg2(HEX2), .seg1(HEX1), .seg0(HEX0));

endmodule