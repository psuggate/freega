/***************************************************************************
 *                                                                         *
 *   crtc_iomap.v - Maps a memory and an I/O port interface onto the VGA's *
 *     CRTC registers.                                                     *
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

// This module has the task of matching the CRTC's I/O ports and memory-
// mapped registers, as seen from the outside world, to the actual CRTC
// registers.
// The X11 driver would use the memory-mapped registers, but legacy software
// (and BIOS routines) will try to use the I/O ports instead.
//

`timescale 1ns/100ps
module crtc_iomap (
	dot_clock_i,
	chr_clock_i,
	bus_clock_i,
	reset_ni,
	
	// These map to the I/O and memory interfaces
	port_write_i,
	port_addr_i,
	port_data_i,
	port_data_o,
	
	mem_write_i,
	mem_addr_i,
	mem_bes_ni,
	mem_data_i,
	mem_data_o,
	
	// CRTC signals
	hsync_o,
	vsync_o,
	
	hblank_o,
	vblank_o,
	
	de_o,
	de_next_o,
	
	memory_ptr_o,
	row_address_o
);

input	dot_clock_i;
input	chr_clock_i;
input	bus_clock_i;
input	reset_ni;

input	portwrite_i;
input	[ADDR_BITS-1:0]	portaddr_i;
input	[7:0]	portdata_i;
output	[7:0]	portdata_o;

input	memwrite_i;
input	[ADDR_BITS-1:0]	memaddr_i;
input	[7:0]	memdata_i;
output	[7:0]	memdata_o;


// The register `read_regs' is a 1D flip-flop array that gets set by memory
// or I/O port accesses. If there are gaps in the array that aren't used (16-
// bits of space is usually reserved for non-flag values, for example), these
// are reserved for future expansion.
`define	HTOTAL	7:0
`define	HDEEND	23:16
`define	HBSTRT	39:32
`define	HBEND	53:48
`define	HRSTRT	71:64
`define	HREND	84:80

`define	VTOTAL	105:96
`define	VDEEND	121:112
`define	VRSTRT	137:128
`define	VREND	147:144
`define	VBSTRT	169:160
`define	VBEND	183:176

wire	[255:0]	crtc_regs;

wire	horiz_total		= crtc_regs [`HTOTAL];
wire	horiz_disp_en_end	= crtc_regs [`HDEEND];
wire	horiz_blank_start	= crtc_regs [`HBSTRT];
wire	horiz_blank_end		= crtc_regs [`HBEND];
wire	horiz_retrace_start	= crtc_regs [`HRSTRT];
wire	horiz_retrace_end	= crtc_regs [`HREND];

wire	vert_total		= crtc_regs [`VTOTAL];
wire	vert_disp_en_end	= crtc_regs [`VDEEND];
wire	vert_retrace_start	= crtc_regs [`VRSTRT];
wire	vert_retrace_end	= crtc_regs [`VREND];
wire	vert_blank_start	= crtc_regs [`VRSTRT];
wire	vert_blank_end		= crtc_regs [`VREND];


memmap CRTCMM0 (
	.clock_i	(bus_clock_i),
	.reset_ni	(reset_ni),
	
	.port_write_i	(port_write_i),
	.port_addr_i	(port_addr_i),
	.port_data_i	(port_data_i),
	.port_data_o	(port_data_o),
	
	.mem_write_i	(mem_write_i),
	.mem_addr_i	(mem_addr_i),
	.mem_bes_ni	(mem_bes_ni),
	.mem_data_i	(mem_data_i),
	.mem_data_o	(mem_data_o),
	
	.regs_o		(crtc_regs),
	.regs_i		(crtc_regs)
);


crtc CRTC0 (
	.clock_i		(chr_clock_i),	// Character clock
	.reset_ni		(reset_ni),
	
	// CRTC Register values
	// Horizontal redrawing stuff
	.horiz_total_i		(horiz_total),
	.horiz_disp_en_cnt_i	(horiz_disp_en_end),
	.horiz_blank_start_i	(horiz_blank_start),
	.horiz_blank_end_i	(horiz_blank_end),
	.horiz_disp_en_skew_i	(2'b0),	// TODO
	.horiz_retrace_start_i	(horiz_retrace_start),
	.horiz_retrace_end_i	(horiz_retrace_end),
	.horiz_retrace_skew_i	(2'b0),	// TODO
	.horiz_retrace_div_i	(1'b0),
	
	// Vertical redrawing stuff
	.vert_total_i		(vert_total),
	.vert_retrace_start_i	(vert_retrace_start),
	.vert_retrace_end_i	(vert_retrace_end),
	.vert_disp_en_end_i	(vert_disp_en_end),
	.vert_blank_start_i	(vert_blank_start),
	.vert_blank_end_i	(vert_blank_end),
	.vert_int_en_ni		(1'b0),
	.vert_int_clr_ni	(1'b0),
	.vert_int_o		(),
	
	// Scan-lines within a char. stuff
	.scan_row_preset_i	(5'b0),
	.scan_max_i		(5'h0f),
	.scan_double_i		(1'b0),	// TODO
	.scan_cursor_en_ni	(1'b0),
	.scan_cursor_start_i	(5'h0d),
	.scan_cursor_end_i	(5'h0e),
	.scan_cursor_skew_i	(2'b0),
	.scan_uline_loc_i	(5'h1f),
	
	// Misc. regs
	.mem_start_i		('b0),
	.cursor_location_i	('b0),
	.refresh_bandwidth_i	(1'b0),
	.write_protect_i	(1'b1),
	.display_word_size_i	(2'b00),
	.display_img_off_i	(8'h28),
	.dwell_i		(2'b00),
	.light_pen_en_ni	(1'b1),
	
	.hsync_o		(hsync_o),
	.hblank_o		(hblank_o),
	
	.vsync_o		(vsync_o),
	.vblank_o		(vblank_o),
	
	.DE_o			(de_o),	// Display enable
	.DEnext_o		(de_next_o),
	
	.cursor_o		(),
	.uline_o		(),
	
	.memory_ptr_o		(memory_ptr_o),	// Used for text & graphics modes
	.row_address_o		(row_address_o)	// Used for text-mode
);


endmodule	// crtc_iomap
