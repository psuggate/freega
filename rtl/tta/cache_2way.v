/***************************************************************************
 *                                                                         *
 *   cache_2way.v - A parameterisable CPU 2-way associative cache.         *
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

// TODO: Probably rename this to cache_2way.
// TODO: Use an invalid flag? This allows cache-lines to be invalidated to
// keep the cache coherent, and allows for a sensible startup.
`timescale 1ns/100ps
module cache_2way (
	clock_i,
	reset_ni,
	init_no,
	
	pc_i,
	get_i,
	hit_o,
	data_o,
	
	invld_i,	// Used to invalidate cache-lines, like when a PCI
	iaddr_i,	// transaction clobbers instruction data.
	
	addr_o,
	read_o,
	full_i,		// So the memory controller isn't flooded
	ready_i,
	data_i
);

parameter	LINE	= 32;	// 32-bytes
parameter	AW	= 16;
parameter	DW	= 32;
parameter	BAMSB	= 8;	// BRAM address bits-1
parameter	BSIZE	= 512;	// Number of words/BRAM
//parameter	BSIZE	= 2 ** (BAMSB+1);	// Number of words
parameter	LWORDS	= (LINE * 8) / DW;
parameter	TSIZE	= BSIZE * DW / (LINE * 8);

parameter	TMSB	= 6;
parameter	DMSB	= DW-1;
parameter	AMSB	= AW-1;


input	clock_i;
input	reset_ni;
output	init_no;

input	[AMSB:0]	pc_i;
input	get_i;
output	hit_o;
output	[DMSB:0]	data_o;

input	invld_i;
input	[AMSB:0]	iaddr_i;

output	[AMSB:0]	addr_o;
output	read_o;
input	full_i;
input	ready_i;
input	[DMSB:0]	data_i;

// Instantiate the tag memories required.
reg			tag_age [0:TSIZE-1];	// Used for replacement policy
reg	[TMSB:0]	tag_mem0 [0:TSIZE-1];
reg	[TMSB:0]	tag_mem1 [0:TSIZE-1];

/*
reg	[DW:0]	sram0 [0:BSIZE-1];	// DW + 1 invalid bit
reg	[DW:0]	sram1 [0:BSIZE-1];
*/

reg	[TMSB:0]	tag0, tag1;
reg	hit_o	= 0, miss	= 0;
reg	age	= 0;

reg	read_word	= 0;
/*
reg	[DMSB:0]	entry0, entry1;
reg	invld0, invld1;
*/
reg	[DMSB:0]	data_o;

`define	ICST_INIT	2'b00
`define	ICST_IDLE	2'b01
`define	ICST_FETCH	2'b10
reg	[1:0]	state	= `ICST_INIT;

reg	[9:0]	init_addr	= 0;
reg	[4:0]	line_addr	= 0;
reg	[3:0]	load_addr	= 0;
reg	[3:0]	store_addr	= 0;
reg	[6:0]	tag_addr	= 0;

reg	read_o	= 0;
reg	fetch_done	= 0;

// TODO:
reg	[TMSB+1:0]	prev_tag	= 0;

wire	[8:0]	write_addr;

wire	[DMSB:0]	entry0, entry1;
wire	invld0, invld1;

wire	[5:0]	tag_lu_addr;

wire	tag0_match;
wire	tag1_match;
wire	hit_w;

wire	write0;
wire	write1;


assign	init_no	= (state != `ICST_INIT);

assign	addr_o	= {tag_addr, line_addr, 4'b0000};

assign	#1 tag_lu_addr	= miss ? line_addr : pc_i [8:4];

assign	#2 tag0_match	= ({invld0, tag0} == {1'b0, pc_i[15:10]});
assign	#2 tag1_match	= ({invld1, tag1} == {1'b0, pc_i[15:10]});
assign	#1 hit_w	= (!invld0 && tag0_match) || (!invld1 && tag1_match);

assign	#1 write0	= ((ready_i && !age) || (state == `ICST_INIT));
assign	#1 write1	= ((ready_i && age) || (state == `ICST_INIT));

