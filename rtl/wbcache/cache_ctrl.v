/***************************************************************************
 *                                                                         *
 *   cache_ctrl.v - Control logic for a 3-pipeline stage cache.            *
 *     Two-way set-associative.                                            *
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
module cache_ctrl #(
	parameter	ADDRESS	= 18,
	parameter	ASB	= ADDRESS - 1
) (
	input		clock_i,
	input		reset_i,
	
	input		newseg_i,	// 1MB segment size
// 	output	reg	busy_o	= 1,
	output		busy_o,
	
	output	reg	s1_enable_o	= 0,
	input		s1_full_i,
	input	[ASB:0]	s1_pc_i,
	
	output	reg	s2_enable_o	= 0,
	input		s2_full_i,
	input	[ASB:0]	s2_pc_i,
	
	output	reg	s3_enable_o	= 0,
	input		s3_miss_ai,
	input	[ASB:0]	s3_pc_i,
	
	output	reg	u_fetch_o	= 0,
	input		u_ack_i,
	input		u_done_i,
	
	output	reg	t_write0_o	= 0,
	output	reg	t_valid0_o	= 0,
	output	reg	t_write1_o	= 0,
	output	reg	t_valid1_o	= 0,
	output	reg	t_addr_sel_o	= 0,
	output	reg	[ASB:0]	t_addr_o	= 0
);


`define	CCST_IDLE	4'b0000
`define	CCST_FETCHING	4'b0001
`define	CCST_REDIRECT	4'b0010
`define	CCST_INVALIDATE	4'b1000
reg	[3:0]	state	= `CCST_INVALIDATE;
reg	redirect2	= 0;
reg	t_update	= 0;

wire	u_bank, t_bank, miss;


assign	#2 miss	= (state == `CCST_IDLE) && s3_miss_ai;
assign	#2 busy_o	= (state != `CCST_IDLE);


always @(posedge clock_i)
	if (reset_i)
		state	<= #2 `CCST_INVALIDATE;
	else case (state)
	
	`CCST_INVALIDATE:
		if (t_addr_o [7:4] == 4'b1111)
			state	<= #2 `CCST_IDLE;
	
	`CCST_IDLE:
		if (s3_miss_ai)
			state	<= #2 `CCST_FETCHING;
	
	`CCST_FETCHING:
		if (u_done_i) begin
			if (s2_full_i)
				state	<= #2 `CCST_REDIRECT;
			else
				state	<= #2 `CCST_IDLE;
		end
	
	// Redirect any stalled lookups, that occurred after a miss, back
	// through the cache. 
	`CCST_REDIRECT:
		if (!redirect2)
			state	<= #2 `CCST_IDLE; 
	
	endcase

/*
always @(posedge clock_i)
	if (reset_i)			busy_o	<= #2 1;
	else if (state == `CCST_IDLE)	busy_o	<= #2 0;
*/

always @(posedge clock_i)
	if (reset_i)
		redirect2	<= #2 0;
	else if (state == `CCST_REDIRECT)
		redirect2	<= #2 0;
	else if (state == `CCST_IDLE && s3_miss_ai)
		redirect2	<= #2 (s1_full_i && s2_full_i);


// As long as the pipeline hasn't stalled, enable stage I.
always @(posedge clock_i)
	if (reset_i)
		s1_enable_o	<= #2 0;
	else if (state == `CCST_IDLE || (state == `CCST_FETCHING && !s1_full_i))
		s1_enable_o	<= #2 1;
	else
		s1_enable_o	<= #2 0;


// Upon miss, stall the previous two stages if full.
always @(posedge clock_i)
	if (reset_i)
		s2_enable_o	<= #2 0;
	else if (state == `CCST_INVALIDATE)
		s2_enable_o	<= #2 0;
	else if (!s2_full_i)
		s2_enable_o	<= #2 1;
	else if (miss)
		s2_enable_o	<= #2 0;
	else if (state != `CCST_IDLE)
		s2_enable_o	<= #2 0;
	else
		s2_enable_o	<= #2 1;


always @(posedge clock_i)
	if (reset_i)
		s3_enable_o	<= #2 0;
	else if (state == `CCST_IDLE)
		s3_enable_o	<= #2 1;
	else if (u_done_i)
		s3_enable_o	<= #2 1;
	else
		s3_enable_o	<= #2 0;


// Cache contents updating.
always @(posedge clock_i)
	if (reset_i)		u_fetch_o	<= #2 0;
	else if (miss)		u_fetch_o	<= #2 1;
	else if (u_ack_i)	u_fetch_o	<= #2 0;


// Tag updating stuff.
always @(posedge clock_i)
	if (reset_i)
		t_addr_o [7:4]	<= #2 4'b0000;
	else if (state == `CCST_INVALIDATE && t_addr_o [7:4] != 4'b1111)
		t_addr_o [7:4]	<= #2 t_addr_o [7:4] + 1;
	else if (state == `CCST_REDIRECT)
		t_addr_o	<= #2 s2_pc_i;
	else if (state == `CCST_IDLE && s3_miss_ai)
		t_addr_o	<= #2 s2_pc_i;


always @(posedge clock_i)
	if (reset_i)	t_update	<= #2 0;
	else if (miss)	t_update	<= #2 1;
	else		t_update	<= #2 0;

always @(posedge clock_i)
	if (state == `CCST_INVALIDATE)
		{t_write0_o, t_valid0_o, t_write1_o, t_valid1_o}	<= #2 4'b1010;
	else if (miss)
		{t_write0_o, t_valid0_o, t_write1_o, t_valid1_o}	<= #2 {~t_bank, ~t_bank, t_bank, t_bank};
	else
		{t_write0_o, t_valid0_o, t_write1_o, t_valid1_o}	<= #2 4'b0000;

// Determine the cache entry to evict.
reg	[7:0]	mfsr_cnt	= 1;
wire	[7:0]	mfsr_cnt_w;

assign	u_bank		= mfsr_cnt [0];
assign	t_bank		= mfsr_cnt [0];

always @(posedge clock_i)
	if (reset_i)
		mfsr_cnt	<= #2 1;
	else if (t_update)
		mfsr_cnt	<= #2 mfsr_cnt_w;


mfsr8 MFSR0 (
	.count_i(mfsr_cnt),
	.count_o(mfsr_cnt_w)
);


endmodule
