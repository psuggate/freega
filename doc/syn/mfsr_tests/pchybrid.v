/***************************************************************************
 *                                                                         *
 *   pchybrid.v - A simple hybrid PC circuit.                              *
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

`define	TRADBITS	TRADBITS_XX

`timescale 1ns/100ps
module pchybrid #(
	parameter	WIDTH	= 16,
	parameter	TRADBITS	= `TRADBITS,
	parameter	MFSRBITS	= WIDTH - TRADBITS,
	parameter	USEMFSR	= 1,	// Kept for compat reasons
	parameter	MSB	= WIDTH - 1,
	parameter	USB	= MSB - TRADBITS,
	parameter	TSB	= TRADBITS - 1
) (
	input		clock,
	input		reset,
	input		load,
	input		enable,
	input	[MSB:0]	data,
	output	[MSB:0]	count
);

reg	[MSB:0]	cnt	= 0;
wire	[MSB:0]	cnt_inc;
wire	[TSB:0]	cnt_inc_trad;
wire	[USB:0]	cnt_inc_mfsr;

`define	UPPER	MSB:TRADBITS
`define	LOWER	TSB:0

assign	count		= cnt;
assign	#2 inc_upper	= cnt[`LOWER]=={TRADBITS{1'b1}};
assign	#2 cnt_upper	= inc_upper ? cnt_inc_mfsr : cnt[`UPPER];
assign	#2 cnt_inc_trad	= cnt[`LOWER] + 1;

always @(posedge clock)
	if (reset)		cnt[`UPPER]	<= #2 USEMFSR;
	else if (enable) begin
		if (load)	cnt[`UPPER]	<= #2 data[`UPPER];
		else		cnt[`UPPER]	<= #2 cnt_upper;
	end else		cnt[`UPPER]	<= #2 cnt[`UPPER];

always @(posedge clock)
	if (reset)		cnt[TSB:0]	<= #2 0;
	else if (enable) begin
		if (load)	cnt[`LOWER]	<= #2 data[`LOWER];
		else		cnt[`LOWER]	<= #2 cnt_inc_trad;
	end else		cnt[`LOWER]	<= #2 cnt[`LOWER];

MFSR_XX MFSR(
	.count_i(cnt[`UPPER]),
	.count_o(cnt_inc_mfsr)
);

endmodule	// pctest
