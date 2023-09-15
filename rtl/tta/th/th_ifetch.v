/***************************************************************************
 *                                                                         *
 *   th_ifetch.v - Typically the first stage of a pipelined CPU is a fetch *
 *     unit. This stage performs cache lookup and update and keeps track   *
 *     of the Program Counter (PC).                                        *
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
module th_ifetch (
	clock_i,
	reset_ni,
	enable_i,
	
	if_lookup_i,
	if_ack_o,
	if_branch_i,
	if_pc_co,	// NOTE: Medium-length combinatorial path
	if_pc_next_i,
	if_pc_bra_i,
	
	// The second stage is called Instruction fetch Second like the
	// MIPS-R04K, hence the `is' prefix.
	is_lookup_o,
	is_pc_o,
	is_pre0_o,	// Pre-calc to reduce work next stage
	is_tag0_o,
	is_vld0_o,
	is_pre1_o,
	is_tag1_o,
	is_vld1_o,
	is_busy_i,
	is_update_i,
	is_newtag_i,
	is_lru_ni,
	is_bank_i
);

parameter	PC_INIT		= 0;
parameter	INSTRUCTION	= 32;
parameter	ADDRESS		= 10;
parameter	DELAYSLOTS	= 2;

parameter	MSB	= INSTRUCTION - 1;
parameter	ASB	= ADDRESS - 1;
parameter	TSB	= ADDRESS - 4;

input		clock_i;
input		reset_ni;
input		enable_i;

input		if_lookup_i;
output		if_ack_o;
input		if_branch_i;
output	[ASB:0]	if_pc_co;
input	[ASB:0]	if_pc_next_i;
input	[ASB:0]	if_pc_bra_i;

output		is_lookup_o;
output	[ASB:0]	is_pc_o;
output		is_pre0_o;
output	[TSB:0]	is_tag0_o;
output		is_vld0_o;
output		is_pre1_o;
output	[TSB:0]	is_tag1_o;
output		is_vld1_o;
input		is_busy_i;
input		is_update_i;
input	[TSB:0]	is_newtag_i;
input		is_lru_ni;
input		is_bank_i;


reg	[TSB:0]	is_tag0_o;
reg	[TSB:0]	is_tag1_o;
reg	is_vld0_o	= 0;
reg	is_vld1_o	= 0;
reg	is_pre0_o	= 0;
reg	is_pre1_o	= 0;
reg	is_lookup_o	= 0;
reg	[ASB:0]	is_pc_o	= PC_INIT;

wire	[ASB:0]	pc;
wire	hash;
wire	[TSB:0]	tag1, tag0;
wire	vld1, vld0;
wire	pre1, pre0;


assign	#2 if_ack_o	= !is_busy_i && if_lookup_i && enable_i;
assign	if_pc_co	= pc;

assign	#2 pc	= if_branch_i ? if_pc_bra_i : if_pc_next_i ;
assign	hash	= pc [2];	// Simple 2-way cache tag bank calc.

assign	#2 pre0	= if_ack_o && (pc [ASB] == tag0 [TSB]) && vld0;
assign	#2 pre1	= if_ack_o && (pc [ASB] == tag1 [TSB]) && vld1;


always @(posedge clock_i)
	if (!reset_ni)	is_lookup_o	<= #2 0;
	else		is_lookup_o	<= #2 if_ack_o;

always @(posedge clock_i)
	if (!reset_ni)		is_pc_o	<= #2 PC_INIT;
	else if (if_ack_o)	is_pc_o	<= #2 pc;

always @(posedge clock_i)
	if (!reset_ni)	{is_vld1_o, is_vld0_o}	<= #2 0;
	else begin
		is_vld0_o	<= #2 vld0;
		is_vld1_o	<= #2 vld1;
		is_tag0_o	<= #2 tag0;
		is_tag1_o	<= #2 tag1;
	end

always @(posedge clock_i)
	if (!reset_ni)	{is_pre1_o, is_pre0_o}	<= #2 0;
	else begin
		is_pre0_o	<= #2 pre0;
		is_pre1_o	<= #2 pre1;
	end


th_tags #(
	.TAGSIZE	(ADDRESS-3),
	.TAGNUM		(2)
) TAGS0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.update_i	(is_update_i),	// Update path
	.bank_i		(is_bank_i),
	.lru_ni		(is_lru_ni),
	.tag_i		(is_newtag_i),
	
	.hash_i		(hash),	// Lookup path
	.tag0_o		(tag0),
	.tag1_o		(tag1),
	.vld0_o		(vld0),
	.vld1_o		(vld1)
);


endmodule	// th_ifetch


module th_tags (
	clock_i,
	reset_ni,
	
	update_i,
	bank_i,
	lru_ni,
	tag_i,
	
	hash_i,
	tag0_o,
	tag1_o,
	vld0_o,
	vld1_o
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
input	[LSB:0]	lru_ni;
input	[TSB:0]	tag_i;

input		hash_i;
output	[TSB:0]	tag0_o;
output	[TSB:0]	tag1_o;
output		vld0_o;
output		vld1_o;


reg	[TSB:0]	tags0	[TAGNUM-1:0];
reg	[TSB:0]	tags1	[TAGNUM-1:0];
reg		vlds0	[TAGNUM-1:0];
reg		vlds1	[TAGNUM-1:0];


assign	#2 tag0_o	= tags0 [hash_i];
assign	#2 tag1_o	= tags1 [hash_i];
assign	#2 vld0_o	= vlds0 [hash_i];
assign	#2 vld1_o	= vlds1 [hash_i];


// Update tags depending on LRU and odd/even cache-line.
always @(posedge clock_i)
	if (update_i && !lru_ni)	tags0 [bank_i]	<= #2 tag_i;

always @(posedge clock_i)
	if (update_i && lru_ni)		tags1 [bank_i]	<= #2 tag_i;

// Mark as valid once entire line is fetched.
always @(posedge clock_i)
	if (!reset_ni)			vlds0 [bank_i]	<= #2 1'b0;
	else if (update_i && !lru_ni)	vlds0 [bank_i]	<= #2 1'b1;

always @(posedge clock_i)
	if (!reset_ni)			vlds1 [bank_i]	<= #2 1'b0;
	else if (update_i && lru_ni)	vlds1 [bank_i]	<= #2 1'b1;


endmodule	// th_tags
