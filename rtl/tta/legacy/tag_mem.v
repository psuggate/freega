`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    01:43:59 08/31/2007 
// Design Name: 
// Module Name:    top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top(
	clock_i,
	ad_i,
	tag_o
);

input	clock_i;
input	[5:0]	ad_i;
output	[2:0]	tag_o;

reg	[5:0]	ad;
reg	[2:0]	tag;

 // synthesis attribute ram_style of tag_mem is distributed ;
reg	[2:0]	tag_mem [0:63];

assign	tag_o	= tag;

always @(posedge clock_i) begin
	ad	<= ad_i;
	tag	<= tag_mem [ad];
end

endmodule
