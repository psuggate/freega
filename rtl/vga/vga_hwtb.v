/***************************************************************************
 *                                                                         *
 *   vga_hwtb.v - The top-level module of a VGA hardware testbench.        *
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

`define __no_reset

`timescale 1ns/100ps
module vga_hwtb (
	clk50,
`ifndef __no_reset
	reset,
`endif
	
	leds,
	
	pci_disable,
	
/*	dvi_clock,
	dvi_de,
	dvi_hsync,
	dvi_vsync,
	dvi_red,
	dvi_green,
	dvi_blue,
	dvi_msen,
	dvi_pd_n
	*/
	vgaclk,
	r, g, b,
	hsync,
	vsync,
	de,
	blank_n,
	sync_n
);

input	clk50;
`ifndef __no_reset
input	reset;
`endif

output	[1:0]	leds;

output	pci_disable;

/*
output	dvi_clock;
output	dvi_de;
output	dvi_hsync;
output	dvi_vsync;
output	[7:0]	dvi_red;
output	[7:0]	dvi_green;
output	[7:0]	dvi_blue;
input	dvi_msen;
output	dvi_pd_n;
*/
output	vgaclk;
output	[7:0]	r, g, b;
output	hsync;
output	vsync;
output	de;
output	blank_n;
output	sync_n;


// reg	vgaclk;
reg	[7:0]	r, g, b;
reg	hsync, vsync;
reg	de, blank_n, sync_n;

wire	dot_clock;	// VGA wide signals
wire	char_clock;
wire	vga_reset_n;
wire	locked;


wire	hsync_w, vsync_w;	// Redraw signals
wire	hblank, vblank;
wire	de_w, de_next, de_crt;


wire	[15:0]	mem_addr;
wire	[4:0]	row_addr;

wire	[1:0]	clksel;

wire	[1:0]	readmode;

wire	[3:0]	colour4;
wire	[7:0]	colour8;


assign	pci_disable	= 1'b1;

// FIXME:
// assign	clksel	= 2'b01;	// 28.322 MHz dot clock for text-mode
assign	clksel	= 2'b01;	// 25.000 MHz dot clock for VGA-mode


//---------------------------------------------------------------------------
// TODO: This is just a simple test-pattern.

`define	__turq
`ifdef	__turq

wire	[7:0]	red, green, blue;
reg	[9:0]	col	= 0;

always @(posedge dot_clock)
	if (hsync_w)
		col	<= 0;
	else
		col	<= col + 1;

assign	red	= 0;
assign	blue	= col[8:1] & {8{de_w}};
assign	green	= col[8:1] & {8{de_w}};

`else

wire	[7:0]	red, green, blue;
wire	blue_w;
reg	red_r	= 0;

assign	red	= {8{red_r & de_w}};
assign	green	= {8{de_w}};
assign	blue	= {8{blue_w & de_w}};

always @(posedge char_clock)
	red_r	<= ~red_r;

// Divide by 9 .
div9 DIV0 (
	.clock_i	(hsync_w),
	.reset_ni	(~vsync_w & ~de_w),
	.clock_o	(blue_w)
);

`endif

//---------------------------------------------------------------------------

// Needs this phase shift so that clean data is latched.
assign	vgaclk	= ~dot_clock;

// This is so all signals are placed in IOBs so that they are in phase.
always @(posedge dot_clock)
	if (!vga_reset_n) begin
		hsync	<= 0;
		vsync	<= 0;
		de	<= 0;
		blank_n	<= 1;
		sync_n	<= 1;
		{r, g, b}	<= 0;
	end else begin
		hsync	<= hsync_w;
		vsync	<= vsync_w;
		de	<= de_w;
		blank_n	<= 1;	// TODO
		sync_n	<= 1;	// TODO
		r	<= red;
		g	<= green;
		b	<= blue;
	end


