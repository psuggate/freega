/***************************************************************************
 *                                                                         *
 *   tta_pc.v - Controls the stalling, branching and incrementing of the   *
 *     program counter (PC).                                               *
 *                                                                         *
 *     This design of TTA module is optimised for latency, not frequency.  *
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

`timescale 1ns/100ps
module tta_pc (
	clock_i,
	reset_ni,
	enable_i,
	
	pc_o,
	pc_i,
	fetch_o,
	latch_o,
	ack_i,
	hit_i,
	
	branch_i,
	memop_i,
	mbusy_i,	// Components that can stall the pipeline.
	
	stall_no
);

parameter	WIDTH	= 18;
parameter	INIT	= 0;
parameter	MSB	= WIDTH - 1;

input		clock_i;
input		reset_ni;
input		enable_i;	// FIXME

output	[MSB:0]	pc_o;
input	[MSB:0]	pc_i;
output		fetch_o;
output		latch_o;
input		ack_i;
input		hit_i;

input		branch_i;
input		memop_i;	// Gives some warning of memory commands
input		mbusy_i;

// input		stall_ni;
output		stall_no;


wire	#2 mem_stall	= (mbusy_i && memop_i);
reg	[MSB:0]	pc_o	= INIT;

`define	PCST_FETCH	2'b00
`define	PCST_MISS	2'b01
`define	PCST_STALL	2'b10
reg	[1:0]	state	= `PCST_FETCH;


assign	#2 stall_no	= (state == `PCST_FETCH);
assign	#2 fetch_o	= (state != `PCST_STALL);
// assign	#2 latch_o	= (state == `PCST_FETCH) || (state == `PCST_MISS && hit_i);
assign	latch_o		= ack_i;


always @(posedge clock_i)
	if (!reset_ni)
		state	<= #2 `PCST_FETCH;
	else case (state)
	
	`PCST_FETCH: begin
		if (!ack_i)		state	<= #2 `PCST_MISS;
		else if (mem_stall)	state	<= #2 `PCST_STALL;
		else			state	<= #2 state;
	end
	
	`PCST_MISS: begin
		if (mem_stall)	state	<= #2 `PCST_MISS;
		else if (hit_i)	state	<= #2 `PCST_FETCH;
		else		state	<= #2 state;
	end
	
	`PCST_STALL: begin
		if (!mem_stall)	state	<= #2 `PCST_FETCH;
		else		state	<= #2 state;
	end
	
	endcase


always @(posedge clock_i)
	if (!reset_ni)
		pc_o	<= #2 INIT;
	else case (state)
	`PCST_FETCH, `PCST_MISS: if (ack_i) begin
		if (branch_i)	pc_o	<= #2 pc_i;
		else		pc_o	<= #2 pc_o + 1;
	end else
		pc_o	<= #2 pc_o;
	
	`PCST_STALL:	pc_o	<= #2 pc_o;
	
	endcase


endmodule	// tta_pc