assign	#1 write_addr	= (state == `ICST_INIT) ? init_addr [8:0] : {line_addr, store_addr};

always @(posedge clock_i) begin
	if (tag1_match)
		data_o	<= entry1;
	else
		data_o	<= entry0;
end


// Theory of operation:
// Initially, the cache memory is empty so invalidate all the cache entries
// before entering IDLE.
// Once the cache has been placed into its initial operation state, match the
// incoming address. This will fail so fetch the first cache line from main
// memory (or the L2 cache if present).
//

always @(posedge clock_i) begin
	if (!reset_ni)
		state	<= `ICST_INIT;
	else case (state)
	
	// Invalidate all cache-lines upon startup.
	`ICST_INIT: begin
		// TODO: Optimise this. Only the upper bit to be tested?
		if (init_addr == BSIZE-1)
			state	<= `ICST_IDLE;
	end
	
	// Stay in idle state until a miss occurs.
	`ICST_IDLE: begin
		if (miss)
			state	<= `ICST_FETCH;
	end
	
	// Fetch an entire cache-line. (16 words, 64 bytes.)
	`ICST_FETCH: begin
		if (store_addr [3:0] == 4'hF && ready_i)
			state	<= `ICST_IDLE;
	end
	
	endcase
end


//---------------------------------------------------------------------------
// Cache memory tags.
// TODO: Parameterise.
//
always @(posedge clock_i) begin
	if (state == `ICST_IDLE)
		age	<= tag_age [tag_lu_addr];
	
	// Evict oldest entry and add new tag.
	if (miss) begin
		if (age)
			tag_mem1 [tag_lu_addr]	<= tag_addr;
		else
			tag_mem0 [tag_lu_addr]	<= tag_addr;
		tag_age [line_addr]	<= ~age;
	end
	else begin
		tag0	<= tag_mem0 [tag_lu_addr];
		tag1	<= tag_mem1 [tag_lu_addr];
	end
end

reg	get0	= 0, get1	= 0;
always @(posedge clock_i) begin
	if (!reset_ni)
		{get1, get0}	<= 0;
	else if (state == `ICST_IDLE)
		{get1, get0}	<= {get0, get_i};
end


// Match tags and also check the invalidate bit from the BRAM.
// TODO: This will be too slow?
always @(posedge clock_i) begin
	if (!reset_ni)
		hit_o	<= 0;
	else if (state != `ICST_INIT)
		hit_o	<= hit_w & get1;
	else
		hit_o	<= hit_o;
end


reg	miss_oneshot	= 0;
always @(posedge clock_i) begin
	if (!reset_ni) begin
		miss		<= 0;
		miss_oneshot	<= 0;
	end
	else if (state == `ICST_INIT) begin
		miss		<= 0;
		miss_oneshot	<= 0;
	end
	else if (state == `ICST_FETCH) begin
		miss	<= 0;
		miss_oneshot	<= 0;
	end
	else begin
		miss	<= (!hit_w && !miss_oneshot);
		miss_oneshot	<= ~hit_w;
	end
end


