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
	br_ack_o,
	br_branch_i,
	br_pc_co,	// NOTE: Medium-length combinatorial path
	br_pc_next_i,
	br_pc_bra_i,
	
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
parameter	MEMSIZE		= 16;
parameter	DELAYSLOTS	= 2;

parameter	MSB	= INSTRUCTION - 1;
parameter	ASB	= ADDRESS - 1;
parameter	TSB	= ADDRESS - 4;

input		clock_i;
input		reset_ni;
input		enable_i;

input		if_ack_i;
output		if_busy_o;
output		if_update_o;
output	[TSB:0]	if_newtag_o;
output		if_lru_no;
output		if_bank_o;

input		is_lookup_i;
input	[ASB:0]	is_pc_i;
input		is_pre0_i;
input	[TSB:0]	is_tag0_i;
input		is_vld0_i;
input		is_pre1_i;
input	[TSB:0]	is_tag1_i;
input		is_vld1_i;

input		rf_branch_i;
output	[ASB:0]	if_pc_co;
input	[ASB:0]	if_pc_next_i;
input	[ASB:0]	if_pc_bra_i;

output		is_lookup_o;


reg	[MSB:0]	mem	[MEMSIZE-1:0];

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


endmodule	// th_first


module th_mfetch (
	clock_i,
	reset_ni,
	
	miss_i,
	bank_i,
	addr_i,
	lru_i,
	done_o,
	busy_no,
	update_o,
	
	m_read_o,
	m_rack_i,
	m_ready_i,
	m_addr_o,
	m_data_i,
	
	c_write_o,	// Write to the cache
	c_addr_o,
	c_data_o
);

parameter	WIDTH		= 32;
parameter	ADDRESS		= 10;
parameter	CSIZEBITS	= 1;	// cache-lines/bank = 2^CSIZEBITS
parameter	ASSOCBITS	= 1;	// set-associativity = 2^ASSOCBITS
parameter	LINEBITS	= 2;	// linesize = 2^LINEBITS

parameter	MSB		= WIDTH - 1;
parameter	ASB		= ADDRESS - 1;
parameter	LSB		= LINEBITS - 1;
parameter	CSB		= CSIZEBITS + ASSOCBITS + LINEBITS - 1;
parameter	RSB		= ASSOCBITS - 1;	// Replacement locations
parameter	BSB		= CSIZEBITS - 1;

input		clock_i;
input		reset_ni;

input		miss_i;
input	[BSB:0]	bank_i;
input	[ASB:0]	addr_i;
input	[RSB:0]	lru_i;	// Last Recently Used (or whatever suits ya fancy)
output		done_o;
output		busy_no;
output		update_o;	// Update tags

output		m_read_o;
input		m_rack_i;
input		m_ready_i;
output	[ASB:0]	m_addr_o;
input	[MSB:0]	m_data_i;

output		c_write_o;
output	[CSB:0]	c_addr_o;
output	[MSB:0]	c_data_o;


reg	[ASB-2:0]	addr;

reg		done_o	= 0;
reg		update_o	= 0;
reg		m_read_o	= 0;
reg	[LSB:0]	rd_cnt	= 0;
reg	[LSB:0]	wr_cnt	= 0;
reg		fetch	= 0;
reg		done	= 1;
reg	[RSB:0]	lru;
reg	[BSB:0]	bank;

wire	rdone, wdone;


// assign	#2 done_o	= fetch && done;
// assign	update_o	= wdone;
assign	busy_no		= done;

assign	m_addr_o	= {addr, rd_cnt};

assign	c_write_o	= m_ready_i;
assign	c_addr_o	= {lru, bank, wr_cnt};
assign	c_data_o	= m_data_i;

assign	#2 rdone	= (rd_cnt == {LINEBITS{1'b1}}) && m_rack_i;
assign	#2 wdone	= (wr_cnt == {LINEBITS{1'b1}}) && c_write_o;


// Fetch state.
always @(posedge clock_i)
	if (!reset_ni)			fetch	<= #2 0;
	else if (miss_i && done)	fetch	<= #2 1;
	else if (rdone)			fetch	<= #2 0;

always @(posedge clock_i)
	if (miss_i && done)	addr	<= #2 addr_i [ASB:2];

always @(posedge clock_i)
	if (!reset_ni)			m_read_o	<= #2 0;
	else if (miss_i && done)	m_read_o	<= #2 1;
	else if (rdone)			m_read_o	<= #2 0;

always @(posedge clock_i)
	if (!reset_ni)	rd_cnt	<= #2 0;
	else		rd_cnt	<= #2 rd_cnt + m_rack_i;

always @(posedge clock_i)
	if (!reset_ni)	wr_cnt	<= #2 0;
	else		wr_cnt	<= #2 wr_cnt + c_write_o;

always @(posedge clock_i)
	if (!reset_ni)		done	<= #2 1;
	else if (wdone)		done	<= #2 1;
	else if (miss_i)	done	<= #2 0;

always @(posedge clock_i)
	if (miss_i && done)	{bank, lru}	<= #2 {bank_i, lru_i};


always @(posedge clock_i)
	if (!reset_ni)	done_o	<= #2 0;
	else		done_o	<= #2 wdone;

always @(posedge clock_i)
	if (!reset_ni)	update_o	<= #2 0;
	else		update_o	<= #2 rdone;


endmodule	// th_mfetch
