/***************************************************************************
 *                                                                         *
 *   th_second.v - Second pipeline stage, a cache memory lookup.           *
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
module th_second (
	clock_i,
	reset_ni,
	enable_i,
	
	m_read_o,
	m_rack_i,
	m_ready_i,
	m_addr_o,
	m_data_i,
	
	if_lookup_i,
	if_l_addr_i,
	if_packed_i,
	if_ack_o,
	if_hit_i,
	if_miss_i,
	if_pc_i,
	if_busy_o,
	if_update_o,
	if_u_addr_o,
	if_packed_o,
	
	br_update_o,
	br_newtag_o,
	br_lru_o,
	br_bank_o,
	
	de_instr_o,
	de_packed_o,
	de_valid_o,
	de_nop_o
);

parameter	PC_INIT		= 0;
parameter	INSTRUCTION	= 32;
parameter	ADDRESS		= 10;
parameter	MEMSIZE		= 16;
parameter	MEMSIZELOG2	= 4;
parameter	DELAYSLOTS	= 2;

parameter	MSB	= INSTRUCTION - 1;
parameter	ISB	= INSTRUCTION - 2;
parameter	ASB	= ADDRESS - 1;
parameter	TSB	= ADDRESS - 4;
parameter	USB	= MEMSIZELOG2 - 1;

input		clock_i;
input		reset_ni;
input		enable_i;

output		m_read_o;
input		m_rack_i;
input		m_ready_i;
output	[ASB:0]	m_addr_o;
input	[MSB:0]	m_data_i;

input		if_lookup_i;
input	[3:0]	if_l_addr_i;
input		if_packed_i;
output		if_ack_o;
input		if_hit_i;
input		if_miss_i;
input	[ASB:0]	if_pc_i;
output		if_busy_o;
output		if_update_o;
output	[USB:0]	if_u_addr_o;
output		if_packed_o;

output		br_update_o;
output	[TSB:0]	br_newtag_o;
output		br_lru_o;
output		br_bank_o;

output	[ISB:0]	de_instr_o;
output		de_packed_o;
output		de_valid_o;
output		de_nop_o;


reg	[MSB:0]	mem	[MEMSIZE-1:0];

// reg		if_busy_o	= 0;

reg	[ISB:0]	de_instr_o;
reg		de_packed_o;
reg		de_nop_o	= 1'b1;

reg		br_update_o	= 0;
reg		br_bank_o	= 0;
reg	[TSB:0]	br_newtag_o;

reg		next_packed	= 0;

wire	[MSB:0]	instr_w;

wire	bank, busy_n, done, lru, update;

wire		u_write;
wire	[USB:0]	u_addr;
wire	[MSB:0]	u_data;


assign	#2 if_ack_o	= if_lookup_i && !if_busy_o;
assign	#2 if_busy_o	= (if_miss_i || !busy_n);
assign	if_update_o	= u_write;
assign	if_u_addr_o	= u_addr;
assign	if_packed_o	= u_data [31];

assign	br_lru_o	= u_addr [3];

assign	de_valid_o	= ~de_nop_o;

assign	instr_w		= mem [if_l_addr_i];
assign	bank		= if_pc_i [2];


// Cache update logic.
always @(posedge clock_i)
	if (u_write)	mem [u_addr]	<= #2 u_data;

always @(posedge clock_i)
	if (done)	{next_packed, de_instr_o}	<= #2 mem [u_addr];
	else		{next_packed, de_instr_o}	<= #2 mem [if_l_addr_i];

always @(posedge clock_i)
	if (!reset_ni)		de_packed_o	<= #2 0;
	else if (de_valid_o)	de_packed_o	<= #2 next_packed;

always @(posedge clock_i)
	if (!reset_ni)		de_nop_o	<= #2 1'b1;
	else if (busy_n)	de_nop_o	<= #2 !(if_hit_i || done);
// 	else if (busy_n)	de_nop_o	<= #2 !(if_lookup_i || done);
	else			de_nop_o	<= #2 1'b1;


wire	#2 b_up	= busy_n && if_miss_i;
always @(posedge clock_i)
	if (!reset_ni)		br_bank_o	<= #2 ~br_bank_o;
	else if (b_up)	br_bank_o	<= #2 if_pc_i [2];

always @(posedge clock_i)
// 	br_update_o	<= #2 done;	// TODO Too slow
	br_update_o	<= #2 b_up;

always @(posedge clock_i)
	if (b_up)	br_newtag_o	<= #2 if_pc_i [ASB:3];

/*
always @(posedge clock_i)
	if (!reset_ni)	if_busy_o	<= #2 0;
	else		if_busy_o	<= #2 (if_miss_i || !busy_n);
*/

th_memfetch #(
	.WIDTH		(32),
	.ADDRESS	(10),
	.CSIZEBITS	(1),	// cache-lines/bank = 2^CSIZEBITS
	.ASSOCBITS	(1),	// set-associativity = 2^ASSOCBITS
	.LINEBITS	(2)	// linesize = 2^LINEBITS
) MFETCH0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.miss_i		(if_miss_i),
	.bank_i		(bank),
	.addr_i		(if_pc_i),
	.lru_i		(lru),
	.done_o		(done),
	.busy_no	(busy_n),
	.update_o	(update),
	
	.m_read_o	(m_read_o),
	.m_rack_i	(m_rack_i),
	.m_ready_i	(m_ready_i),
	.m_addr_o	(m_addr_o),
	.m_data_i	(m_data_i),
	
	.c_write_o	(u_write),	// Write to the cache
	.c_addr_o	(u_addr),
	.c_data_o	(u_data)
);


// Calculates the Least Recently Used cacheline which is then replaced upon a
// miss.
th_lru #(
	.INIT		(1),
	.ASSOCBITS	(1),	// associativity = 2^ASSOCBITS
	.ADDRESS	(10)
) LRU0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.hit_i		(if_hit_i),
	.miss_i		(if_miss_i),
	.bank_i		(0),
	.addr_i		(0),
	.lru_o		(lru)
);


endmodule	// th_second


module th_memfetch (
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


endmodule	// th_memfetch


// Determines the cache-line to retire scientifically (randomly).
module th_lru (
	clock_i,
	reset_ni,
	hit_i,
	miss_i,
	bank_i,
	addr_i,
	lru_o
);

parameter	INIT		= 1;
parameter	ASSOCBITS	= 1;	// associativity = 2^ASSOCBITS
parameter	ADDRESS		= 10;
parameter	ASB		= ADDRESS - 1;

input		clock_i;
input		reset_ni;
input		hit_i;
input		miss_i;
input		bank_i;
input	[ASB:0]	addr_i;
output		lru_o;

reg	[7:0]	rnd	= INIT;
wire	[7:0]	next;

assign	lru_o	= rnd [ASSOCBITS:1];

always @(posedge clock_i)
	if (!reset_ni)		rnd	<= #2 INIT;
	else if (miss_i)	rnd	<= #2 next;

mfsr8 MFSR8 (
	.count_i	(rnd),
	.count_o	(next)
);

endmodule	// th_lru
