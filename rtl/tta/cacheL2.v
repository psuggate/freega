/***************************************************************************
 *                                                                         *
 *   cacheL2.v - A simple, fast, but high-latency (five cycles) cache      *
 *     designed to sit between an L0/L1 cache and a main memory.           *
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

`timescale 1ns/100ps
module cacheL2 (
	clock_i,
	reset_ni,
	
	lu_get_i,
	lu_addr_i,
	lu_hit_o,
	lu_data_o,
	
	fetch_o,	// Get a new cache-line from main memory
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

input	lu_get_i;
input	[AMSB:0]	lu_addr_i;
output	lu_hit_o;
output	[DMSB:0]	lu_data_o;

output	fetch_o;
input	invld_i;
input	store_i;
input	[AMSB:0]	addr_i;
input	[DMSB:0]	data_i;


//---------------------------------------------------------------------------
//  Stage I: Tag lookup.
//  Also, update a tag if needed.
//
reg	[37:0]	tag_mem [0:15];	// TODO: Parameterise
reg	[7:0]	tag0, tag1, tag2, tag3;
reg	[1:0]	age;	// Used for replacement policy

reg	lu_get1;		// These are used by subsequent stages
reg	[2:0]	word_addr1;
reg	[3:0]	line_addr1;
reg	[8:0]	tag_addr1;

// Single port RAM.
always @(posedge clock_i) begin
	if (lu_get_i) begin
		{age, tag3, tag2, tag1, tag0}	<= #1 tag_mem[addr_i[6:3]];
		
		lu_get1		<= #1 1;
		word_addr1	<= #1 addr_i[2:0];
		line_addr1	<= #1 addr_i[6:3];
		tag_addr1	<= #1 addr_i[15:7];
	end
	else if (update_tags) begin
		tag_mem [update_addr]	<= #1 new_tag;
		lu_get_I	<= #1 0;
	end
end


//---------------------------------------------------------------------------
//  Stage II: Caclulate hit.
//
reg	hit0	= 0, hit1	= 0, hit2	= 0; hit3	= 0;

reg	lu_get2;
reg	[2:0]	word_addr2;
reg	[3:0]	line_addr2;
reg	[8:0]	tag_addr1;

always @(posedge clock_i) begin
	if (!reset_ni)
		{hit3, hit2, hit1, hit0}	<= #1 0;
	else begin
		if (lu_get1) begin
			hit0	<= #2 (tag0 == tag_addr);
			hit1	<= #2 (tag1 == tag_addr);
			hit2	<= #2 (tag2 == tag_addr);
			hit3	<= #2 (tag3 == tag_addr);
			
			lu_get2		<= #1 lu_get1;
			word_addr2	<= #1 word_addr1;
			line_addr2	<= #1 line_addr1;
		end
		else
			lu_get3		<= #1 0;
	end
end


//---------------------------------------------------------------------------
//  Stage III: Caclulate cache data address.
//
reg	[1:0]	bank_addr;
reg	[3:0]	line_addr3;
reg	[2:0]	word_addr3;

reg	taghit	= 0;

wire	taghit_w, upperbit, lowerbit;

assign	#1 upperbit	= hit2 | hit3;
assign	#1 lowerbit	= hit1 | hit3;
assign	#1 taghit_w	= hit3 | hit2 | hit1 | hit0;

always @(posedge clock_i) begin
	if (!reset_ni)
		taghit		<= #1 0;
	else if (lu_get2) begin
		taghit		<= #1 taghit_w;
		bank_addr	<= #1 {upperbit, lowerbit};
		
		word_addr3	<= #1 word_addr2;
		line_addr3	<= #1 line_addr2;
	end
end


RAMB16_S36_S36 bram (
	.CLKA	(clock_i),
	.SSRA	(1'b0),
	.ADDRA	({bank_addr, line_addr3, word_addr3}),
	.ENA	(lu_get3),
	.DOA	(cache_data),
	.DOPA	(invld),
	.WEA	(1'b0),
	.DIA	(32'b0),
	.DIPA	(4'b0),
	
	.CLKB	(clock_i),
	.SSRB	(1'b0),
	.ADDRB	(write_addr),
	.ENB	(1'b1),
	.DOB	(),
	.DOPB	(),
	.WEB	(),
	.DIB	(),
	.DIPB	()
);


endmodule	// cacheL2
