
//////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.05.2026 14:35:18
// Design Name: 
// Module Name: xmitt
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
module xmitt #(parameter baudr = 115200, parameter dw = 8, parameter clk_freq = 50000000)(
	output reg uart_XMIT_dataH,
	output reg xmit_doneH,
	output reg xmit_active,
	input  wire  clk,
	input  wire rst,
	input  wire xmitH,
	input  wire [dw-1:0]xmit_dataH
);

localparam idle = 0;
localparam start = 1;
localparam data = 2;
localparam stop = 3;

wire baud_clk;

reg [1:0]st;
reg [$clog2(dw)-1:0] bit_count;
reg [dw-1:0] temp;
reg [3:0] samp;

baud #(.baudr(baudr), .clk_freq(clk_freq)) baud_generator(.clk(clk), .rst(rst), .baud_clk(baud_clk));

always@(posedge baud_clk or negedge rst)begin
if(!rst)begin
	uart_XMIT_dataH <= 1;
	xmit_doneH <= 0;
	xmit_active <= 0;

	temp <= 0;
	bit_count <= 0;
    samp <= 0;
	st <= idle;
end

else begin
		case(st)
		idle:begin
		xmit_doneH <= 1;
			uart_XMIT_dataH <= 1;
			xmit_active <= 0;
			bit_count <= 0;
            samp <= 0;
            
			if(xmitH)begin
				temp <= xmit_dataH;
				xmit_active <= 1;	
				st <= start;
			end
		end
				
		start: begin
			uart_XMIT_dataH <= 0;
			xmit_doneH <= 0;
			samp <= samp + 1;
                if(samp == 15)begin
                    samp <= 0;
                    st <= data;
                end  
		end

		data: begin
			uart_XMIT_dataH <= temp[0];
			xmit_doneH <= 0;
			samp <= samp + 1;
			if(samp == 15)begin
			     samp <= 0;
			     temp <= temp >> 1;
			     if(bit_count == dw - 1)begin
					   bit_count <= 0;
				       st <= stop;
                end
                else begin
                    bit_count <= bit_count + 1;
                end
            end
        end
		stop: begin
			uart_XMIT_dataH <= 1;
			xmit_doneH <= 0;
			xmit_active <= 0;
			samp <= samp + 1;
			    if(samp == 15)begin
			         samp <= 0;
			         xmit_doneH  <= 1;
			         st <= idle;
                end
        end
		endcase
	end
end
endmodule
                 
                 
                 
                 