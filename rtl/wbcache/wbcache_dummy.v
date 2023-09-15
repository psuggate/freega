/***************************************************************************
 *                                                                         *
 *   wbcache_dummy - A Wishbone compliant, dummy instruction cache.        *
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
module wbcache_dummy #(
	parameter	HIGHZ	= 0,
	parameter	WIDTH	= 32,
	parameter	ADDRESS	= 18,
	parameter	WORDBITS	= 9,
	parameter	LINEBITS	= 4,
	parameter	MSB	= WIDTH - 1,
	parameter	ASB	= ADDRESS - 1,
	parameter	ESB	= WIDTH / 8 - 1,
	parameter	WORDS	= (1<<WORDBITS),
	parameter	LINES	= (1<<LINEBITS)
) (
	input		clock_i,
	input		reset_i,
	
	input		lookup_i,
	output		busy_o,
	output		miss_o,
	input		bra_imm_i,
	input		bra_reg_i,
	input	[ASB:0]	pc_nxt_i,
	input	[ASB:0]	pc_imm_i,
	input	[ASB:0]	pc_reg_i,
	
	output	reg	ready_o	= 0,
	output	reg	[MSB:0]	data_o	= 0,
	output	[ASB:0]	pc1_o,
	output	[ASB:0]	pc2_o,
	output	[ASB:0]	pc3_o,
	
	input		wb_clk_i,
	input		wb_rst_i,
	output		wb_cyc_o,
	output		wb_stb_o,
	output		wb_we_o,
	input		wb_ack_i,
	input		wb_rty_i,
	input		wb_err_i,
	output	[2:0]	wb_cti_o,
	output	[1:0]	wb_bte_o,
	output	[ASB:0]	wb_adr_o,
	input	[ESB:0]	wb_sel_i,
	input	[MSB:0]	wb_dat_i,
	output	[ESB:0]	wb_sel_o,
	output	[MSB:0]	wb_dat_o
);

`define	HIT_RATE	922

reg	[31:0]	mem [262143:0];	// 1 MB
reg	fetch	= 0;
reg	lookup1	= 0;
reg	[ASB:0]	pc1	= 0;
reg	redirect	= 0;	// Unused atm.

reg	[ASB:0]	pc2	= 0;
reg	lookup2	= 0;
reg	[9:0]	randhit	= 0;
reg	hit	= 0;
reg	miss	= 0;

reg	[5:0]	count	= 0;
reg	[ASB:0]	pc3	= 0;


assign	busy_o	= fetch;
assign	miss_o	= miss;
assign	pc1_o	= pc1;
assign	pc2_o	= pc2;
assign	pc3_o	= pc3;

assign	wb_cyc_o	= 0;
assign	wb_stb_o	= 0;
assign	wb_we_o		= 0;


// Three stage pipe.

// Stage I: Construct PC.
always @(posedge clock_i)
	if (reset_i)	lookup1	<= #2 0;
	else if (fetch)	lookup1	<= #2 lookup1;
	else		lookup1	<= #2 (redirect | lookup_i);

always @(posedge clock_i)
	if (reset_i)
		pc1	<= #2 0;
	else if (fetch && lookup1)
		pc1	<= #2 pc1;
	else if (redirect)
		pc1	<= #2 pc2;
	else if (bra_imm_i)
		pc1	<= #2 pc_imm_i;
	else if (bra_reg_i)
		pc1	<= #2 pc_reg_i;
	else
		pc1	<= #2 pc_nxt_i;


// Stage II: Just kill some time.
always	@(posedge clock_i)
	randhit	<= $random;

always @(posedge clock_i)
	if (reset_i)
		{miss, hit}	= #2 0;
	else begin
		if (count != 0) begin
			miss	<= #2 0;
			hit	<= #2 0;
		end else if (!fetch || !lookup2 || miss) begin
			hit	<= #2  (randhit < `HIT_RATE) && lookup1;
			miss	<= #2 !(randhit < `HIT_RATE) && lookup1;
			lookup2	<= #2 lookup1;
			pc2	<= #2 pc1;
		end
	end


// Stage III: Random data
always @(posedge clock_i)
	if (reset_i)	{data_o, fetch}	<= #2 0;
	else if (!fetch) begin
		if (miss) begin
			pc3	<= #2 pc2;
			ready_o	<= #2 0;
			fetch	<= #2 1;
			count	<= #2 60;
		end else if (hit || lookup2) begin
			pc3	<= #2 pc2;
			ready_o	<= #2 1;
			data_o	<= #2 mem[pc2];
		end else
			ready_o	<= #2 0;
	end else if (count == 0) begin
		fetch	<= #2 0;
		ready_o	<= #2 1;
		data_o	<= #2 mem[pc3];
	end else
		count	<= #2 count - 1;


integer	ii;
initial begin : Init
	for (ii=0; ii<262144; ii=ii+1)
		mem[ii]	= $random;
end	// Init


endmodule	// cache_dummy
