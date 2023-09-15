/***************************************************************************
 *                                                                         *
 *   sequencer.v - A sequencer module that is part of a VGA.               *
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
module sequencer (
	clock_i,	// All VGA timing is derived from this
	reset_ni,	// Global reset
	
	vga_reset_no,	// Signals to the rest of the VGA
	vga_dotclk_o,
	vga_chrclk_o,
	
	// All of the input flags and variables that determine the
	// behaviour of the sequencer.
	hardreset_i,
	softreset_i,
	
	chrwidth8_i,
	divclkby2_i,
	vgainhibit_i,
	mapmask_i,
	fontAoff_i,
	fontBoff_i,
	fontselect_i,
	textmodemem_i,
	packedpixel_i
);

input	clock_i;
input	reset_ni;

output	vga_reset_no;
output	vga_dotclk_o;
output	vga_chrclk_o;

input	hardreset_i;
input	softreset_i;

input	chrwidth8_i;
input	divclkby2_i;
input	vgainhibit_i;
input	[3:0]	mapmask_i;
input	[2:0]	fontAoff_i;
input	[2:0]	fontBoff_i;
input	fontselect_i;
input	textmodemem_i;
input	packedpixel_i;


// The two possible reset modes.
reg	hardreset	= 0;
reg	safereset	= 0;

// Character clock is dot-clock divided by 9 when this is 0, else it
// is divided by 8.
reg	chrwidth8	= 0;

// Divide the dot-clock by two when set.
reg	divclkby2	= 0;

// Screen inhibit prevents the drawing of the screen while continuing
// to maintain VSync and HSync. This allows all of the memory band-
// width for the bus.
reg	vgainhibit	= 0;

// Map masks are used to allow writes to certain bit-planes when set.
reg	[3:0]	map_mask	= 0;	// TODO: Or 0x0F?

// Font offsets
reg	[2:0]	fontA_off	= 0;
reg	[2:0]	fontB_off	= 0;

// Select font B when set.
reg	fontselect	= 0;

// Textmode has bit-planes 0 & 2 mapped to even addresses (and the
// text-mode character), and bit-planes 1 & 3 mapped to odd addresses
// (text mode attribute byte. When this register is one, all four
// bit-planes are mapped to the same address.
reg	textmodemem	= 0;

// When set, the lower 2-bits of the address are a pixel plane, and
// each plane is 16k of the 64k window. When zero, the address reads
// or writes to all four planes simultaneously (depending on the bit-
// masks).
reg	packedpixel	= 0;


// FIXME:
assign	vga_reset_no	= reset_ni;


// Optional clock pre-divide by two.
reg	clock_div2	= 0;
always @(posedge clock_i)
begin
	if (!reset_ni)
		clock_div2	<= 0;
	else
		clock_div2	<= ~clock_div2;
end


// TODO: `BUFGMUX'?
assign	vga_dotclk_o	= divclkby2_i ? clock_div2 : clock_i;


charclock_gen CHRCLK0 (
	.clock_i	(vga_dotclk_o),
	.mode8_i	(chrwidth8_i),
	.div2_i		(divclkby2_i),
	.clock_o	(vga_chrclk_o)
);


endmodule	// sequencer
