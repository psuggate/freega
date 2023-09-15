/***************************************************************************
 *                                                                         *
 *   th_decode.v - The third stage of this pipelined TTA CPU. This TTA is  *
 *     not pure and supports a packed instruction mode where two           *
 *     instructions fit in a 32-bit word.                                  *
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
module th_decode (
	clock_i,
	reset_ni,
	enable_i,
	
	is_instr_i,
	is_nop_i,
	
	tr_packed_o,
	tr_instr_o,
	tr_immed_o,
	tr_nop_no,
	tr_rf_idx_o,
	tr_bra_imm_o,
	tr_bra_reg_o
);

// Change these at your own risk since most of this module is hard-coded.
parameter	INSTRUCTION	= 32;
parameter	WORDSIZE	= 18;
parameter	IMMEDBITS	= 13;
parameter	RFBITS		= 4;
parameter	PC_INIT		= 0;

parameter	MSB	= INSTRUCTION - 1;
parameter	WSB	= WORDSIZE - 1;
parameter	ISB	= IMMEDBITS - 1;
parameter	RSB	= RFBITS - 1;

input		clock_i;
input		reset_ni;
input		enable_i;

input	[MSB:0]	is_instr_i;
input		is_nop_i;

output		tr_packed_o;
output	[MSB:0]	tr_instr_o;
output	[WSB:0]	tr_immed_o;
output		tr_nop_no;
output	[RSB:0]	tr_rf_idx_o;
output		tr_bra_imm_o;
output		tr_bra_reg_o;


reg		tr_bra_imm_o	= 1;
// reg	tr_bra_reg_o	= 0;	// FIXME
reg	[MSB:0]	tr_instr_o;
reg	[WSB:0]	tr_immed_o	= 0;
reg		tr_nop_no	= 1;
reg	[3:0]	tr_rf_idx_o	= 0;
reg		tr_packed_o;
reg	isel	= 0;

wire	packed, sign, branch;
wire	[MSB:0]	instr_w;
wire	[WSB:0]	immed;


assign	tr_bra_reg_o	= 0;	// TODO

assign	packed	= is_instr_i [MSB];
assign	sign	= is_instr_i [26];
assign	immed	= {{(WORDSIZE-10){sign}}, is_instr_i [25:16]};

// assign	tr_packed_o	= is_instr_i [MSB];

// TODO
assign	branch	= (is_instr_i [12:9] == 4'b1000);


always @(posedge clock_i)
	tr_instr_o	<= #2 instr_w;

always @(posedge clock_i)
	if (!reset_ni)		tr_immed_o	<= #2 PC_INIT;
	else if (packed)	tr_immed_o	<= #2 0;
	else			tr_immed_o	<= #2 immed;

always @(posedge clock_i)
	if (!reset_ni)		tr_bra_imm_o	<= #2 1'b1;
	else if (is_nop_i)	tr_bra_imm_o	<= #2 1'b0;	// TODO needed?
	else			tr_bra_imm_o	<= #2 branch;

always @(posedge clock_i)
	if (!reset_ni)	tr_nop_no	<= #2 1'b0;
	else		tr_nop_no	<= #2 ~is_nop_i;

always @(posedge clock_i)
	if (!reset_ni)	tr_packed_o	<= #2 0;
	else		tr_packed_o	<= #2 packed;

always @(posedge clock_i)
	tr_rf_idx_o	<= #2 is_instr_i [30:27];


th_unpack UNPACK0 (
	.instr_i	(is_instr_i),
	.sel_i		(isel),
	.instr_o	(instr_w)
);


endmodule	// th_decode


module th_unpack (
	instr_i,
	sel_i,
	instr_o
);

input	[31:0]	instr_i;
input		sel_i;
output	[31:0]	instr_o;


wire		p;
wire	[31:0]	i	= instr_i;

wire		sign;
wire	[9:0]	immed;

wire	[2:0]	s00, d00, s01, com0;
wire	[3:0]	d01, r0;
wire	[2:0]	s10, d10, s11, com1;
wire	[3:0]	d11, r1;

wire	[31:0]	instr0, instr1;


assign	p	= i [31];
assign	sign	= i [30];
assign	immed	= i [29:20];

// Instruction 0:
assign	#2 s00	= p ? {1'b0, i [1:0]}	: i [2:0];
assign	d00	= i [5:3];
assign	#2 s01	= p ? {1'b0, i [7:6]}	: i [8:6];
assign	#2 d01	= p ? {2'b00, i [10:9]}	: i [12:9];
assign	com0	= i [15:13];
assign	r0	= i [30:27];

// Instruction 1:
assign	#2 s10	= {1'b0, i [8], i [2]};
assign	d10	= {i [16], i [12:11]};
assign	#2 s11	= {1'b0, i [18:17]};
assign	#2 d11	= {2'b00, i [20:19]};
assign	com1	= i [23:21];
assign	r1	= {i [30], i [26:24]};


assign	instr0	= {1'b0, r0, com0, d01, s01, d00, s00};
assign	instr1	= {1'b0, r1, com1, d11, s11, d10, s10};

assign	#2 instr_o	= sel_i ? instr1 : instr0 ;


endmodule	// th_unpack
