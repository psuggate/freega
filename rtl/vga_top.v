/***************************************************************************
 *                                                                         *
 *   vga_top.v - Top level VGA module for FreeGA.                          *
 *                                                                         *
 *   Copyright (C) 2008 by Patrick Suggate                                 *
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

// FIXME: There seems to be a bug causing data to be written out of alignment
// by one address when writing large bursts. Maybe a PCI TARGET ABORT could
// be used to keep the bursts small to prevent this bug?
`define	__debug

`timescale 1ns/100ps
module	vga_top (
	sys_clk_i,
	cpu_clk_i,
	mem_clk_i,
	dot_clk_o,
	chr_clk_o,
	reset_ni,
	
	mem_read_o,
	mem_rack_i,
	mem_ready_i,
	mem_addr_o,
	mem_data_i,
	
	hsync_o,
	vsync_o,
	red_o,
	green_o,
	blue_o,
	de_o
);

parameter	WIDTH	= 32;
parameter	ADDRESS	= 21;
parameter	FBSIZE	= 18;
parameter	FBOFF	= 3'b100;

parameter	MSB	= WIDTH - 1;
parameter	ASB	= ADDRESS - 1;
parameter	FSB	= FBSIZE - 1;

input		sys_clk_i;
input		cpu_clk_i;
input		mem_clk_i;
output		dot_clk_o;
output		chr_clk_o;
input		reset_ni;

output		mem_read_o;
input		mem_rack_i;
input		mem_ready_i;
output	[ASB:0]	mem_addr_o;
input	[MSB:0]	mem_data_i;

output		hsync_o;
output		vsync_o;
output	[7:0]	red_o;
output	[7:0]	green_o;
output	[7:0]	blue_o;
output		de_o;


reg		hsync_o	= 1;
reg		vsync_o	= 1;
reg		de_o	= 0;

reg	[15:0]	upper_word;
reg		odd	= 1;
wire	[31:0]	mdata;
wire		read;
reg	[7:0]	red_o, green_o, blue_o;
wire	[9:0]	row, col;

wire		dot_clk, chr_clk;
wire		hsync, vsync, de, hblank, vblank;


assign	dot_clk_o	= dot_clk;
assign	chr_clk_o	= chr_clk;

assign	mem_addr_o [ASB:FBSIZE]	= FBOFF;

assign	#2 read		= (de && odd);


// Make sure all output signals are free from combinatorial delays and
// therefore in phase.
always @(posedge dot_clk)
	if (!reset_ni)	{hsync_o, vsync_o, de_o}	<= #2 3'b110;
	else begin
		hsync_o	<= #2 hsync;
		vsync_o	<= #2 vsync;
		de_o	<= #2 de;
	end


//---------------------------------------------------------------------------
//  Display DATAPATH:
//	The memory controller fetches data with a width of 32-bits, but the
//	display uses 16-bit colour data.
always @(posedge dot_clk)
	if (!reset_ni)	odd	<= #2 0;
	else if (hsync)	odd	<= #2 0;
	else if (de)	odd	<= #2 ~odd;

always @(posedge dot_clk)
	if (!odd)	upper_word	<= #2 mdata [31:16];

always @(posedge dot_clk)
	if (hblank || vblank)
		{red_o, green_o, blue_o}	<= #2 0;
	else begin
/*		red_o	<= #2 odd ? upper_word [15:8] : mdata [15:8];
		green_o	<= #2 odd ? upper_word [7:0] : mdata [7:0];
		blue_o	<= #2 0;*/
		
		blue_o	<= #2 {odd ? upper_word [15:11] : mdata [15:11], 3'b000};
		green_o	<= #2 {odd ? upper_word [10:5] : mdata [10:5], 2'b00};
		red_o	<= #2 {odd ? upper_word [4:0] : mdata [4:0], 3'b000};
	end


//---------------------------------------------------------------------------
//  Display redraw PREFETCH:
//	The display uses significant memory bandwidth for redrawing the
//	contents of the screen. At mode 640x480x16@60Hz, the total bandwidth
//	needed is about 35 MB/s. To sustain this rate, and to make sure data
//	is ready when needed, a large prefetch FIFO is used.
//
prefetch #(
	.WIDTH		(WIDTH),
	.ADDRESS	(FBSIZE)	// Enough for 640x480x16
) PREFETCH0 (
	.mem_clk_i	(mem_clk_i),
	.dot_clk_i	(dot_clk),
	.reset_ni	(reset_ni),
	.enable_i	(1'b1),
	
	// Dot clock domain
	.d_vsync_i	(vsync),
	.d_read_i	(read),
	.d_data_o	(mdata),
	
	// Memory clock domain
	.m_read_o	(mem_read_o),
	.m_rack_i	(mem_rack_i),
	.m_ready_i	(mem_ready_i),
	.m_addr_o	(mem_addr_o [FSB:0]),
	.m_data_i	(mem_data_i)
);


//---------------------------------------------------------------------------
//  Generate CRT monitor control signals.
//
crtc #(
	.WIDTH	(10)
) CRTC0 (
	.clock_i	(chr_clk),	// Character clock
	.reset_ni	(reset_ni),
	.enable_i	(1'b1),
`ifdef __icarus
	.hsynct_i	(1),
	.hbporch_i	(2),
	.hactive_i	(11),
	.hfporch_i	(12),
	
	.vsynct_i	(1),
	.vbporch_i	(2),
	.vactive_i	(11),
	.vfporch_i	(12),
`else
	.hsynct_i	(11),
	.hbporch_i	(17),
	.hactive_i	(97),
	.hfporch_i	(99),	// h-total too
	
	.vsynct_i	(1),
	.vbporch_i	(34),
	.vactive_i	(514),
	.vfporch_i	(524),
`endif	/* criple_mode */
	.row_o		(row),
	.col_o		(col),
	
	.de_o		(de),
	.hsync_o	(hsync),
	.vsync_o	(vsync),
	.hblank_o	(hblank),
	.vblank_o	(vblank)
);


//---------------------------------------------------------------------------
//  Clocking stuff. Different phases of clocks are needed since there are
//  real-world delays, like IOB delays.
//
wire	GND	= 0;
wire	clk_out, clk90, clk180, clk270, clk_over_8, lock;
DCM #(
	.CLKIN_DIVIDE_BY_2	("TRUE"),	// 50 -> 25 MHz
	.CLKDV_DIVIDE		(8),
	.CLK_FEEDBACK		("1X"),
	.DLL_FREQUENCY_MODE	("LOW")
) dcm0 (
	.CLKIN	(sys_clk_i),
	.CLKFB	(dot_clk),
	.DSSEN	(GND),
	.PSEN	(GND),
	.RST	(~reset_ni),
	.CLK0	(clk_out),
	.CLK90	(clk90),
	.CLK180	(clk180),
	.CLK270	(clk270),
	.CLKDV	(clk_over_8),
	.LOCKED	(lock)
);


BUFG dot_bufg (
	.I	(clk_out),
	.O	(dot_clk)
);


BUFG chr_bufg (
	.I	(clk_over_8),
	.O	(chr_clk)
);


endmodule	// vga_top
