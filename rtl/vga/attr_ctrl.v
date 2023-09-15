/***************************************************************************
 *                                                                         *
 *   attr_ctrl.v - VGA attribute controller. This module handles the gen-  *
 *     eration of colour values for the external palette.                  *
 *     TODO: Text-mode generation is in the module?                        *
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

`timescale 1ns / 100ps
module attr_ctrl (
	clock_i,	// Dot clock
	reset_ni,
	
	pal_write_i,
	pal_addr_i,
	pal_data_i,
	
	textmode_i,
	monotext_i,
	linechr_mode_i,
	textblink_i,
	splitpanning_i,
	colour256_i,
	coloursel4_i,	// 4-bits come from the colour select reg. if set
	
	overscan_clr_i,	// Overscan colour
	plane_en_i,	// Can enable the incoming plane's bits
	status_sel_i,	// Select colour bits to a special debug register
	horiz_pan_i,	// Upto one character or 8 pixels can be panned
	coloursel_i,	// 4-bits that can be combined for 8-bit output
	
	status_sel_o,
	
	de_i,		// When DE is low and not blanking, display the over-
	hblank_i,	// scan border colour
	vblank_i,
	
	colour_i,	// From the VGA graphics controller
	colour_o	// 8-bit value to external palette
);

input	clock_i;
input	reset_ni;

input	pal_write_i;
input	[3:0]	pal_addr_i;
input	[5:0]	pal_data_i;

input		textmode_i;
input		monotext_i;
input		linechr_mode_i;
input		textblink_i;
input		splitpanning_i;
input		colour256_i;
input		coloursel4_i;

input	[7:0]	overscan_clr_i;	// TODO
input	[3:0]	plane_en_i;
input	[1:0]	status_sel_i;	// TODO
input	[3:0]	horiz_pan_i;	// TODO
input	[3:0]	coloursel_i;

output	[1:0]	status_sel_o;	// TODO

input	de_i;
input	hblank_i;
input	vblank_i;

input	[3:0]	colour_i;
output	[7:0]	colour_o;


// 16 colour internal palette.
reg	[5:0]	palette [0:15];
reg	[7:0]	colour_r;
reg	[3:0]	colour_m;	// Masked colour input

wire	[7:0]	colour_w;
wire	[5:0]	pal_colour	= palette [colour_m];


assign	colour_w [7:6]	= coloursel_i [3:2];
assign	colour_w [5:4]	= coloursel4_i ? coloursel_i [1:0] : pal_colour [5:4];
assign	colour_w [3:0]	= pal_colour [3:0];


// Masked colour output. This also affects 256 colour packed pixel mode.
always @(posedge clock_i)
	colour_m	<= colour_i & plane_en_i;


always @(posedge clock_i)
begin
	if (reset_ni)
	begin
		if (pal_write_i)
			palette [pal_addr_i]	<= pal_data_i;
	end
end


// Generating the output 8-bit colour value is different depending whether or
// not 256 packed pixel colour mode is selected.
always @(posedge clock_i)
begin
	if (!reset_ni)
		colour_r	<= 0;
	else
	begin
		if (colour256_i)
		begin
			colour_r [3:0]	<= colour_m;
			colour_r [7:4]	<= colour_r [3:0];
		end
		else
			colour_r	<= colour_w;
	end
end


endmodule	// attr_ctrl
