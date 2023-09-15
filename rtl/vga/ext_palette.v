/***************************************************************************
 *                                                                         *
 *  ext_palette.v - Converts incoming 8-bit colour values into 24-bit RGB  *
 *    values suitable for the VGA DAC.                                     *
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
module ext_palette (
	clock_i,
	reset_ni,
	
	read_i,
	write_i,
	rd_addr_set_i,
	wr_addr_set_i,
	raddr_i,
	waddr_i,
	data_i,
	data_o,
	
	de_i,
	de_o,
	
	pel_mask_i,
	readmode_o,
	
	colour_i,
	
	red_o,
	green_o,
	blue_o
);

input	clock_i;
input	reset_ni;

input		read_i;
input		write_i;
input		rd_addr_set_i;
input		wr_addr_set_i;
input	[7:0]	raddr_i;
input	[7:0]	waddr_i;
input	[7:0]	data_i;
output	[7:0]	data_o;

input	de_i;
output	de_o;

input	[7:0]	pel_mask_i;
output	[1:0]	readmode_o;

input	[7:0]	colour_i;

output	[7:0]	red_o;
output	[7:0]	green_o;
output	[7:0]	blue_o;


reg	[1:0]	rgb_sel		= 0;
reg		readmode	= 0;
reg		write_r		= 0;
reg	[7:0]	colour_r	= 0;
reg	[7:0]	data_o;
reg	[7:0]	rd_addr		= 0;
reg	[7:0]	wr_addr		= 0;
reg		de_o;

wire	[7:0]	pal_data;
wire	[1:0]	rgb_sel_next;

wire	[7:0]	unused8;
wire	[10:0]	ramaddr;


assign	ramaddr [1:0]	= rgb_sel;
assign	ramaddr [9:2]	= write_i ? wr_addr : rd_addr;
assign	ramaddr [10]	= 1'b0;
assign	readmode_o	= {readmode, readmode};


// This is so interrupt routines can set the palette back to a known state.
always @(posedge clock_i)
begin
	if (!reset_ni)
		readmode	<= 0;
	else
	begin
		if (read_i)
			readmode	<= 1;
		else if (write_i)
			readmode	<= 0;
		else
			readmode	<= readmode;
	end
end


// Handle the auto-incrementing of the RGB pointer. This is because every
// palette entry has 3 bytes that can be written to; red, green or blue.
// Back-to-back reads and back-to-back writes increment the pointer, but
// switching between reads and writes resets the pointer.
reg	auto_inc	= 0;
always @(posedge clock_i)
begin
	if (!reset_ni)
		rgb_sel	<= 0;
	else if (read_i && !readmode)
		rgb_sel	<= 0;
	else if (write_i && readmode)
		rgb_sel	<= 0;
	else if (read_i || write_i || auto_inc)
		rgb_sel	<= rgb_sel_next;
end


always @(posedge clock_i)
begin
	if (!reset_ni)
		auto_inc	<= 0;
	else
		auto_inc	<= (read_i && !readmode) || (write_i && readmode);
end


// After three consecutive reads or writes, increment the appropriate address
// pointer.
always @(posedge clock_i)
begin
	if (!reset_ni)
		rd_addr	<= 0;
	else
	begin
		if (rd_addr_set_i)
			rd_addr	<= raddr_i;
		else if (read_i)
			rd_addr	<= rd_addr + (rgb_sel == 2'b10);
	end
end


always @(posedge clock_i)
begin
	if (!reset_ni)
	begin
		wr_addr	<= 0;
		write_r	<= 0;
	end
	else
	begin
		write_r	<= write_i;
		
		if (wr_addr_set_i)
			wr_addr	<= waddr_i;
		else if (write_i)
			wr_addr	<= wr_addr + (rgb_sel == 2'b10);
	end
end


always @(posedge clock_i)
begin
	colour_r	<= colour_i & pel_mask_i;
end


reg	read_r	= 0;
always @(posedge clock_i)
begin
	if (!reset_ni)
		read_r	<= 0;
	else
	begin
//		read_r	<= read_i | rd_addr_set_i;
		
//		if (read_r)
			data_o	<= pal_data;
	end
end


// Explicitly instantiate the RAM block since the port wodths are different.
RAMB16_S9_S36 block_ram0 (
	.DIA(data_i),
	.DIPA(1'b0),
	.ADDRA(ramaddr),
	.ENA(1'b1),
	.WEA(write_i),
	.SSRA(1'b0),
	.CLKA(clock_i),
	.DOA(pal_data),
	
	.DIB(32'b0),
	.DIPB(4'b0),
	.ADDRB({1'b0, colour_r}),
	.ENB(1'b1),
	.WEB(1'b0),
	.SSRB(1'b0),
	.CLKB(clock_i),
	.DOB({unused8, blue_o, green_o, red_o})
);


// The pipelining in this module causes two more cycles of latency to be
// added to the incoming data, so DE needs to be delayed too.
reg	de_r;
always @(posedge clock_i)
begin
	de_r	<= de_i;
	de_o	<= de_r;
end


mfsr2 COUNT0 (
	.count_i	(rgb_sel),
	.count_o	(rgb_sel_next)
);


endmodule	// ext_palette
