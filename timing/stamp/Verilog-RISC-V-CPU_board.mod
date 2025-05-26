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
 with speed grade 6, core voltage 1.1V, and temperature 85 Celsius

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
_8.831__9.094__delay:		DELAY 8.831 9.094 ;
_7.139__7.346__delay:		DELAY 7.139 7.346 ;
_8.190__8.571__delay:		DELAY 8.190 8.571 ;
_7.505__7.859__delay:		DELAY 7.505 7.859 ;
_8.228__8.457__delay:		DELAY 8.228 8.457 ;
_7.773__7.949__delay:		DELAY 7.773 7.949 ;
_8.815__9.314__delay:		DELAY 8.815 9.314 ;
_8.177__8.565__delay:		DELAY 8.177 8.565 ;
_8.290__8.551__delay:		DELAY 8.290 8.551 ;
_7.281__7.347__delay:		DELAY 7.281 7.347 ;
_8.483__8.505__delay:		DELAY 8.483 8.505 ;
_8.335__8.630__delay:		DELAY 8.335 8.630 ;
_8.468__8.704__delay:		DELAY 8.468 8.704 ;
_7.813__7.922__delay:		DELAY 7.813 7.922 ;
_8.588__9.028__delay:		DELAY 8.588 9.028 ;
_7.566__7.777__delay:		DELAY 7.566 7.777 ;
_8.901__9.263__delay:		DELAY 8.901 9.263 ;
_6.962__7.071__delay:		DELAY 6.962 7.071 ;
_8.372__8.754__delay:		DELAY 8.372 8.754 ;
_7.435__7.675__delay:		DELAY 7.435 7.675 ;
_8.584__8.851__delay:		DELAY 8.584 8.851 ;
_7.907__8.181__delay:		DELAY 7.907 8.181 ;
_9.443__9.844__delay:		DELAY 9.443 9.844 ;
_8.429__8.816__delay:		DELAY 8.429 8.816 ;
_8.925__9.202__delay:		DELAY 8.925 9.202 ;
_7.955__8.119__delay:		DELAY 7.955 8.119 ;
_8.835__8.977__delay:		DELAY 8.835 8.977 ;
_8.407__8.801__delay:		DELAY 8.407 8.801 ;
_8.773__8.940__delay:		DELAY 8.773 8.940 ;
_7.750__7.860__delay:		DELAY 7.750 7.860 ;
_8.478__9.009__delay:		DELAY 8.478 9.009 ;
_7.721__7.927__delay:		DELAY 7.721 7.927 ;
_6.989__7.153__delay:		DELAY 6.989 7.153 ;
_8.263__8.355__delay:		DELAY 8.263 8.355 ;
_7.354__7.497__delay:		DELAY 7.354 7.497 ;
_8.636__8.938__delay:		DELAY 8.636 8.938 ;
_7.568__7.732__delay:		DELAY 7.568 7.732 ;
_8.367__8.598__delay:		DELAY 8.367 8.598 ;
_7.426__7.764__delay:		DELAY 7.426 7.764 ;
_8.973__9.505__delay:		DELAY 8.973 9.505 ;
_7.544__7.776__delay:		DELAY 7.544 7.776 ;
_8.193__8.537__delay:		DELAY 8.193 8.537 ;
_7.265__7.333__delay:		DELAY 7.265 7.333 ;
_8.549__8.954__delay:		DELAY 8.549 8.954 ;
_6.603__6.648__delay:		DELAY 6.603 6.648 ;
_8.399__8.591__delay:		DELAY 8.399 8.591 ;
_7.828__8.135__delay:		DELAY 7.828 8.135 ;
_8.486__8.842__delay:		DELAY 8.486 8.842 ;
_7.234__7.512__delay:		DELAY 7.234 7.512 ;
_8.057__8.311__delay:		DELAY 8.057 8.311 ;
_7.285__7.427__delay:		DELAY 7.285 7.427 ;
_8.516__8.862__delay:		DELAY 8.516 8.862 ;
_7.315__7.571__delay:		DELAY 7.315 7.571 ;
_8.476__8.708__delay:		DELAY 8.476 8.708 ;
_7.101__7.341__delay:		DELAY 7.101 7.341 ;
_8.708__9.229__delay:		DELAY 8.708 9.229 ;
_7.317__7.450__delay:		DELAY 7.317 7.450 ;
_8.292__8.538__delay:		DELAY 8.292 8.538 ;
_7.205__7.372__delay:		DELAY 7.205 7.372 ;
_8.576__9.080__delay:		DELAY 8.576 9.080 ;
_6.412__6.451__delay:		DELAY 6.412 6.451 ;
_8.463__8.654__delay:		DELAY 8.463 8.654 ;
_7.727__7.942__delay:		DELAY 7.727 7.942 ;
_8.310__8.486__delay:		DELAY 8.310 8.486 ;

ENDMODEL
