/***************************************************************************
 *                                                                         *
 *   crtc.v - A CRT/LCD controller for a VGA.                              *
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
module crtc (
	clock_i,	// Character clock
	reset_ni,
	
	// CRTC Register values
	// Horizontal redrawing stuff
	horiz_total_i,
	horiz_disp_en_cnt_i,
	horiz_blank_start_i,
	horiz_blank_end_i,
	horiz_disp_en_skew_i,	// TODO
	horiz_retrace_start_i,
	horiz_retrace_end_i,
	horiz_retrace_skew_i,	// TODO
	horiz_retrace_div_i,	// TODO
	
	// Vertical redrawing stuff
	vert_total_i,
	vert_retrace_start_i,
	vert_retrace_end_i,
	vert_disp_en_end_i,
	vert_blank_start_i,
	vert_blank_end_i,
	vert_int_en_ni,		// TODO
	vert_int_clr_ni,	// TODO
	vert_int_o,		// TODO
	
	// Scan-lines within a char. stuff
	scan_row_preset_i,
	scan_max_i,
	scan_double_i,		// TODO
	scan_cursor_en_ni,	// TODO
	scan_cursor_start_i,	// TODO
	scan_cursor_end_i,	// TODO
	scan_cursor_skew_i,	// TODO
	scan_uline_loc_i,	// TODO
	
	// Misc. regs
	mem_start_i,
	cursor_location_i,	// TODO
	refresh_bandwidth_i,
	write_protect_i,	// TODO
	display_word_size_i,	// TODO
	display_img_off_i,	// TODO
	dwell_i,		// TODO
	light_pen_en_ni,	// TODO
	
	hsync_o,
	hblank_o,
	
	vsync_o,
	vblank_o,
	
	DE_o,		// Display enable
	DEnext_o,
	
	cursor_o,
	uline_o,
	
	memory_ptr_o,	// Used for text & graphics modes
	row_address_o		// Used for text-mode
);

input	clock_i;
input	reset_ni;

input	[7:0]	horiz_total_i;	// Actual total is input value + 5

// Controls the display enabling and blanking.
input	[7:0]	horiz_disp_en_cnt_i;
input	[7:0]	horiz_blank_start_i;
input	[5:0]	horiz_blank_end_i;
input	[1:0]	horiz_disp_en_skew_i;	// Number of cycles to delay DE

// Controls the retrace signal.
input	[7:0]	horiz_retrace_start_i;
input	[4:0]	horiz_retrace_end_i;
input	[1:0]	horiz_retrace_skew_i;
input		horiz_retrace_div_i;

input	[9:0]	vert_total_i;	// Actual total is input + 2

// Controls the vertical retrace.
input	[9:0]	vert_retrace_start_i;
input	[3:0]	vert_retrace_end_i;	// Lower 4-bits only

input	[9:0]	vert_disp_en_end_i;

input	[9:0]	vert_blank_start_i;
input	[7:0]	vert_blank_end_i;

input		vert_int_en_ni;
input		vert_int_clr_ni;
output		vert_int_o;

// Scan line stuff. Upto 32 scan lines per character.
input	[4:0]	scan_row_preset_i;
input	[4:0]	scan_max_i;
input		scan_double_i;	// Increment counter every two scan lines

// Cursor location within a character cell.
input		scan_cursor_en_ni;
input	[4:0]	scan_cursor_start_i;
input	[4:0]	scan_cursor_end_i;
input	[1:0]	scan_cursor_skew_i;

input	[4:0]	scan_uline_loc_i;


// Miscellaneous stuff.
input	[15:0]	mem_start_i;	// Offset into framebuffer of first pixel
input	[15:0]	cursor_location_i;
input		refresh_bandwidth_i;	// Selects between 3 or 5 refreshes per row
input		write_protect_i;
input	[1:0]	display_word_size_i;	// 1, 2, or 4 bytes / word
input	[7:0]	display_img_off_i;
input	[1:0]	dwell_i;		// Allows same address for upto 4 chars
input	light_pen_en_ni;


// Monitor timing signals
output	hsync_o;
output	hblank_o;

output	vsync_o;
output	vblank_o;

output	DE_o;
output	DEnext_o;

// Text-mode signals
output	cursor_o;
output	uline_o;

// Redraw addressing signals.
output	[15:0]	memory_ptr_o;
output	[4:0]	row_address_o;


// Registered outputs.
reg	hsync_o		= 0;
reg	hblank_o	= 0;

reg	vsync_o		= 0;
reg	vblank_o	= 0;

reg	DE_o		= 0;
reg	DEnext_o	= 0;


// Internal counters.
reg	[7:0]	hcount	= 0;
reg	[9:0]	vcount	= 0;
reg	[4:0]	lcount	= 0;


reg	reset_col	= 0;
reg	reset_row	= 0;

reg	inc_row		= 0;

reg	hdisp_en	= 0;
reg	vdisp_en	= 0;

reg	hblank_st	= 1;
reg	hblank_end	= 0;

reg	vblank_st	= 1;
reg	vblank_end	= 0;

reg	hsync_st	= 0;
reg	hsync_end	= 0;

reg	vsync_st	= 0;
reg	vsync_end	= 0;

reg		inc_col		= 0;
reg		inc_scanline	= 0;
reg	[7:0]	col_counter	= 0;
reg	[4:0]	row_counter	= 0;
reg	[15:0]	row_start	= 0;
reg	[15:0]	memory_ptr_o	= 0;


assign	row_address_o	= row_counter;


// Generate the horizontal redraw signals.
always @(posedge clock_i)
begin
	if (reset_col || !reset_ni)
		hcount	<= 0;
	else
		hcount	<= hcount + 1;
end


reg	[3:0]	reset_col_srl;
always @(posedge clock_i)
begin
	reset_col_srl [0]	<= (hcount == horiz_total_i) & reset_ni;
	reset_col_srl [3:1]	<= reset_col_srl [2:0];
	reset_col		<= reset_col_srl;
end


// Horizontal output display enable (ANDed with the vertical value).
always @(posedge clock_i)
begin
	if (!reset_ni)
		hdisp_en	<= 0;
	else
		hdisp_en	<= (hcount <= horiz_disp_en_cnt_i);
end


// Horizontal blanking
always @(posedge clock_i)
begin
	if (!reset_ni)
	begin
		hblank_st	<= 1;
		hblank_end	<= 0;
	end
	else
	begin
		hblank_st	<= (hcount > horiz_blank_start_i);
		hblank_end	<= (hcount [5:0] == horiz_blank_end_i);	// FIXME
	end
end


// Horizontal retrace (HSync).
// TODO: HSync skew SRL logic.
always @(posedge clock_i)
begin
	if (!reset_ni)
	begin
		hsync_st	<= 0;
		hsync_end	<= 0;
	end
	else
	begin
		if (hcount == horiz_retrace_start_i)
			hsync_st	<= 1;
		else if (hsync_end)
			hsync_st	<= 0;
		
		if (hsync_st && (hcount [4:0] == horiz_retrace_end_i))
			hsync_end	<= 1;
		else
			hsync_end	<= 0;
	end
end


// Vertical redraw signals.
// TODO: Support `horiz_retrace_div_i'.
always @(posedge clock_i)
begin
	if (reset_row)
		vcount	<= 0;
	else if (inc_row)
		vcount	<= vcount + 1;
end


reg	reset_row_dly	= 0;
always @(posedge clock_i)
begin
	if (!reset_ni)
	begin
		reset_row	<= 0;
		reset_row_dly	<= 0;
	end
	else if (inc_row)
	begin
		reset_row_dly	<= ((vcount == vert_total_i) && inc_row) || (!reset_ni);
		reset_row	<= reset_row_dly;
	end
	else
		reset_row	<= 0;
end


always @(posedge clock_i)
begin
	if (!reset_ni)
		inc_row	<= 0;
	else
		inc_row	<= (hcount == horiz_retrace_start_i);
end


always @(posedge clock_i)
begin
	if (!reset_ni)
		vdisp_en	<= 0;
	else
		vdisp_en	<= (vcount <= vert_disp_en_end_i);
end


always @(posedge clock_i)
begin
	if (!reset_ni)
	begin
		vblank_st	<= 1;
		vblank_end	<= 0;
	end
	else
	begin
		vblank_st	<= (vcount >= vert_blank_start_i);
		vblank_end	<= (vcount [7:0] >= vert_blank_end_i);
	end
end


always @(posedge clock_i)
begin
	if (!reset_ni)
	begin
		vsync_st	<= 0;
		vsync_end	<= 0;
	end
	else
	begin
		// FIXME
		vsync_st	<= (vcount >= vert_retrace_start_i) && !reset_row;
		if (vsync_st && !vsync_end)
			vsync_end	<= (vcount [3:0] >= vert_retrace_end_i);
		else if (reset_row)
			vsync_end	<= 0;
	end
end


// Registered outputs.
always @(posedge clock_i)
begin
	// TODO: Allow sync. polarity to be set (0x3c2 wr, 0x3cc rd)
	hsync_o		<= hsync_st && !hsync_end;
	vsync_o		<= vsync_st && !vsync_end;
	
	hblank_o	<= hblank_st && !hblank_end;
	vblank_o	<= vblank_st && !vblank_end;
	
	DEnext_o	<= hdisp_en && vdisp_en;
	DE_o		<= DEnext_o;
end


// Operation principle:
// The CRTC fetches the same row of display information `scan_max_i' minus
// one times. This is because some modes, text esp. but also 320x200 &
// 640x200 use a row of display information more than once. Every time a row
// of information is displayed a counter is increased. Once `scan_max_i' is
// reached, the row address is increased.
always @(posedge clock_i)
begin
	if (!reset_ni)
	begin
		memory_ptr_o	<= 0;
		row_start	<= 0;
		row_counter	<= 0;
		col_counter	<= 0;
		inc_col		<= 0;
		inc_scanline	<= 0;
	end
	else
	begin
		// TODO: DE skew.
		inc_col		<= (hcount < horiz_disp_en_cnt_i);
		inc_scanline	<= (reset_col && (row_counter == scan_max_i));
		
//		if (hcount < horiz_disp_en_cnt_i)
		if (inc_col)
			col_counter	<= col_counter + 1;
		else
			col_counter	<= 0;
		
		if (reset_row)
			row_counter	<= scan_row_preset_i;
		else if (reset_col)
		begin
			if (row_counter == scan_max_i)
				row_counter	<= 0;
			else
				row_counter	<= row_counter + 1;
		end
		
		// TODO: `display_img_off_i' is (bytes/row)/{2,4,8}.
		if (reset_row)
			row_start	<= mem_start_i;
//		else if (reset_col && (row_counter == scan_max_i))
		else if (inc_scanline)
			row_start	<= row_start + {display_img_off_i, 1'b0};
		
		// TODO: How fast does this clock?
		if (reset_row)
			memory_ptr_o	<= mem_start_i;
		else
			memory_ptr_o	<= row_start + col_counter;
		
	end
end


endmodule	// crtc
