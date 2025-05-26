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
 This file contains Slow Corner delays for the design using part 5CSEMA5F31C6
 with speed grade 6, core voltage 1.1V, and temperature 0 Celsius

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
_8.524__8.770__delay:		DELAY 8.524 8.770 ;
_6.858__7.099__delay:		DELAY 6.858 7.099 ;
_7.902__8.308__delay:		DELAY 7.902 8.308 ;
_7.218__7.594__delay:		DELAY 7.218 7.594 ;
_7.934__8.188__delay:		DELAY 7.934 8.188 ;
_7.406__7.630__delay:		DELAY 7.406 7.630 ;
_8.478__9.022__delay:		DELAY 8.478 9.022 ;
_7.820__8.227__delay:		DELAY 7.820 8.227 ;
_7.906__8.204__delay:		DELAY 7.906 8.204 ;
_6.968__7.051__delay:		DELAY 6.968 7.051 ;
_8.272__8.264__delay:		DELAY 8.272 8.264 ;
_8.027__8.323__delay:		DELAY 8.027 8.323 ;
_8.178__8.460__delay:		DELAY 8.178 8.460 ;
_7.531__7.661__delay:		DELAY 7.531 7.661 ;
_8.294__8.768__delay:		DELAY 8.294 8.768 ;
_7.293__7.522__delay:		DELAY 7.293 7.522 ;
_8.601__8.967__delay:		DELAY 8.601 8.967 ;
_6.689__6.820__delay:		DELAY 6.689 6.820 ;
_8.090__8.504__delay:		DELAY 8.090 8.504 ;
_7.157__7.401__delay:		DELAY 7.157 7.401 ;
_8.333__8.614__delay:		DELAY 8.333 8.614 ;
_7.595__7.929__delay:		DELAY 7.595 7.929 ;
_9.159__9.575__delay:		DELAY 9.159 9.575 ;
_8.141__8.538__delay:		DELAY 8.141 8.538 ;
_8.595__8.905__delay:		DELAY 8.595 8.905 ;
_7.684__7.877__delay:		DELAY 7.684 7.877 ;
_8.606__8.747__delay:		DELAY 8.606 8.747 ;
_8.105__8.521__delay:		DELAY 8.105 8.521 ;
_8.508__8.720__delay:		DELAY 8.508 8.720 ;
_7.446__7.586__delay:		DELAY 7.446 7.586 ;
_8.185__8.771__delay:		DELAY 8.185 8.771 ;
_7.423__7.647__delay:		DELAY 7.423 7.647 ;
_6.692__6.849__delay:		DELAY 6.692 6.849 ;
_8.000__8.101__delay:		DELAY 8.000 8.101 ;
_7.056__7.200__delay:		DELAY 7.056 7.200 ;
_8.356__8.652__delay:		DELAY 8.356 8.652 ;
_7.297__7.466__delay:		DELAY 7.297 7.466 ;
_8.064__8.330__delay:		DELAY 8.064 8.330 ;
_7.146__7.503__delay:		DELAY 7.146 7.503 ;
_8.676__9.218__delay:		DELAY 8.676 9.218 ;
_7.237__7.524__delay:		DELAY 7.237 7.524 ;
_7.863__8.261__delay:		DELAY 7.863 8.261 ;
_7.019__7.083__delay:		DELAY 7.019 7.083 ;
_8.219__8.614__delay:		DELAY 8.219 8.614 ;
_6.376__6.453__delay:		DELAY 6.376 6.453 ;
_8.087__8.296__delay:		DELAY 8.087 8.296 ;
_7.496__7.849__delay:		DELAY 7.496 7.849 ;
_8.206__8.596__delay:		DELAY 8.206 8.596 ;
_6.972__7.254__delay:		DELAY 6.972 7.254 ;
_7.769__8.049__delay:		DELAY 7.769 8.049 ;
_7.027__7.161__delay:		DELAY 7.027 7.161 ;
_8.235__8.592__delay:		DELAY 8.235 8.592 ;
_7.025__7.306__delay:		DELAY 7.025 7.306 ;
_8.189__8.452__delay:		DELAY 8.189 8.452 ;
_6.807__7.044__delay:		DELAY 6.807 7.044 ;
_8.378__8.910__delay:		DELAY 8.378 8.910 ;
_7.028__7.195__delay:		DELAY 7.028 7.195 ;
_8.020__8.290__delay:		DELAY 8.020 8.290 ;
_6.941__7.125__delay:		DELAY 6.941 7.125 ;
_8.241__8.756__delay:		DELAY 8.241 8.756 ;
_6.132__6.211__delay:		DELAY 6.132 6.211 ;
_8.196__8.395__delay:		DELAY 8.196 8.395 ;
_7.411__7.652__delay:		DELAY 7.411 7.652 ;
_8.067__8.236__delay:		DELAY 8.067 8.236 ;

ENDMODEL
