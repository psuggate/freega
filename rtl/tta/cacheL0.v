/***************************************************************************
 *                                                                         *
 *   cacheL0.v - Simple, fast, low-latency cache designed to sit between a *
 *     CPU and a more conventional L1 cache.                               *
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

// TODO: A couple of cycles latency can be saved by issuing the FETCH earlier
// when in the WAIT state.
// TODO: Support a burst-fetch cancel command when a cache miss occurs before
// the current cache-line is completely loaded.

`timescale 1ns/100ps
module cacheL0 (
	clock_i,
	reset_ni,
	
	pc_i,
	hit_o,
	instr_o,
	
	fetch_o,	// Get a new cache-line from the L1 cache
	abort_o,
	invld_i,
	store_i,
	addr_i,
	data_i
);

parameter	DW	= 32;
parameter	AW	= 4;
parameter	DMSB	= DW - 1;
parameter	AMSB	= AW - 1;
parameter	MSIZE	= 16;

input	clock_i;
input	reset_ni;

input	[AMSB:0]	pc_i;
output	hit_o;
output	[DMSB:0]	instr_o;

output	fetch_o;
output	abort_o;
input	invld_i;
input	store_i;
input	[AMSB:0]	addr_i;
input	[DMSB:0]	data_i;


`define	C0ST_IDLE	4'b0000
`define	C0ST_FETCH	4'b0001
`define	C0ST_LOAD	4'b0010
`define	C0ST_RUN	4'b0100
`define	C0ST_ABORT	4'b1000
reg	[3:0]	state	= `C0ST_FETCH;

// Dual-port asynchronous-read memory.
reg	[DMSB:0]	amem [0:MSIZE-1];

wire	fetched, run_ok;


assign	#1 instr_o	= amem[pc_i];
assign	#2 hit_o	= (state == `C0ST_IDLE || state == `C0ST_RUN) && !invld_i;

assign	#1 fetched	= (addr_i == 4'hF && store_i);
assign	#1 run_ok	= (addr_i == pc_i && store_i);

assign	#1 fetch_o	= (state == `C0ST_FETCH);
// assign	#1 abort_o	= (state == `C0ST_ABORT);
assign	#1 abort_o	= (state == `C0ST_RUN) && invld_i;


always @(posedge clock_i) begin
	if (store_i)
		amem [addr_i]	<= #1 data_i;
end


// This state machine allows the CPU to resume once the needed data has been
// fetched. If a cache miss occurs again, the current operation is aborted
// and a new fetch is issued.
// TODO: Some more latency can be saved.
always @(posedge clock_i) begin
	if (!reset_ni)
		state	<= #1 `C0ST_IDLE;
	else case (state)
	
	`C0ST_IDLE:	if (invld_i)	state	<= #1 `C0ST_FETCH;
	
	`C0ST_FETCH:	begin
		if (run_ok)
			state	<= #1 `C0ST_RUN;
		else
			state	<= #1 `C0ST_LOAD;
	end
	
	`C0ST_LOAD:	begin
		if (fetched)
			state	<= #1 `C0ST_IDLE;
		else if (run_ok)
			state	<= #1 `C0ST_RUN;
	end
	
	`C0ST_RUN:	begin
		if (abort_o)
			state	<= #1 `C0ST_FETCH;
		else if (fetched)
			state	<= #1 `C0ST_IDLE;
	end
	
	`C0ST_ABORT:	state	<= #1 `C0ST_FETCH;
	
	endcase
end


endmodule	// cacheL0
