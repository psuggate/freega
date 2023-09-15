/***************************************************************************
 *                                                                         *
 *   ucache.v - A tiny, two-cacheline-sized, read-only cache.              *
 *                                                                         *
 *     This design of TTA is optimised for latency, not frequency.         *
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
module ucache (
	clock_i,
	reset_ni,	// Also invalidate
	
	m_read_i,	// From Master
	m_flush_i,
	m_rack_o,
	m_ready_o,
	m_addr_i,
	m_data_o,
	
	s_read_o,	// To Slave
	s_rack_i,
	s_ready_i,
	s_addr_o,
	s_data_i
);

parameter	WIDTH	= 32;
parameter	ADDRESS	= 10;

parameter	MSB	= (WIDTH-1);
parameter	ASB	= (ADDRESS-1);
parameter	TSB	= (ADDRESS-4);

input		clock_i;
input		reset_ni;

input		m_read_i;
input		m_flush_i;	// Clear queued up address (upon branch)
output		m_rack_o;
output		m_ready_o;
input	[ASB:0]	m_addr_i;
output	[MSB:0]	m_data_o;

output		s_read_o;
input		s_rack_i;
input		s_ready_i;
output	[ASB:0]	s_addr_o;
input	[MSB:0]	s_data_i;


reg	[MSB:0]	mem [15:0];
reg	[TSB:0]	tag0, tag1;

reg		s_read_o	= 0;
reg	[ASB:0]	s_addr_o;

// Invalidate cache contents upon reset.
reg	[7:0]	vld0	= 0;
reg	[7:0]	vld1	= 0;
reg	[7:0]	loaded	= 0;

reg	s1_stall	= 0;
reg	s2_stall	= 0;


//---------------------------------------------------------------------------
//  Pipelined Cache.
//

// Stage I: Register address and perform tag comparison.
reg		m0_r, m1_r;
reg	[ASB:0]	addr1;
reg		read1	= 0;

wire	[TSB:0]	taddr	= m_addr_i [ASB:3];
wire		m0, m1;

assign	#2 m0	= (tag0 == taddr);
assign	#2 m1	= (tag1 == taddr);
assign	#2 m_rack_o	= m_read_i && !s2_stall;

always @(posedge clock_i)
	if (!reset_ni) begin
		s1_stall	<= #2 0;
		read1		<= #2 0;
		m0_r		<= #2 0;
		m1_r		<= #2 1;
	end else begin
		s1_stall	<= #2 s2_stall;
		if (ready) begin
			read1	<= #2 m_read_i;
			m0_r	<= #2 m0;
			m1_r	<= #2 m1;
			addr1	<= #2 m_addr_i;
		end else if (!s2_stall) begin
			read1	<= #2 m_read_i;
			m0_r	<= #2 m0;
			m1_r	<= #2 m1;
			addr1	<= #2 m_addr_i;
		end
// 		if (!s1_stall)
	end



// Stage II: Calculate HIT/MISS and cache lookup address. Upon a miss, cause
//  a pipeline stall.
reg	hit_r	= 0;
reg	miss_r	= 0;
reg	[3:0]	l_addr;	// Cache memory lookup address
reg	ready	= 0;
reg	[ASB:0]	addr2;

// wire	n0, n1;
// assign	#2 n0	= (

wire	match, hit, miss;

assign	#2 match	= (m0_r && vld0 [addr1 [2:0]]) || (m1_r && vld1 [addr1 [2:0]]);
assign	#2 hit	=  match && read1;
assign	#2 miss	= !match && read1;

always @(posedge clock_i)
	if (!reset_ni) begin
		s2_stall	<= #2 0;
		hit_r		<= #2 0;
		miss_r		<= #2 0;
		ready		<= #2 0;
	end else begin
		s2_stall	<= #2 miss && !first;
		
		// Prevent a lookup or a fetch upon FLUSH.
		hit_r		<= #2 (hit && !m_flush_i);
		miss_r		<= #2 (miss || m_flush_i);
		
		if (!m_flush_i)	ready		<= #2 hit || first;
		else		ready		<= #2 0;
		
		if (!m_flush_i && !s2_stall && read1) begin
			if (miss)	l_addr	<= #2 {oldest, addr1 [2:0]};
			else		l_addr	<= #2 {m1_r, addr1 [2:0]};
		end
		
		if (!s2_stall)
			addr2		<= #2 addr1;
	end


//  Stage III: Output data upon HIT.
assign	#2 m_data_o	= mem [l_addr [3:0]];
assign	m_ready_o	= ready;


//---------------------------------------------------------------------------
//  Update Logic:
//   Part of stage III.
//
reg	oldest	= 0;	// Replace this cache-line first
reg	fetch	= 0;
reg	[3:0]	u_addr	= 0;	// Cache memory update address
reg	[2:0]	fcnt	= 0;
wire	fdone;

assign	#2 fdone	= s_ready_i && (fcnt == 7);
assign	#2 first	= (fcnt == 0) && s_ready_i;

always @(posedge clock_i)
	if (!reset_ni)			fetch	<= #2 0;
	else if (miss_r)		fetch	<= #2 1;
	else if (fdone && !miss_r)	fetch	<= #2 0;

always @(posedge clock_i)
	if (!reset_ni)		s_read_o	<= #2 0;
	else if (s_rack_i)	s_read_o	<= #2 0;
	else if ((miss_r && !fetch) || (miss_r && fdone)) begin
		s_read_o	<= #2 1;
		s_addr_o	<= #2 addr2;	// FIXME
	end

always @(posedge clock_i)
	if (!reset_ni) begin
		vld0 [u_addr [2:0]]	<= #2 0;
		vld1 [u_addr [2:0]]	<= #2 0;
		u_addr [2:0]		<= #2 u_addr [2:0] + 1;
	end else begin
		if (miss_r && !fetch)
			u_addr		<= #2 {oldest, addr2 [2:0]};	// FIXME
		else if (miss_r && fdone)
			u_addr		<= #2 {~oldest, addr2 [2:0]};	// FIXME
		else if (s_ready_i)
			u_addr [2:0]	<= #2 u_addr [2:0] + 1;
		
		// 16 flip-flops. Bit of a waste?
		if (oldest) begin
			if (miss_r)	vld1	<= #2 0;
			else if (s_ready_i && oldest)
				vld1 [u_addr [2:0]]	<= #2 1;
		end else begin
			if (miss_r)	vld0	<= #2 0;
			else if (s_ready_i && oldest)
				vld0 [u_addr [2:0]]	<= #2 1;
		end
	end

// Update the cache memory.
always @(posedge clock_i)
	if (s_ready_i)	mem [u_addr]	<= #2 s_data_i;

// Increment the fetch counter when a READY is received.
always @(posedge clock_i)
	if (!reset_ni)		fcnt	<= #2 0;
	else if (s_ready_i)	fcnt	<= #2 fcnt + 1;

// Update pointer to oldest tag.
always @(posedge clock_i)
	if (!reset_ni)	oldest	<= #2 0;
	else if (fdone)	oldest	<= #2 ~oldest;

// Update tags.
always @(posedge clock_i)
	if (!fetch && miss_r) begin
		if (!oldest)	tag0	<= #2 addr2 [ASB:3];
		else		tag1	<= #2 addr2 [ASB:3];
	end else if (miss_r && fdone) begin
		if (oldest)	tag0	<= #2 addr2 [ASB:3];
		else		tag1	<= #2 addr2 [ASB:3];
	end

/*
reg	pending	= 0;
reg	ready	= 0;

reg	[ASB:0]	addr2;

wire	first, fdone;

*/

