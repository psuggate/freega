/***************************************************************************
 *                                                                         *
 *   charclock_gen.v - Character clock generator for a VGA.                *
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
module charclock_gen (
	clock_i,
	mode8_i,
	div2_i,
	clock_o
);

input	clock_i;
input	mode8_i;
input	div2_i;
output	clock_o;


reg	[2:0]	count8	= 0;
wire	div8	= count8 [2];
wire	div9;


// Divide by 8.
always @(posedge clock_i)
	count8	<= count8 + 1;


BUFGMUX bufg0 (
	.I0	(div9),
	.I1	(div8),
	.S	(mode8_i),
	.O	(clock_o)
);


// Divide by 9.
div9 DIV0 (
	.clock_i	(clock_i),
	.reset_ni	(1'b1),
	.clock_o	(div9)
);


endmodule	// charclock_gen
