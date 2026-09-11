//-----------------------------------------------------------------------------
// eth_crc32.vh - Byte-serial Ethernet CRC-32 (reflected, poly 0xEDB88320)
// Included by the MAC. crc starts at 0xFFFFFFFF; the transmitted FCS is the
// bitwise complement, sent low byte first.
//-----------------------------------------------------------------------------
`ifndef ETH_CRC32_VH
`define ETH_CRC32_VH

function [31:0] crc32_byte;
    input [31:0] crc_in;
    input [7:0]  data;
    integer i;
    reg [31:0] c;
    begin
        c = crc_in ^ {24'h0, data};
        for (i = 0; i < 8; i = i + 1)
            c = c[0] ? ((c >> 1) ^ 32'hEDB88320) : (c >> 1);
        crc32_byte = c;
    end
endfunction

`endif