/*
reg	[MSB:0]	mem [15:0];
reg	[TSB:0]	tag0, tag1;
reg	[7:0]	loaded	= 0;

reg	s_read_o	= 0;

// Invalidate cache contents upon reset.
reg	vld0	= 0;
reg	vld1	= 0;

reg	oldest	= 0;	// Replace this cache-line first
reg	pending	= 0;
reg	ready	= 0;

reg	[3:0]	l_addr;	// Cache memory lookup address
reg	[3:0]	u_addr	= 0;	// Cache memory update address
reg	[ASB:0]	addr;
reg	[2:0]	fcnt	= 0;

wire	first, fdone;
reg	read_r	= 0;

`define	UCST_IDLE	2'b00
`define	UCST_FETCH	2'b01
`define	UCST_UPDATE	2'b10
`define	UCST_WAIT	2'b11
reg	[1:0]	state	= `UCST_IDLE;


assign	#2 m_rack_o	= m_read_i && (state == `UCST_IDLE || ready);
assign	#2 m_ready_o	= (hit && read_r && state == `UCST_IDLE) || ready;
assign	#2 m_data_o	= mem [l_addr];

assign	s_addr_o	= addr;


assign	#2 first	= (fcnt == 0) && s_ready_i;
assign	#2 fdone	= s_ready_i && (fcnt == 7);
assign	#2 update	= s_read_o;


// State machine. Idle until a miss, then fetch a new cache-line. Once the
// cache-line starts arriving, start outputting any cached data that at the
// requested addresses. If the address changes to something so that neither
// tag matches, wait until the cache-line retrieval has finished, then fetch
// the new cache-line.
always @(posedge clock_i)
	if (!reset_ni)
		state	<= #2 `UCST_IDLE;
	else case (state)
	
	`UCST_IDLE: begin
		if (!hit && read_r)	state	<= #2 `UCST_FETCH;
	end
	
	`UCST_FETCH: begin
		if (first && s_ready_i)	state	<= #2 `UCST_UPDATE;
	end
	
	// Update cache-line issue hits if data present.
	`UCST_UPDATE: begin
		if (!hit && read_r)	state	<= #2 `UCST_WAIT;
	end
	
	// Cache busy, wait until end to fetch another cache-line.
	`UCST_WAIT: begin
		if (pending)	state	<= #2 `UCST_FETCH;
		else if (fdone)	state	<= #2 `UCST_IDLE;	// TODO: Never gets here?
	end
	
	endcase


always @(posedge clock_i)
	if (miss)		l_addr	<= #2 {oldest, m_addr_i [2:0]};
// 	else if (m_rack_o)	l_addr	<= #2 {m1, m_addr_i [2:0]};


always @(posedge clock_i)
	{read_r, m1_r, m0_r}	<= #2 {m_read_i, m1, m0};


always @(posedge clock_i)
	if (!reset_ni)		pending	<= #2 0;
	// FIXME


always @(posedge clock_i)
	if (!reset_ni)	ready	<= #2 0;
	else if (first)	ready	<= #2 1;
	else if (((oldest && m0) || (!oldest && m1)) && m_read_i)// || (((!oldest && m0) || (oldest && m1)) && m_read_i && loaded [m_addr_i [2:0]]))
		ready	<= #2 1;
	else		ready	<= #2 0;


// Upon miss, go fetch the cache-line from memory (or another cache).
always @(posedge clock_i)
	if (!reset_ni)		s_read_o	<= #2 0;
	else if (miss)		s_read_o	<= #2 1;
	else if (s_rack_i)	s_read_o	<= #2 0;

always @(posedge clock_i)
	if (m_rack_o)	addr	<= #2 m_addr_i;


// Update the cache contents.
always @(posedge clock_i)
	if (s_addr_o)	u_addr	<= #2 {oldest, addr [2:0]};
	else 		u_addr [2:0]	<= #2 u_addr [2:0] + s_ready_i;

always @(posedge clock_i)
	if (s_ready_i)	mem [u_addr]	<= #2 s_data_i;

always @(posedge clock_i)
	if (!reset_ni)	fcnt	<= #2 0;
	else		fcnt	<= #2 fcnt + s_ready_i;

// Allow data to be read from partially retrieved cache-lines.
always @(posedge clock_i)
	if (!reset_ni)	loaded	<= #2 0;
	else if (fdone)	loaded	<= #2 0;
	else if (state != `UCST_IDLE && s_ready_i)
		loaded [u_addr [2:0]]	<= #2 1'b1;


// Once a new cache-line has been fetched, point to the oldest (other) cache-
// line.
reg	update_r	= 0;
always @(posedge clock_i)	update_r	<= #2 update;

always @(posedge clock_i)
	if (!reset_ni)		oldest	<= #2 0;
	else if (update_r)	oldest	<= #2 ~oldest;

always @(posedge clock_i)
	if (!reset_ni)
		{tag1, tag0}	<= #2 0;
	else if (update_r) begin
		if (!oldest)	tag0	<= #2 s_addr_o [ASB:3];
		else		tag1	<= #2 s_addr_o [ASB:3];
	end

always @(posedge clock_i)
	if (!reset_ni)
		{vld1, vld0}		<= #2 0;
	else if (update_r) begin
		if (!oldest)	vld0	<= #2 1;
		else		vld1	<= #2 1;
	end

*/
endmodule	// ucache