// This module generates the clocks and talks to the memory controller.
sequencer SEQ0 (
	.clock_i	(dot_clock),	// All VGA timing is derived from this
`ifndef __no_reset
	.reset_ni	(~reset),	// Global reset
`else
	.reset_ni	(1),	// Global reset
`endif
	
	.vga_reset_no	(vga_reset_n),	// Signals to the rest of the VGA
	.vga_dotclk_o	(),		// FIXME!
	.vga_chrclk_o	(char_clock),
	
	// All of the input flags and variables that determine the
	// behaviour of the sequencer.
	.hardreset_i	(1'b0),
	.softreset_i	(1'b0),
	
	.chrwidth8_i	(1'b0),
	.divclkby2_i	(1'b0),
	.vgainhibit_i	(1'b0),
	.mapmask_i	(4'hf),
	.fontAoff_i	(3'b0),
	.fontBoff_i	(3'b0),
	.fontselect_i	(1'b1),	// Textmode
	.textmodemem_i	(1'b1),	// Odd/even
	.packedpixel_i	(1'b0)	// Chain 4 mode
);


crtc CRTC0 (
	.clock_i		(char_clock),	// Character clock
	.reset_ni		(vga_reset_n),
	
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
	
	.hsync_o		(hsync_w),
	.hblank_o		(hblank),
	
	.vsync_o		(vsync_w),
	.vblank_o		(vblank),
	
	.DE_o			(de_crt),	// Display enable
	.DEnext_o		(de_next),
	
	.cursor_o		(),
	.uline_o		(),
	
	.memory_ptr_o		(mem_addr),	// Used for text & graphics modes
	.row_address_o		(row_addr)	// Used for text-mode
);


attr_ctrl ACTL0 (
	.clock_i	(dot_clock),	// Dot clock
	.reset_ni	(vga_reset_n),
	
	.pal_write_i	(),
	.pal_addr_i	(),
	.pal_data_i	(),
	
	.textmode_i	(),
	.monotext_i	(),
	.linechr_mode_i	(),
	.textblink_i	(),
	.splitpanning_i	(),
	.colour256_i	(),
	.coloursel4_i	(),	// 4-bits come from the colour select reg. if set
	
	.overscan_clr_i	(),	// Overscan colour
	.plane_en_i	(),	// Can enable the incoming plane's bits
	.status_sel_i	(),	// Select colour bits to a special debug register
	.horiz_pan_i	(),	// Upto one character or 8 pixels can be panned
	.coloursel_i	(),	// 4-bits that can be combined for 8-bit output
	
	.status_sel_o	(),
	
	.de_i		(de_crt),	// These are used to make the border colour
	.hblank_i	(hblank),
	.vblank_i	(vblank),
	
	.colour_i	(colour4),	// From the VGA sequencer
	.colour_o	(colour8)// 8-bit value to external palette
);


ext_palette PAL0 (
	.clock_i	(dot_clock),	// Character clock
	.reset_ni	(vga_reset_n),
	
	.read_i		(1'b0),
	.write_i	(1'b0),
	.rd_addr_set_i	(1'b0),
	.wr_addr_set_i	(1'b0),
	.raddr_i	(),
	.waddr_i	(),
	.data_i		(),
	.data_o		(),
	
	.de_i		(de_crt),
	.de_o		(de_w),
	
	.pel_mask_i	(8'hff),
	.readmode_o	(readmode),
	
	.colour_i	(colour8),
	
	.red_o		(),
	.green_o	(),
	.blue_o		()
);

/*
dvi_ctrl DVI0 (
	.clock_i	(dot_clock),	// VGA dot clock
	.reset_ni	(vga_reset_n),
	
	.hsync_i	(hsync_w),
	.vsync_i	(vsync_w),
	.de_i		(de_w),
	.red_i		(red),
	.green_i	(green),
	.blue_i		(blue),
	
	.dvi_clock_o	(dvi_clock),
	.dvi_hsync_o	(dvi_hsync),
	.dvi_vsync_o	(dvi_vsync),
	.dvi_de_o	(dvi_de),
	.dvi_red_o	(dvi_red),
	.dvi_green_o	(dvi_green),
	.dvi_blue_o	(dvi_blue),
	
	.dvi_msen_i	(dvi_msen),
	.dvi_pd_no	(dvi_pd_n)
);
*/

// Generates the 25 MHz and 28 MHz dot clocks.
clockgen CLKGEN0 (
	.clk50_i	(clk50),
`ifdef __no_reset
	.reset_i	(0),
`else
	.reset_i	(reset),
`endif	
	
	.clksel_i	(clksel),	// 25, 28, 50, & 100 MHz clock select
	.clock_o	(dot_clock),
	.locked_o	(locked)	// Inhibit VGA output until locked
);


reg	[24:0]	counter	= 0;
assign	leds [1]	= counter [23];
assign	leds [0]	= locked;

always @(posedge char_clock or negedge vga_reset_n)
begin
	if (!vga_reset_n)
		counter	<= 0;
	else
		counter	<= counter + 1;
end


endmodule	// vga_hwtb
