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
 with speed grade M, core voltage 1.1V, and temperature 0 Celsius

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
_5.331__5.611__delay:		DELAY 5.331 5.611 ;
_4.393__4.574__delay:		DELAY 4.393 4.574 ;
_4.938__5.267__delay:		DELAY 4.938 5.267 ;
_4.645__4.925__delay:		DELAY 4.645 4.925 ;
_4.990__5.220__delay:		DELAY 4.990 5.220 ;
_4.857__5.018__delay:		DELAY 4.857 5.018 ;
_5.310__5.721__delay:		DELAY 5.310 5.721 ;
_5.116__5.411__delay:		DELAY 5.116 5.411 ;
_5.073__5.325__delay:		DELAY 5.073 5.325 ;
_4.551__4.636__delay:		DELAY 4.551 4.636 ;
_5.120__5.233__delay:		DELAY 5.120 5.233 ;
_5.132__5.390__delay:		DELAY 5.132 5.390 ;
_5.111__5.319__delay:		DELAY 5.111 5.319 ;
_4.830__4.936__delay:		DELAY 4.830 4.936 ;
_5.135__5.487__delay:		DELAY 5.135 5.487 ;
_4.658__4.834__delay:		DELAY 4.658 4.834 ;
_5.385__5.717__delay:		DELAY 5.385 5.717 ;
_4.332__4.452__delay:		DELAY 4.332 4.452 ;
_5.070__5.390__delay:		DELAY 5.070 5.390 ;
_4.636__4.851__delay:		DELAY 4.636 4.851 ;
_5.141__5.393__delay:		DELAY 5.141 5.393 ;
_4.909__5.131__delay:		DELAY 4.909 5.131 ;
_5.692__6.057__delay:		DELAY 5.692 6.057 ;
_5.235__5.538__delay:		DELAY 5.235 5.538 ;
_5.410__5.673__delay:		DELAY 5.410 5.673 ;
_4.946__5.092__delay:		DELAY 4.946 5.092 ;
_5.373__5.548__delay:		DELAY 5.373 5.548 ;
_5.187__5.498__delay:		DELAY 5.187 5.498 ;
_5.331__5.489__delay:		DELAY 5.331 5.489 ;
_4.837__4.935__delay:		DELAY 4.837 4.935 ;
_5.098__5.501__delay:		DELAY 5.098 5.501 ;
_4.804__4.973__delay:		DELAY 4.804 4.973 ;
_4.354__4.532__delay:		DELAY 4.354 4.532 ;
_4.932__5.090__delay:		DELAY 4.932 5.090 ;
_4.559__4.719__delay:		DELAY 4.559 4.719 ;
_5.203__5.493__delay:		DELAY 5.203 5.493 ;
_4.641__4.801__delay:		DELAY 4.641 4.801 ;
_5.073__5.290__delay:		DELAY 5.073 5.290 ;
_4.559__4.852__delay:		DELAY 4.559 4.852 ;
_5.428__5.840__delay:		DELAY 5.428 5.840 ;
_4.657__4.840__delay:		DELAY 4.657 4.840 ;
_4.960__5.240__delay:		DELAY 4.960 5.240 ;
_4.467__4.585__delay:		DELAY 4.467 4.585 ;
_5.192__5.548__delay:		DELAY 5.192 5.548 ;
_4.084__4.136__delay:		DELAY 4.084 4.136 ;
_5.089__5.281__delay:		DELAY 5.089 5.281 ;
_4.831__5.067__delay:		DELAY 4.831 5.067 ;
_5.136__5.395__delay:		DELAY 5.136 5.395 ;
_4.471__4.701__delay:		DELAY 4.471 4.701 ;
_4.847__5.097__delay:		DELAY 4.847 5.097 ;
_4.463__4.632__delay:		DELAY 4.463 4.632 ;
_5.165__5.465__delay:		DELAY 5.165 5.465 ;
_4.517__4.726__delay:		DELAY 4.517 4.726 ;
_5.141__5.344__delay:		DELAY 5.141 5.344 ;
_4.436__4.671__delay:		DELAY 4.436 4.671 ;
_5.310__5.731__delay:		DELAY 5.310 5.731 ;
_4.502__4.632__delay:		DELAY 4.502 4.632 ;
_4.996__5.230__delay:		DELAY 4.996 5.230 ;
_4.459__4.630__delay:		DELAY 4.459 4.630 ;
_5.216__5.624__delay:		DELAY 5.216 5.624 ;
_4.026__4.066__delay:		DELAY 4.026 4.066 ;
_5.085__5.286__delay:		DELAY 5.085 5.286 ;
_4.743__4.928__delay:		DELAY 4.743 4.928 ;
_5.015__5.187__delay:		DELAY 5.015 5.187 ;

ENDMODEL
