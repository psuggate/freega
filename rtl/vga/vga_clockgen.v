/***************************************************************************
 *                                                                         *
 *   vga_clockgen.v - Handles the generation of all dot-clocks needed by   *
 *     the VGA.                                                            *
 *                                                                         *
 *   Copyright (C) 2006 by Patrick Suggate                                 *
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

module vga_clockgen (
		clk200_i,
		reset_i,
		
		clksel_i,
		chr9_i,
		
		dotclk_o,
		chrclk_o
	);
	
	input	clk200_i;
	input	reset_i;
	
	input	[3:0]	clksel_i;	// Allow for 16 pre-defined dot-clocks
	input	chr9;			// Is the character width 9 pixels?
	
	output	dotclk_o;
	output	chrclk_o;
	
	
	// Look up the divider value from a 16x8 ROM.
	reg	[7:0]	div;
	always @(posedge clk200_i)
	begin
		case (clksel_i)
		4'b0000:	div	<= 36;	// 25.175 MHz
		default:	div	<= 42;	// 28.322 MHz
		endcase
	end
	
	
	// Generate the character clock
	// TODO: Make sure the phasing is correct
	reg	[3:0]	chrcount;
	always @(posedge dotclk_o)
	begin
		if (reset_i)
			chrcount	<= 1;
		else
		begin
			if (chrcount == 1)
				chrcount	<= {3'b100, chr9_i};
			else
				chrcount	<= chrcount - 1;
		end
	end
	assign	chrclk	= (chrcount == 1);
	
	
	clockgen CG0 (
		.clk200_i	(clk_in),
		.div_i		(div),
		.clk_o		(clk_out)
	);
	
	
	// Use a DCM to correct the duty-cycle.
	
	
endmodule	// vga_clockgen
