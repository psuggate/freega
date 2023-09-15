/***************************************************************************
 *                                                                         *
 *   pctest.v - A simple PC circuit.                                       *
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

USEMFSR_XX

`timescale 1ns/100ps
module pctest #(
	parameter	WIDTH	= 16,
	parameter	USEMFSR	= 1,
	parameter	MSB	= WIDTH - 1
) (
	input		clock,
	input		reset,
	input		load,
	input		enable,
	input	[MSB:0]	data,
	output	[MSB:0]	count
);

reg	[MSB:0]	cnt	= 0;
wire	[MSB:0]	cnt_inc, cnt_inc_trad, cnt_inc_mfsr;

assign	count	= cnt;
assign	cnt_inc	= USEMFSR ? cnt_inc_mfsr : cnt_inc_trad ;

assign	#3 cnt_inc_trad	= cnt + 1;

always @(posedge clock)
	if (reset)		cnt	<= #2 0;
	else if (enable) begin
		if (load)	cnt	<= #2 data;
		else		cnt	<= #2 cnt_inc;
	end else		cnt	<= #2 cnt;

`ifdef __use_mfsr
MFSR_XX MFSR(
	.count_i(cnt),
	.count_o(cnt_inc_mfsr)
);
`endif

endmodule	// pctest
