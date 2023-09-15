/***************************************************************************
 *                                                                         *
 *   th_first.v - First pipeline stage, a cache hit/miss calculation.      *
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
module th_first (
	clock_i,
	reset_ni,
	enable_i,
	
	br_lookup_i,
	br_pc_i,
	br_ack_o,
	br_busy_o,
	br_vld0_i,
	br_tag0_i,
	br_pre0_i,
	br_vld1_i,
	br_tag1_i,
	br_pre1_i,
/*	br_update_o,
	br_newtag_o,
	br_lru_no,
	br_bank_o,
	*/
	// The second stage is called Instruction fetch Second like the
	// MIPS-R04K, hence the `is' prefix.
	is_lookup_o,
	is_ack_i,
	is_l_addr_o,
	is_packed_o,
	is_busy_i,
	is_pc_o,
	is_hit_o,
	is_miss_o,
	is_hit_co,	// These two have large combinatorial components
	is_miss_co,
	is_update_i,
	is_u_addr_i,
	is_packed_i
);

parameter	ADDRESS		= 10;
parameter	MEMSIZE		= 16;
parameter	MEMSIZELOG2	= 4;
parameter	BANKSLOG2	= 1;

parameter	ASB	= ADDRESS - 1;
parameter	TSB	= ADDRESS - 4;
parameter	LSB	= MEMSIZELOG2 - 1;
parameter	BSB	= BANKSLOG2 - 1;

input		clock_i;
input		reset_ni;
input		enable_i;

input		br_lookup_i;
input	[ASB:0]	br_pc_i;
output		br_ack_o;
output		br_busy_o;
input		br_vld0_i;
input	[TSB:0]	br_tag0_i;
input		br_pre0_i;	// TODO
input		br_vld1_i;
input	[TSB:0]	br_tag1_i;
input		br_pre1_i;	// TODO
/*
output		br_update_o;
output	[TSB:0]	br_newtag_o;
output		br_lru_no;
output	[BSB:0]	br_bank_o;
*/

output		is_lookup_o;	// Lookup path
input		is_ack_i;
output	[LSB:0]	is_l_addr_o;
output		is_packed_o;
input		is_busy_i;	// TODO
output	[ASB:0]	is_pc_o;
output		is_hit_o;
output		is_miss_o;
output		is_hit_co;
output		is_miss_co;
input		is_update_i;	// Update path
input	[LSB:0]	is_u_addr_i;
input		is_packed_i;


reg	packs	[MEMSIZE-1:0];

reg		is_lookup_o	= 0;
reg	[LSB:0]	is_l_addr_o	= 0;
reg		is_packed_o	= 0;
reg		is_hit_o	= 0;
reg		is_miss_o	= 0;
reg	[ASB:0]	is_pc_o		= 0;

wire	[TSB:0]	taddr	= br_pc_i [ASB:2+BANKSLOG2];
wire	[LSB:0]	l_addr_w;
wire	hit_w, miss_w, m1, m0;
wire	packed_w;


assign	#2 br_ack_o	= br_lookup_i && !is_miss_o && !is_busy_i;	// TODO
assign	br_busy_o	= is_busy_i;

assign	is_hit_co	= hit_w;
assign	is_miss_co	= miss_w;

assign	#2 m0	= (br_tag0_i == br_pc_i [ASB:3]) && br_vld0_i;
assign	#2 m1	= (br_tag1_i == br_pc_i [ASB:3]) && br_vld1_i;

assign	#2 hit_w	=  (m1 || m0) && br_lookup_i;
assign	#2 miss_w	= !(m1 || m0) && br_lookup_i;

assign	l_addr_w	= {m1, br_pc_i [1+BANKSLOG2:0]};
assign	packed_w	= packs [l_addr_w];


always @(posedge clock_i)
	if (!reset_ni)	is_lookup_o	<= #2 0;
	else		is_lookup_o	<= #2 br_ack_o;
/*	else if (br_lookup_i && !is_busy_i)	is_lookup_o	<= #2 1;
	else if (!br_lookup_i && is_ack_i)	is_lookup_o	<= #2 0;
*/

always @(posedge clock_i)
	if (br_lookup_i)	is_pc_o	<= #2 br_pc_i;

always @(posedge clock_i)
	if (br_lookup_i)	is_packed_o	<= #2 packed_w;

always @(posedge clock_i)
	if (br_lookup_i && !is_busy_i)	is_l_addr_o	<= #2 l_addr_w;

always @(posedge clock_i)
	if (!reset_ni)	{is_miss_o, is_hit_o}	<= #2 0;
// 	else if (br_lookup_i) begin
	else if (br_ack_o) begin
		is_hit_o	<= #2 hit_w;
		is_miss_o	<= #2 miss_w;
	end else
		{is_miss_o, is_hit_o}	<= #2 0;


// Update the packed instruction flags memory.
always @(posedge clock_i)
	if (is_update_i)	packs [is_u_addr_i]	<= #2 is_packed_i;


endmodule	// th_first
