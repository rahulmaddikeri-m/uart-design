
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.05.2026 11:47:16
// Design Name: 
// Module Name: rec
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
module rec #(parameter baudr = 115200, parameter dw = 8, parameter clk_freq = 50000000)(
	output reg [dw-1:0]rec_dataH,
	output reg rec_readyH,
	output reg rec_busy,
	input wire clk,
	input  wire rst,
	input  wire uart_REC_dataH
);

localparam idle  = 0;
localparam start = 1;
localparam data  = 2;
localparam stop  = 3;

wire baud_clk;
reg [1:0]st;
reg [$clog2(dw)-1:0] bit_count;
reg [dw-1:0] temp;
reg [3:0]samp;
reg F1, F2;

baud #(.baudr(baudr), .clk_freq(clk_freq)) baud_generator(.clk(clk), .rst(rst), .baud_clk(baud_clk));
always@(posedge clk or negedge rst)begin
if(!rst)begin
	F1 <= 1;
	F2 <= 1;
end

else begin
	F1 <= uart_REC_dataH;
	F2 <= F1;
end
end

always@(posedge baud_clk or negedge rst)begin
if(!rst)begin
	rec_dataH <= 0;
	rec_readyH <= 0;
	rec_busy <= 0;

	temp <= 0;
	bit_count <= 0;	
	
	st <= idle;
    samp <= 0;
end
else begin
        case(st)
            idle: begin
                rec_readyH <= 1;
                rec_busy <= 0;
                if(F2 == 0)begin
                    samp <= 0;
                    rec_busy <= 1;
                    rec_readyH <= 0;
                    st <= start;
                end
            end
            start: begin
                     if(samp == 5)begin
                         samp <= 0;
                         if(F2 == 0) begin
                            bit_count <= 0;
                            st <= data;
                         end
                         else begin
                            st <= idle;
                            rec_busy <= 0;
                         end
                     end
                     else begin
                        samp <= samp + 1;
                     end
           end
           data: begin
                rec_readyH <= 0;
                rec_busy <= 1;
                    if(samp == 15)begin
                        temp[bit_count] <= F2;
                        samp <= 0;
                        if(bit_count == dw - 1)begin
                            bit_count <= 0;
                            st <= stop;
                        end
                        else begin
                            bit_count <= bit_count + 1;
                        end
                   end
                   else begin
                        samp <= samp + 1;
                   end
            end
            stop: begin
                    rec_readyH <= 0;
                    rec_busy <= 1;
                    if(samp == 15)begin
                            samp <= 0;
                            if(F2 == 1)begin
                                rec_dataH <= temp;
                                rec_readyH <= 1;
                            end
                            rec_readyH <= 1;
                            rec_busy <= 0;
                            st <= idle;                           
                    end
                    else begin
                        samp <= samp + 1;
                    end
            end
            endcase
        end
    end

endmodule

