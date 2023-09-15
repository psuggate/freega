/***************************************************************************
 *                                                                         *
 *   th_branch.v - Typically the fourth stage of a pipelined TTA CPU. This *
 *     stage calculates the Program Counter (PC) and performs the cache    *
 *     tag lookup and update.                                              *
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

`define	__debug
`timescale 1ns/100ps
module th_branch (
	clock_i,
	reset_ni,
	enable_i,
	
	tr_pc_next_o,	// PC value stored for in a link reg. (for a CALL)
	
	de_lookup_i,
	de_nop_i,
	de_ack_o,
	de_bra_imm_i,
	de_bra_reg_i,
// 	de_pc_co,	// NOTE: Medium-length combinatorial path
// 	de_pc_next_i,
	de_pc_bra_i,
	
	// The second stage is called Instruction fetch Second like the
	// MIPS-R04K, hence the `is' prefix.
	if_lookup_o,
	if_ack_i,
	if_packed_i,
	if_hit_i,
	if_miss_i,
	if_pc_o,
	if_pre0_o,	// Pre-calc to reduce work next stage
	if_tag0_o,
	if_vld0_o,
	if_pre1_o,
	if_tag1_o,
	if_vld1_o,
	
	is_busy_i,
	is_update_i,
	is_newtag_i,
	is_lru_i,
	is_bank_i
);

parameter	PC_INIT		= 0;
parameter	INSTRUCTION	= 32;
parameter	ADDRESS		= 10;
parameter	DELAYSLOTS	= 2;

parameter	PC_INIT_NEXT	= PC_INIT + 1;
parameter	MSB	= INSTRUCTION - 1;
parameter	ASB	= ADDRESS - 1;
parameter	TSB	= ADDRESS - 4;

input		clock_i;
input		reset_ni;
input		enable_i;

output	[ASB:0]	tr_pc_next_o;

input		de_lookup_i;
input		de_nop_i;
output		de_ack_o;
input		de_bra_imm_i;
input		de_bra_reg_i;
input	[ASB:0]	de_pc_bra_i;

output		if_lookup_o;
input		if_ack_i;
input		if_packed_i;
input		if_hit_i;
input		if_miss_i;
output	[ASB:0]	if_pc_o;
output		if_pre0_o;
output	[TSB:0]	if_tag0_o;
output		if_vld0_o;
output		if_pre1_o;
output	[TSB:0]	if_tag1_o;
output		if_vld1_o;

input		is_busy_i;
input		is_update_i;
input	[TSB:0]	is_newtag_i;
input		is_lru_i;
input		is_bank_i;


reg	[TSB:0]	if_tag0_o;
reg	[TSB:0]	if_tag1_o;
reg		if_vld0_o	= 0;
reg		if_vld1_o	= 0;
reg		if_pre0_o	= 0;
reg		if_pre1_o	= 0;
reg		if_lookup_o	= 0;
reg	[ASB:0]	pc_r		= PC_INIT;

reg	[ASB:0]	pc_next	= PC_INIT_NEXT;	// FIXME: Won't always work with MFSR?
// reg	[ASB:0]	pc_next	= PC_INIT + 1;	// FIXME: Won't always work with MFSR?

reg	packed		= 0;
reg	fetched		= 0;
reg	recalc		= 0;

wire	[ASB:0]	pc;
wire	[ASB:0]	pc_next_w;
wire	hash;
wire	[TSB:0]	tag1, tag0;
wire	vld1, vld0;
wire	pre1, pre0;


assign	tr_pc_next_o	= pc_next;

assign	#2 de_ack_o	= !is_busy_i && de_lookup_i && enable_i;
assign	if_pc_o		= pc_r;

// TODO: Supports jumps to addresses stored in registers.
assign	#2 pc	= de_bra_imm_i ? de_pc_bra_i : pc_next ;
// assign	#2 pc	= if_ack_i ? pc_w : pc_r ;
// assign	hash	= pc_next_w [2];	// Simple 2-way cache tag bank calc.
assign	hash	= pc [2];	// FIXME: Simple 2-way cache tag bank calc.

assign	#2 pre0	= de_ack_o && (pc [ASB] == tag0 [TSB]) && vld0;
assign	#2 pre1	= de_ack_o && (pc [ASB] == tag1 [TSB]) && vld1;

/*
`define	FETCH_EMPTY	3'b001
`define	FETCH_ONE	3'b010
`define	FETCH_TWO	3'b100

reg	[2:0]	state	= `FETCH_EMPTY;
always @(posedge clock_i)
	if (!reset_ni)
		state	<= #2 `FETCH_EMPTY;
	else case (state)
	
	`FETCH_EMPTY:	if (if_ack_i)	state	<= #2 `FETCH_ONE;
	
	`FETCH_ONE: begin
		if (if_hit_i && if_packed_i)
	end
	
	`FETCH_TWO:	state	<= #2 `FETCH_ONE;
	
	endcase
*/


//---------------------------------------------------------------------------
// The goal is to only prefetch the minimum number of intructions that will
// not cause wait-states or bubbles. Prefetching more than this will require
// somewhere to place the extra instructions, or a dump with a refetch later
// on.
//
always @(posedge clock_i)
	if (!reset_ni)		packed	<= #2 0;
	else if (if_hit_i)	packed	<= #2 if_packed_i;

`define	UP	(if_ack_i && !if_hit_i)
`define	DOWN	(if_hit_i && !if_ack_i)
always @(posedge clock_i)
	if (!reset_ni)		fetched	<= #2 0;
	else if (`UP)		fetched	<= #2 1;
	else if (`DOWN)		fetched	<= #2 0;
	else if (is_update_i)	fetched	<= #2 0;

