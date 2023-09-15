/***************************************************************************
 *                                                                         *
 *   top.v - The top module of a simple PC circuit.                        *
 *                                                                         *
 *   Copyright (C) 2009 by Patrick Suggate                                 *
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

`define	WIDTH	WIDTH_XX
`define	H	(`WIDTH-1)

`timescale 1ns/100ps
module top(
	input		clock,
	input		reset,
	input		enable,
	input		jmp,
	input	[`H:0]	adr,
	output	[`H:0]	pc
);

reg		inc_r	= 0;
reg		jmp_r	= 0;
reg	[`H:0]	adr_r	= 0;

// Register inputs.
always @(posedge clock)
	if (reset)	{adr_r, jmp_r, inc_r}	<= #2 0;
	else begin
		inc_r	<= #2 enable;
		jmp_r	<= #2 jmp;
		adr_r	<= #2 adr;
	end

PCMODULE_XX #(
	.WIDTH	(`WIDTH),
	.USEMFSR(USEMFSR_XX)
) PC (
	.clock	(clock),
	.reset	(reset),
	.enable	(inc_r),
	.load	(jmp_r),
	.data	(adr_r),
	.count	(pc)
);

endmodule
