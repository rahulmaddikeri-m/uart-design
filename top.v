
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.05.2026 14:49:11
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns /1ps
`default_nettype none
module top #(parameter baudr = 115200, parameter dw = 8, parameter clk_freq = 50000000)(
	output wire  uart_XMIT_dataH,
	output  wire xmit_doneH,
	output  wire xmit_active,
	output  wire [dw-1:0]rec_dataH,
	output  wire rec_readyH,
	output  wire rec_busy,
	input  wire xmitH,
	input  wire [dw-1:0]xmit_dataH,
	input  wire sys_clk,
	input  wire sys_rst_l,
	input  wire uart_REC_dataH
);

xmitt #(.baudr(baudr), .dw(dw), .clk_freq(clk_freq)) Tx(
	.uart_XMIT_dataH(uart_XMIT_dataH),
	.xmit_doneH(xmit_doneH),
	.xmit_active(xmit_active),
	.clk(sys_clk),
	.rst(sys_rst_l),
	.xmitH(xmitH),
	.xmit_dataH(xmit_dataH)
);

rec #(.baudr(baudr), .dw(dw), .clk_freq(clk_freq)) Rx(
	.rec_dataH(rec_dataH),
	.rec_readyH(rec_readyH),
	.rec_busy(rec_busy),
	.clk(sys_clk),
	.rst(sys_rst_l),
	.uart_REC_dataH(uart_REC_dataH)
);


endmodule