// TODO: Clean this up. This is UGLY!
always @(posedge clock_i)
	if (!reset_ni)			if_lookup_o	<= #2 1'b0;
	else if (recalc)		if_lookup_o	<= #2 1'b1;
	else if (if_ack_i && packed)	if_lookup_o	<= #2 0;
	else if (!fetched)		if_lookup_o	<= #2 1'b1;
// 	else if (fetched && if_ack_i && if_packed_i)	if_lookup_o	<= #2 0;
	else if (fetched && !if_packed_i)	if_lookup_o	<= #2 1'b1;
	else if (fetched && `DOWN)	if_lookup_o	<= #2 1;
	else				if_lookup_o	<= #2 1'b0;

always @(posedge clock_i)
	if (!reset_ni)	recalc	<= #2 1'b0;
	else		recalc	<= #2 is_update_i;


//---------------------------------------------------------------------------
// Perform tag lookup at the same time that the Program Counter (PC) is
// calculated so that the cache hit/miss calculation happens in one clock
// cycle. This is needed so:
//  - extra instruction prefetches can be avoided
//  - the prefetch buffer never underruns
//
/*
reg	wait_n	= 1;
always @(posedge clock_i)
	if (!reset_ni)	wait_n	<= #2 1;
	else		wait_n	<= #2 !((if_ack_i && packed) || (if_hit_i && if_packed_i));
*/
wire	#2 wait_n	= !(fetched && packed && !if_lookup_o);
always @(posedge clock_i)
	if (!reset_ni)	{if_vld1_o, if_vld0_o}	<= #2 0;
	else if (wait_n) begin
// 	else begin
		if_vld0_o	<= #2 vld0;
		if_vld1_o	<= #2 vld1;
		if_tag0_o	<= #2 tag0;
		if_tag1_o	<= #2 tag1;
	end

// Start cache hit/miss calculation earlier so that the next pipeline stage
// clocks faster.
// NOTE: Using these signals is optional.
always @(posedge clock_i)
	if (!reset_ni)	{if_pre1_o, if_pre0_o}	<= #2 0;
	else begin
		if_pre0_o	<= #2 pre0;
		if_pre1_o	<= #2 pre1;
	end

always @(posedge clock_i)
	if (!reset_ni)		pc_next	<= #2 PC_INIT_NEXT;
// 	else if (if_miss_i)	pc_next	<= #2 pc_next;
	else if (if_ack_i)	pc_next	<= #2 pc_next_w;

always @(posedge clock_i)
	if (!reset_ni)		pc_r	<= #2 PC_INIT;
// 	else if (if_miss_i)	pc_r	<= #2 pc_r;
	else if (if_ack_i)	pc_r	<= #2 pc;


// Hybrid PC using one of Roy's ultra-tricky MFSRs.
wire	[ASB-3:0]	pc_mfsr;
assign	#2 pc_next_w [2:0]	= pc + 1;
assign	#2 pc_next_w [ASB:3]	= (pc [2:0] == 3'b111) ? pc_mfsr : pc [ASB:3] ;

mfsr7 MFSR7 (
	.count_i	(pc [ASB:3]),
	.count_o	(pc_mfsr)
);


th_tags #(
	.TAGSIZE	(ADDRESS-3),
	.TAGNUM		(2)
) TAGS0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.update_i	(is_update_i),	// Update path
	.bank_i		(is_bank_i),
	.lru_i		(is_lru_i),
	.tag_i		(is_newtag_i),
	
	.hash_i		(hash),	// Lookup path
	.tag0_co	(tag0),
	.tag1_co	(tag1),
	.vld0_co	(vld0),
	.vld1_co	(vld1)
);


endmodule	// th_branch


module th_tags (
	clock_i,
	reset_ni,
	
	update_i,
	bank_i,
	lru_i,
	tag_i,
	
	hash_i,
	tag0_co,
	tag1_co,
	vld0_co,
	vld1_co
);

parameter	TAGSIZE		= 7;
parameter	TAGNUM		= 2;		// Tags/bank
parameter	TAGLOG2NUM	= 1;

parameter	TSB	= TAGSIZE - 1;
parameter	LSB	= TAGLOG2NUM - 1;

input		clock_i;
input		reset_ni;

input		update_i;
input		bank_i;
input	[LSB:0]	lru_i;
input	[TSB:0]	tag_i;

input		hash_i;
output	[TSB:0]	tag0_co;
output	[TSB:0]	tag1_co;
output		vld0_co;
output		vld1_co;


reg	[TSB:0]	tags0	[TAGNUM-1:0];
reg	[TSB:0]	tags1	[TAGNUM-1:0];
reg		vlds0	[TAGNUM-1:0];
reg		vlds1	[TAGNUM-1:0];


assign	#2 tag0_co	= tags0 [hash_i];
assign	#2 tag1_co	= tags1 [hash_i];
assign	#2 vld0_co	= vlds0 [hash_i];
assign	#2 vld1_co	= vlds1 [hash_i];


// Update tags depending on LRU and odd/even cache-line.
always @(posedge clock_i)
	if (update_i && !lru_i)	tags0 [bank_i]	<= #2 tag_i;

always @(posedge clock_i)
	if (update_i && lru_i)	tags1 [bank_i]	<= #2 tag_i;

// Mark as valid once entire line is fetched.
always @(posedge clock_i)
	if (!reset_ni)			vlds0 [bank_i]	<= #2 1'b0;
	else if (update_i && !lru_i)	vlds0 [bank_i]	<= #2 1'b1;

always @(posedge clock_i)
	if (!reset_ni)			vlds1 [bank_i]	<= #2 1'b0;
	else if (update_i && lru_i)	vlds1 [bank_i]	<= #2 1'b1;


endmodule	// th_tags
