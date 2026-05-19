
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.05.2026 11:16:28
// Design Name: 
// Module Name: baud
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
module baud #(parameter baudr = 115200, parameter clk_freq = 50000000)(
    output reg baud_clk,
    input wire clk,
    input  wire rst
);
localparam integer clk_count = clk_freq / (baudr * 16 * 2);

reg [$clog2(clk_count)-1:0] counter;

always @(posedge clk or negedge rst)
begin
    if(!rst)
    begin
        counter <= 0;
        baud_clk <= 0;
    end
    else
    begin
        if(counter == clk_count - 1)
        begin
            counter <= 0;
            baud_clk <= ~baud_clk;
        end
        else
        begin
            counter <= counter + 1;
        end
    end
end
endmodule

