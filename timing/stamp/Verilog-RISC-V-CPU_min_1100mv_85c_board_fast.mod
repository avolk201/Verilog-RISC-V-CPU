/*
 Copyright (C) 2022  Intel Corporation. All rights reserved.
 Your use of Intel Corporation's design tools, logic functions 
 and other software and tools, and any partner logic 
 functions, and any output files from any of the foregoing 
 (including device programming or simulation files), and any 
 associated documentation or information are expressly subject 
 to the terms and conditions of the Intel Program License 
 Subscription Agreement, the Intel Quartus Prime License Agreement,
 the Intel FPGA IP License Agreement, or other applicable license
 agreement, including, without limitation, that your use is for
 the sole purpose of programming logic devices manufactured by
 Intel and sold by Intel or its authorized distributors.  Please
 refer to the applicable agreement for further details, at
 https://fpgasoftware.intel.com/eula.
*/
MODEL
/*MODEL HEADER*/
/*
 This file contains Fast Corner delays for the design using part 5CSEMA5F31C6
 with speed grade M, core voltage 1.1V, and temperature 85 Celsius

*/
MODEL_VERSION "1.0";
DESIGN "Verilog-RISC-V-CPU";
DATE "05/26/2025 19:35:07";
PROGRAM "Quartus Prime";



INPUT clk;
INPUT reset;
INPUT debug_addr[1];
INPUT debug_addr[0];
INPUT debug_addr[2];
INPUT debug_addr[3];
OUTPUT debug_data[0];
OUTPUT debug_data[1];
OUTPUT debug_data[2];
OUTPUT debug_data[3];
OUTPUT debug_data[4];
OUTPUT debug_data[5];
OUTPUT debug_data[6];
OUTPUT debug_data[7];
OUTPUT debug_data[8];
OUTPUT debug_data[9];
OUTPUT debug_data[10];
OUTPUT debug_data[11];
OUTPUT debug_data[12];
OUTPUT debug_data[13];
OUTPUT debug_data[14];
OUTPUT debug_data[15];