//---------------------------------------------------------------------------
// Generate memory reads on cache misses.
//
// TODO: An extra cycle of latency can be saved here.
always @(posedge clock_i) begin
	if (state != `ICST_FETCH)
		fetch_done	<= #1 0;
	else if (store_addr [3:0] == 4'hF && ready_i)
		fetch_done	<= #1 1;
end

// Issue a cache-line read on a miss.
reg	read_oneshot	= 1;
always @(posedge clock_i) begin
	if (!reset_ni) begin
		read_o		<= #1 0;
		read_oneshot	<= #1 1;
	end
	else begin
		if (miss)
			read_oneshot	<= #1 0;
		else
			read_oneshot	<= #1 1;
		
		if (!read_oneshot && !full_i)
			read_o	<= #1 1;
		else
			read_o	<= #1 0;
	end
end


//---------------------------------------------------------------------------
// The cache memory is two Dual-port SRAMs/BRAMs.
//
/*
// Port A.
always @(posedge clock_i) begin
	{invld0, entry0}	<= sram0 [pc_i [BAMSB:0]];
	{invld1, entry1}	<= sram1 [pc_i [BAMSB:0]];
end

// Port B.
// On initialisation, fill the caches up with INVALID data. Once the cache is
// in normal operation mode, if valid data is present on the inputs, write it
// to the RAM block and de-assert INVALID for the entry.
// TODO: Support external invalidates.
`define	INVALID	33'h1_xxxx_xxxx
always @(posedge clock_i) begin
	if (state == `ICST_INIT) begin
		sram0 [count [BAMSB:0]]	<= `INVALID;
		sram1 [count [BAMSB:0]]	<= `INVALID;
		count	<= count + 1;
	end
	else if (state == `ICST_IDLE)
		// Store the incoming address incase it is needed for a cache
		// fetch. The lower 4-bits are zeroed so that an entire
		// cache-line is fetched.
		count	<= {1'b0, pc_i [AMSB:4], 4'b0000};
	else if (ready_i && count [3:0] < 4'hF) begin
		if (age)
			sram1 [count [BAMSB:0]] <= {1'b0, data_i};
		else
			sram0 [count [BAMSB:0]] <= {1'b0, data_i};
		count	<= count + 1;
	end
end
*/

always @(posedge clock_i) begin
	if (!reset_ni)
		init_addr	<= 0;
	else if (state == `ICST_INIT)
		init_addr	<= init_addr + 1;
end

always @(posedge clock_i) begin
	if (!reset_ni) begin
		line_addr	<= 0;
		tag_addr	<= 0;
	end
	else if (state == `ICST_IDLE && get_i) begin
		tag_addr	<= pc_i [15:9];
		line_addr	<= pc_i [8:4];
	end
end

always @(posedge clock_i) begin
	if (!reset_ni)
		store_addr	<= 0;
	else if (state == `ICST_IDLE)
		store_addr	<= 0;
	else if (ready_i && store_addr [3:0] != 4'hF)
		store_addr	<= store_addr + 1;
end


RAMB16_S36_S36 sram0 (
	.CLKA	(clock_i),
	.SSRA	(1'b0),
	.ADDRA	(pc_i [BAMSB:0]),
	.ENA	(1'b1),
	.DOA	(entry0),
	.DOPA	(invld0),
	.WEA	(1'b0),
	.DIA	(32'b0),
	.DIPA	(4'b0),
	
	.CLKB	(clock_i),
	.SSRB	(1'b0),
	.ADDRB	(write_addr),
	.ENB	(1'b1),
	.DOB	(),
	.DOPB	(),
	.WEB	(write0),
	.DIB	(data_i),
	.DIPB	({3'b0, (state == `ICST_INIT)})
);


RAMB16_S36_S36 sram1 (
	.CLKA	(clock_i),
	.SSRA	(1'b0),
	.ADDRA	(pc_i [BAMSB:0]),
	.ENA	(1'b1),
	.DOA	(entry1),
	.DOPA	(invld1),
	.WEA	(1'b0),
	.DIA	(32'b0),
	.DIPA	(4'b0),
	
	.CLKB	(clock_i),
	.SSRB	(1'b0),
	.ADDRB	(write_addr),
	.ENB	(1'b1),
	.DOB	(),
	.DOPB	(),
	.WEB	(write1),
	.DIB	(data_i),
	.DIPB	({3'b0, (state == `ICST_INIT)})
);


`ifdef __icarus
//---------------------------------------------------------------------------
// Initialisation for simulation.
//
integer	i;
initial begin : Init
/*	for (i=0; i<BSIZE; i=i+1) begin
		sram0 [i]	<= $random;
		sram1 [i]	<= $random;
	end
	*/
	for (i=0; i<TSIZE; i=i+1) begin
		tag_age [i]	<= $random;
		tag_mem0 [i]	<= $random;
		tag_mem1 [i]	<= $random;
	end
end	// Init

`endif

endmodule	// cache_2way
