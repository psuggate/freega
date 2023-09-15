/***************************************************************************
 *                                                                         *
 *   crtc_top.v - A CRT/LCD controller for a VGA.                          *
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
module crtc_top (
	chr_clock_i,
	reset_ni,
	
	hsync_o,
	vsync_o,
	
	hblank_o,
	vblank_o,
	
	de_o,
	de_next_o,
	
	// This is shared for both port and memory accesses.
	bus_clock_i,
	
	port_read_i,
	port_write_i,
	port_addr_i,
	port_data_i,
	port_data_o,
	
	mem_read_i,
	mem_write_i,
	mem_bes_ni,
	mem_addr_i,
	mem_data_i,
	mem_data_o
);

input	chr_clock_i;
input	reset_ni;

input	port_clock_i;
input	port_read_i;
input	port_write_i;
output	port_ready_o;
input	[3:0]	port_bes_ni;
input	[4:0]	port_addr_i;
input	[31:0]	port_data_i;
output	[31:0]	port_data_o;


input	mem_clock_i;
input	mem_read_i;
input	mem_write_i;
input	[3:0]	mem_bes_ni;
input	[4:0]	mem_addr_i;
input	[31:0]	mem_data_i;
output	[31:0]	mem_data_o;


// CRTC registers.
reg	[7:0]	horiz_total;
reg	[7:0]	horiz_disp_en_cnt;
reg	[7:0]	horiz_blank_start;
reg	[5:0]	horiz_blank_end;
reg	[1:0]	horiz_disp_en_skew;
reg	[7:0]	horiz_retrace_start;
reg	[4:0]	horiz_retrace_end;
reg	[1:0]	horiz_retrace_skew;
reg	horiz_retrace_div;

reg	[9:0]	vert_total;
reg	[9:0]	vert_retrace_start;
reg	[3:0]	vert_retrace_end;
reg	[9:0]	vert_disp_en_end;
reg	[9:0]	vert_blank_start;
reg	[7:0]	vert_blank_end;

reg	[4:0]	scan_row_preset;
reg	[4:0]	scan_max;
reg	scan_double;
reg	scan_cursor_en_n;
reg	[4:0]	scan_cursor_start;
reg	[4:0]	scan_cursor_end;
reg	[1:0]	scan_cursor_skew;
reg	[4:0]	scan_uline_loc;

reg	[15:0]	mem_start;
reg	[15:0]	cursor_location;
reg	refresh_bandwidth;	// TODO: Ignore?
reg	write_protect;
reg	[1:0]	display_word_size;
reg	[7:0]	display_img_off;
reg	[1:0]	dwell;
reg	light_pen_en_n;
reg	[9:0]	line_compare;


// Turn a port request into memory request(s).
reg	[7:0]	port_data_o;

always @(posedge bus_clock_i)
begin
	if (port_read_i)
	begin
		case (port_addr_i)
		5'd0:	port_data_o	<= horiz_total;
		5'd1:	port_data_o	<= horiz_disp_en_cnt;
		5'd2:	port_data_o	<= horiz_blank_start;
		5'd3:	port_data_o	<= {light_pen_en_n,
					horiz_disp_en_skew,
					horiz_blank_end [4:0]};
		5'd4:	port_data_o	<= horiz_retrace_start;
		5'd5:	port_data_o	<= {horiz_blank_end [5],
					horiz_retrace_skew,
					horiz_retrace_end};
		5'd6:	port_data_o	<= vert_total [7:0];
		5'd7:	port_data_o	<= {vert_total [8],
					vert_disp_en_end [8],
					vert_retrace_start [8],
					vert_blank_start [8],
					line_compare [8],
					vert_total [9],
					vert_disp_en_end [9],
					vert_retrace_start [9]};
		5'd8:	port_data_o	<= 
		default:	port_data_o	<= 'bx;
		endcase
	end
	else if (port_write_i)
	begin
		case (port_addr_i)
		
		endcase
	end
end



crtc CRTC0 (
	.clock_i		(chr_clock_i),	// Character clock
	.reset_ni		(reset_ni),
	
	// CRTC Register values
	// Horizontal redrawing stuff
	.horiz_total_i		(8'h5f),
	.horiz_disp_en_cnt_i	(8'h4f),
	.horiz_blank_start_i	(8'h50),
	.horiz_blank_end_i	(6'h22),
	.horiz_disp_en_skew_i	(2'b0),	// TODO
	.horiz_retrace_start_i	(8'h54),
	.horiz_retrace_end_i	(5'h01),
	.horiz_retrace_skew_i	(2'b0),	// TODO
	.horiz_retrace_div_i	(1'b0),
	
	// Vertical redrawing stuff
	.vert_total_i		(10'h1bf),
	.vert_retrace_start_i	(10'h183),
	.vert_retrace_end_i	(4'h5),
	.vert_disp_en_end_i	(10'h15d),
	.vert_blank_start_i	(10'h163),
	.vert_blank_end_i	(8'hba),
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
	.line_compare_i		(10'b0),
	
	.hsync_o		(hsync),
	.hblank_o		(hblank),
	
	.vsync_o		(vsync),
	.vblank_o		(vblank),
	
	.DE_o			(de),	// Display enable
	.DEnext_o		(de_next),
	
	.cursor_o		(),
	.uline_o		(),
	
	.memory_ptr_o		(mem_addr),	// Used for text & graphics modes
	.row_address_o		(row_addr)	// Used for text-mode
);


endmodule	// crtc_top