/*Arc definitions start here*/
pos_clk__debug_data[0]__delay:		DELAY (POSEDGE) clk debug_data[0] ;
pos_clk__debug_data[1]__delay:		DELAY (POSEDGE) clk debug_data[1] ;
pos_clk__debug_data[2]__delay:		DELAY (POSEDGE) clk debug_data[2] ;
pos_clk__debug_data[3]__delay:		DELAY (POSEDGE) clk debug_data[3] ;
pos_clk__debug_data[4]__delay:		DELAY (POSEDGE) clk debug_data[4] ;
pos_clk__debug_data[5]__delay:		DELAY (POSEDGE) clk debug_data[5] ;
pos_clk__debug_data[6]__delay:		DELAY (POSEDGE) clk debug_data[6] ;
pos_clk__debug_data[7]__delay:		DELAY (POSEDGE) clk debug_data[7] ;
pos_clk__debug_data[8]__delay:		DELAY (POSEDGE) clk debug_data[8] ;
pos_clk__debug_data[9]__delay:		DELAY (POSEDGE) clk debug_data[9] ;
pos_clk__debug_data[10]__delay:		DELAY (POSEDGE) clk debug_data[10] ;
pos_clk__debug_data[11]__delay:		DELAY (POSEDGE) clk debug_data[11] ;
pos_clk__debug_data[12]__delay:		DELAY (POSEDGE) clk debug_data[12] ;
pos_clk__debug_data[13]__delay:		DELAY (POSEDGE) clk debug_data[13] ;
pos_clk__debug_data[14]__delay:		DELAY (POSEDGE) clk debug_data[14] ;
pos_clk__debug_data[15]__delay:		DELAY (POSEDGE) clk debug_data[15] ;
_5.715__6.069__delay:		DELAY 5.715 6.069 ;
_4.675__4.881__delay:		DELAY 4.675 4.881 ;
_5.273__5.647__delay:		DELAY 5.273 5.647 ;
_4.952__5.288__delay:		DELAY 4.952 5.288 ;
_5.323__5.623__delay:		DELAY 5.323 5.623 ;
_5.180__5.409__delay:		DELAY 5.180 5.409 ;
_5.688__6.169__delay:		DELAY 5.688 6.169 ;
_5.446__5.852__delay:		DELAY 5.446 5.852 ;
_5.401__5.742__delay:		DELAY 5.401 5.742 ;
_4.857__4.973__delay:		DELAY 4.857 4.973 ;
_5.442__5.647__delay:		DELAY 5.442 5.647 ;
_5.498__5.830__delay:		DELAY 5.498 5.830 ;
_5.403__5.681__delay:		DELAY 5.403 5.681 ;
_5.124__5.288__delay:		DELAY 5.124 5.288 ;
_5.434__5.890__delay:		DELAY 5.434 5.890 ;
_4.909__5.163__delay:		DELAY 4.909 5.163 ;
_5.795__6.188__delay:		DELAY 5.795 6.188 ;
_4.605__4.762__delay:		DELAY 4.605 4.762 ;
_5.413__5.789__delay:		DELAY 5.413 5.789 ;
_4.940__5.224__delay:		DELAY 4.940 5.224 ;
_5.495__5.796__delay:		DELAY 5.495 5.796 ;
_5.232__5.510__delay:		DELAY 5.232 5.510 ;
_6.114__6.554__delay:		DELAY 6.114 6.554 ;
_5.560__5.976__delay:		DELAY 5.560 5.976 ;
_5.770__6.125__delay:		DELAY 5.770 6.125 ;
_5.307__5.472__delay:		DELAY 5.307 5.472 ;
_5.744__5.989__delay:		DELAY 5.744 5.989 ;
_5.579__5.950__delay:		DELAY 5.579 5.950 ;
_5.677__5.881__delay:		DELAY 5.677 5.881 ;
_5.156__5.310__delay:		DELAY 5.156 5.310 ;
_5.410__5.902__delay:		DELAY 5.410 5.902 ;
_5.100__5.348__delay:		DELAY 5.100 5.348 ;
_4.631__4.859__delay:		DELAY 4.631 4.859 ;
_5.237__5.442__delay:		DELAY 5.237 5.442 ;
_4.865__5.065__delay:		DELAY 4.865 5.065 ;
_5.540__5.915__delay:		DELAY 5.540 5.915 ;
_4.937__5.147__delay:		DELAY 4.937 5.147 ;
_5.388__5.668__delay:		DELAY 5.388 5.668 ;
_4.854__5.194__delay:		DELAY 4.854 5.194 ;
_5.740__6.280__delay:		DELAY 5.740 6.280 ;
_4.936__5.167__delay:		DELAY 4.936 5.167 ;
_5.281__5.610__delay:		DELAY 5.281 5.610 ;
_4.728__4.881__delay:		DELAY 4.728 4.881 ;
_5.550__6.005__delay:		DELAY 5.550 6.005 ;
_4.247__4.342__delay:		DELAY 4.247 4.342 ;
_5.406__5.674__delay:		DELAY 5.406 5.674 ;
_5.148__5.443__delay:		DELAY 5.148 5.443 ;
_5.445__5.772__delay:		DELAY 5.445 5.772 ;
_4.731__5.010__delay:		DELAY 4.731 5.010 ;
_5.137__5.439__delay:		DELAY 5.137 5.439 ;
_4.726__4.936__delay:		DELAY 4.726 4.936 ;
_5.482__5.862__delay:		DELAY 5.482 5.862 ;
_4.802__5.049__delay:		DELAY 4.802 5.049 ;
_5.436__5.716__delay:		DELAY 5.436 5.716 ;
_4.708__5.003__delay:		DELAY 4.708 5.003 ;
_5.616__6.177__delay:		DELAY 5.616 6.177 ;
_4.731__4.923__delay:		DELAY 4.731 4.923 ;
_5.294__5.582__delay:		DELAY 5.294 5.582 ;
_4.733__4.925__delay:		DELAY 4.733 4.925 ;
_5.584__6.078__delay:		DELAY 5.584 6.078 ;
_4.194__4.277__delay:		DELAY 4.194 4.277 ;
_5.368__5.646__delay:		DELAY 5.368 5.646 ;
_5.020__5.278__delay:		DELAY 5.020 5.278 ;
_5.270__5.530__delay:		DELAY 5.270 5.530 ;

ENDMODEL
