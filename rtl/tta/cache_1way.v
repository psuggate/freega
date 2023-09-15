/***************************************************************************
 *                                                                         *
 *   cache_1way.v - A parameterisable CPU 2-way associative cache.         *
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
module cache_1way (
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

parameter	LINE	= 64;	// 32-bytes
parameter	AW	= 16;
parameter	DW	= 32;
parameter	BAMSB	= 8;	// BRAM address bits-1
parameter	BSIZE	= 512;	// Number of words/BRAM
//parameter	BSIZE	= 2 ** (BAMSB+1);	// Number of words
parameter	LWORDS	= (LINE * 8) / DW;
parameter	TSIZE	= 64;
//parameter	TSIZE	= BSIZE * DW / (LINE * 8);

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

// Instantiate the tag memory.
reg	[TMSB:0]	tag_mem [0:TSIZE-1];

// And the cache SRAM.
reg	[DW:0]	sram [0:BSIZE-1];

reg	get	= 0;

reg	hit_r	= 0;
//reg	[DMSB:0]	data_o;

reg	mem_fetch	= 0;
reg	[8:0]	sram_addr	= 0;

//reg	invld	= 0;
wire	invld;

wire	hit_w;
wire	miss;
wire	[TMSB:0]	tag;


assign	tag		= tag_mem [pc_i [8:4]];
assign	#1 hit_w	= (tag == pc_i [15:9]);
assign	#1 hit_o	= (hit_r && !invld);
assign	#1 miss		= (get && !hit_w);

assign	read_o	= mem_fetch;
assign	addr_o	= {tag, sram_addr [8:4], 4'b0000};


always @(posedge clock_i) begin
	if (!reset_ni)
		hit_r	<= #1 0;
	else
		hit_r	<= #1 hit_w;
end


// Upon miss, add a new tag to the cache.
always @(posedge clock_i) begin
	if (miss)
		tag_mem [pc_i [8:4]]	<= #1 pc_i [15:9];
end


always @(posedge clock_i) begin
	if (!reset_ni)
		get	<= 0;
	else
		get	<= get_i;
end


always @(posedge clock_i) begin
	if (!reset_ni)
		mem_fetch	<= #1 0;
	else if (miss)
		mem_fetch	<= #1 1;
	else
		mem_fetch	<= #1 0;
end


always @(posedge clock_i) begin
	if (miss)
		sram_addr	<= #1 {pc_i [8:4], 4'b0000};
	else if (ready_i)
		sram_addr [3:0]	<= #1 sram_addr [3:0] + 1;
end


RAMB16_S36_S36 sram0 (
	.CLKA	(clock_i),
	.SSRA	(1'b0),
	.ADDRA	(pc_i [BAMSB:0]),
	.ENA	(1'b1),
	.DOA	(data_o),
	.DOPA	(invld),
	.WEA	(1'b0),
	.DIA	(32'b0),
	.DIPA	(4'b0),
	
	.CLKB	(clock_i),
	.SSRB	(1'b0),
	.ADDRB	(sram_addr),
	.ENB	(1'b1),
	.DOB	(),
	.DOPB	(),
	.WEB	(ready_i),
	.DIB	(data_i),
	.DIPB	({3'b0, invld_i})
);

/*
// Port A.
always @(posedge clock_i)
	{invld, data_o}	<= #2 sram [pc_i [8:0]];


// Port B.
always @(posedge clock_i) begin
	if (ready_i)
		sram [sram_addr]	<= #1 {1'b0, data_i};
end


integer	i;
initial begin : Init
	for (i=0; i<BSIZE; i=i+1)
		sram [i]	= {1'b1, $random};	// Mark as invalid
	
	for (i=0; i<TSIZE; i=i+1)
		tag_mem [i]	= $random;
end	// Init
*/

endmodule	// cache_1way
