/***************************************************************************
 *                                                                         *
 *   text_mode.v - Generates characters from ASCII data and is designed to *
 *     give an 80x25 text-mode display at a resolution at 720x400 .        *
 *                                                                         *
 *   Copyright (C) 2007 by Patrick Suggate                                 *
 *   patrick@physics.otago.ac.nz                                           *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/

`timescale 1ns/100ps
module text_mode (
	dot_clk_i,
	chr_clk_i,
	reset_ni,
	
	de_i,
	vsync_i,
	hsync_i,
	
	addr_o,
	data_i,
	
	vsync_o,
	hsync_o,
	de_o,
	red_o,
	green_o,
	blue_o
);

// parameter	COL_MAX	= 720;	// 80*9
// parameter	ROW_MAX	= 400;	// 25*16

parameter	COL_MAX	= 80;	// 80*9
parameter	ROW_MAX	= 25;	// 25*16

`define	ROW_MAX	ROW_MAX
`define	COL_MAX	COL_MAX

input	dot_clk_i;
input	chr_clk_i;
input	reset_ni;

input	de_i;
input	vsync_i;
input	hsync_i;

output	[11:0]	addr_o;
input	[15:0]	data_i;

output	vsync_o;
output	hsync_o;
output	de_o;
output	red_o;
output	green_o;
output	blue_o;


`define	TMST_PREDRAW	1'b0
`define	TMST_REDRAW	1'b1
reg	state	= `TMST_PREDRAW;

reg	prev_hsync	= 0;
reg	prev_vsync	= 0;
reg	prev_de		= 0;
reg	redraw_started	= 0;

reg	[4:0]	row	= 0;	// 25 rows.
reg	[6:0]	col	= 0;	// 80 columns.
reg	[11:0]	addr_o	= 0;

wire	edge_vsync;
wire	edge_hsync;
wire	edge_de;


assign	hsync_o	= prev_hsync;
assign	vsync_o	= prev_vsync;
assign	de_o	= prev_de;

assign	#1 edge_hsync	= hsync_i && !prev_hsync;
assign	#1 edge_vsync	= hsync_i && !prev_vsync;
assign	#1 edge_de	= hsync_i && !prev_de;


always @(posedge chr_clk_i) begin
	if (!reset_ni) begin
		prev_hsync	<= #1 0;
		prev_vsync	<= #1 0;
		prev_de		<= #1 0;
	end
	else begin
		prev_hsync	<= #1 hsync_i;
		prev_vsync	<= #1 vsync_i;
		prev_de		<= #1 de_i;
	end
end


always @(posedge chr_clk_i) begin
	if (!reset_ni)
		state	<= #1 `TMST_PREDRAW;
	else case (state)
	`TMST_PREDRAW:	// Waiting for DE
		if (edge_de)	state	<= #1 `TMST_REDRAW;
		else		state	<= #1 state;
	
	`TMST_REDRAW:	// Drawing text
		if (row < `ROW_MAX)	state	<= #1 state;
		else			state	<= #1 `TMST_PREDRAW;
	endcase
end


always @(posedge chr_clk_i) begin
	if (!reset_ni)
		row	<= #1 0;
	else case (state)
		`TMST_PREDRAW:	row	<= #1 0;
		`TMST_REDRAW:	if (edge_hsync)	row	<= #1 row + 1;
	endcase
end


always @(posedge chr_clk_i) begin
	if (!reset_ni)
		col	<= #1 0;
	else case (state)
		`TMST_PREDRAW:	col	<= #1 0;
		`TMST_REDRAW: begin
			if (edge_hsync)
				col	<= #1 0;
			else if (de_i)
				col	<= #1 col + 1;
			else
				col	<= #1 col;
		end
	endcase
end


endmodule	// text_mode
