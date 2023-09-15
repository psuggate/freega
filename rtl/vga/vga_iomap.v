/***************************************************************************
 *                                                                         *
 *   vga_iomap.v - Maps a memory and an I/O port interface onto the VGA's  *
 *     registers.                                                          *
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

// This module has the task of matching the VGA's I/O ports and memory mapped
// registers, as seen from the outside world, to the actual VGA registers.
// The X11 driver would use the memory-mapped registers, but legacy software
// (and BIOS routines) will try to use the I/O ports instead.
//

`timescale 1ns/100ps
module vga_iomap (
	clock_i,
	reset_i,
	
	portwrite_i,
	portaddr_i,
	portdata_i,
	portdata_o,
	
	mem_write_i,
	mem_addr_i,
	mem_bes_ni,
	mem_data_i,
	mem_data_o,
	
	ctrc_horiz_total_o,
	crtc_horiz_disp_en_end_o,
	crtc_horiz_blank_start_o,
	crtc_horiz_blank_end_o,
	crtc_horiz_retrace_start_o,
	crtc_horiz_retrace_end_o,
	
	crtc_vert_total_o,
	crtc_vert_retrace_start_o,
	crtc_vert_retrace_end_o,
	crtc_vert_disp_en_end_o,
	crtc_vert_blank_start_o,
	crtc_vert_blank_end_o,
	
);

input	portwrite_i;
input	[ADDR_BITS-1:0]	portaddr_i;
input	[7:0]	portdata_i;
output	[7:0]	portdata_o;

input	memwrite_i;
input	[ADDR_BITS-1:0]	memaddr_i;
input	[7:0]	memdata_i;
output	[7:0]	memdata_o;


output	[7:0]	ctrc_horiz_total_o;
output	[7:0]	crtc_horiz_disp_en_end_o;
output	[7:0]	crtc_horiz_blank_start_o;
output	[5:0]	crtc_horiz_blank_end_o;
output	[7:0]	crtc_horiz_retrace_start_o;
output	[4:0]	crtc_horiz_retrace_end_o;

output	[9:0]	crtc_vert_total_o;
output	[9:0]	crtc_vert_retrace_start_o;
output	[3:0]	crtc_vert_retrace_end_o;
output	[9:0]	crtc_vert_disp_en_end_o;
output	[9:0]	crtc_vert_blank_start_o;
output	[7:0]	crtc_vert_blank_end_o;


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


assign	crtc_horiz_total_o		= read_regs [`HTOTAL];
assign	crtc_horiz_disp_en_end_o	= read_regs [`HDEEND];
assign	crtc_horiz_blank_start_o	= read_regs [`HBSTRT];
assign	crtc_horiz_blank_end_o		= read_regs [`HBEND];
assign	crtc_horiz_retrace_start_o	= read_regs [`HRSTRT];
assign	crtc_horiz_retrace_end_o	= read_regs [`HREND];

assign	crtc_vert_total_o		= read_regs [`VTOTAL];
assign	crtc_vert_disp_en_end_o		= read_regs [`VDEEND];
assign	crtc_vert_retrace_start_o	= read_regs [`VRSTRT];
assign	crtc_vert_retrace_end_o		= read_regs [`VREND];
assign	crtc_vert_blank_start_o		= read_regs [`VRSTRT];
assign	crtc_vert_blank_end_o		= read_regs [`VREND];

memmap MM0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.portwrite_i	(),
	.portaddr_i	(),
	.portdata_i	(),
	.portdata_o	(),
	
	.mem_write_i	(mem_write_i),
	.mem_addr_i	(mem_addr_i),
	.mem_bes_ni	(mem_bes_ni),
	.mem_data_i	(mem_data_i),
	.mem_data_o	(mem_data_o),
	
	.regs_o	(write_regs),
	.regs_i	(read_regs)
);


endmodule	// vga_iomap
