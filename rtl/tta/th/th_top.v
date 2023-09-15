/***************************************************************************
 *                                                                         *
 *   th_top.v - Basically just useful for generating marketing numbers.    *
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


// The instruction format.
`define	D0S_COM		3'b000
`define	D0S_RF		3'b001
`define	D0S_MEMH	3'b010
`define	D0S_DIFF	3'b011

`define	D0S_IMM		3'b100
`define	D0S_BITN	3'b101
`define	D0S_PCN		3'b111

`define	D0D_NOP		3'b000
`define	D0D_WAD		3'b001
`define	D0D_MEMH	3'b010
`define	D0D_SUB		3'b011
`define	D0D_RF		3'b100
`define	D0D_AND		3'b101
`define	D0D_OR		3'b110
`define	D0D_XOR		3'b111


`define	D1S_COM		3'b000
`define	D1S_RF		3'b001
`define	D1S_MEML	3'b010
`define	D1S_INC		3'b011

`define	D1S_IMM		3'b100

`define	D1D_NOP		4'b0000
`define	D1D_RAD		4'b0001
`define	D1D_MEML	4'b0010
`define	D1D_INC		4'b0011

`define	D1D_PC		4'b1000
`define	D1D_PCZ		4'b1001
`define	D1D_PCNZ	4'b1010

`define	D1D_CRI		4'b1100
`define	D1D_CRD		4'b1101
`define	D1D_MUL		4'b1110
`define	D1D_LEDS	4'b1111

`define	COM_NOP		3'b000
`define	COM_RF		3'b001
`define	COM_IMM		3'b010
`define	COM_PLO		3'b011
`define	COM_MEML	3'b100
`define	COM_INC		3'b101
`define	COM_DIFF	3'b110
`define	COM_BITS	3'b111


`timescale 1ns/100ps
module th_top (
	clock_i,
	reset_ni,
	enable_i,
	
	i_read_o,
	i_rack_i,
	i_ready_i,
	i_addr_o,
	i_data_i,
	
`ifdef __debug
	leds_o,
`endif
	
	m_read_o,
	m_write_o,
	m_rack_i,
	m_wack_i,
	m_ready_i,
	m_busy_i,
	m_addr_o,
	m_bes_ni,
	m_bes_no,
	m_data_i,
	m_data_o
);

parameter	ADDRESS		= 28;
parameter	INSTRUCTION	= 32;
parameter	WIDTH		= 18;
parameter	PAGEWIDTH	= 10;
parameter	TAGSIZE		= PAGEWIDTH - 3;
parameter	MEMSIZE		= 16;
parameter	MEMSIZELOG2	= 4;
parameter	BANKSLOG2	= 1;
parameter	DISTMEMSIZE	= MEMSIZE;

parameter	MSB	= WIDTH - 1;
parameter	ISB	= INSTRUCTION - 1;
parameter	ASB	= ADDRESS - 1;
parameter	TSB	= TAGSIZE - 1;
parameter	PSB	= PAGEWIDTH - 1;

input		clock_i;
input		reset_ni;
input		enable_i;

output		i_read_o;
input		i_rack_i;
input		i_ready_i;
output	[ASB:0]	i_addr_o;
input	[ISB:0]	i_data_i;

`ifdef __debug
output	[1:0]	leds_o;
`endif

output		m_read_o;
output		m_write_o;
input		m_rack_i;
input		m_wack_i;
input		m_ready_i;
input		m_busy_i;
output	[ASB:0]	m_addr_o;	// 1024 MB RAM!
input	[3:0]	m_bes_ni;
output	[3:0]	m_bes_no;
input	[31:0]	m_data_i;
output	[31:0]	m_data_o;


// Signals for the First pipeline stage.
wire	f_lookup, f_ack, f_busy, f_vld0, f_vld1, f_pre0, f_pre1;
wire	[TSB:0]	f_tag0, f_tag1;
wire	[PSB:0]	f_pc;

// Signals for the Second pipeline stage.
wire	s_lookup, s_packed, s_ack, s_hit, s_miss, s_busy, s_valid, s_nop;
wire	s_u_pack, s_update;
wire	[MEMSIZELOG2-1:0]	s_l_addr, s_u_addr;
wire	[PSB:0]	s_pc;
wire	[ISB-1:0]	s_instr;

// Signals for the Decode pipeline stage.
wire	d_packed;

// Signals for the Transport.
wire	t_packed, t_bra_imm, t_bra_reg, t_nop_n;
wire	[3:0]	t_rf_idx;
wire	[MSB:0]	t_immed;
wire	[ISB:0]	t_instr;

// Signals for branching, the same pipeline stage as Transport.
wire	b_update, b_lru, b_bank;
wire	[TSB:0]	b_newtag;

// TODO: Global stalling is too expensive.
wire	stall_n, mstall_n;	// FIXME
wire	mem_busy;		// TODO

reg	[MSB:0]	rseg	= 0;	// Memory segments (read/Write/Instruction)
reg	[MSB:0]	wseg	= 0;
reg	[MSB:0]	iseg	= 0;


assign	i_addr_o [ASB:PAGEWIDTH]	= iseg;	// TODO

assign	stall_n	= 1'b1;	// FIXME


//---------------------------------------------------------------------------
//  Stage I: Cache Lookup (F).
//
th_first #(
	.ADDRESS	(PAGEWIDTH)
) FETCH0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(1'b1),
	
	.br_lookup_i	(f_lookup),
	.br_pc_i	(f_pc),
	.br_ack_o	(f_ack),
	.br_busy_o	(f_busy),
	.br_vld0_i	(f_vld0),
	.br_tag0_i	(f_tag0),
	.br_pre0_i	(f_pre0),
	.br_vld1_i	(f_vld1),
	.br_tag1_i	(f_tag1),
	.br_pre1_i	(f_pre1),
	
	.is_lookup_o	(s_lookup),
	.is_ack_i	(s_ack),
	.is_l_addr_o	(s_l_addr),
	.is_packed_o	(s_packed),
	.is_busy_i	(s_busy),
	.is_pc_o	(s_pc),
	.is_hit_o	(s_hit),
	.is_miss_o	(s_miss),
	.is_hit_co	(),
	.is_miss_co	(),
	.is_update_i	(s_update),
	.is_u_addr_i	(s_u_addr),
	.is_packed_i	(s_u_pack)
);


//---------------------------------------------------------------------------
//  Stage II: Cache Instruction Fetch (S).
//
th_second #(
	.INSTRUCTION	(INSTRUCTION),
	.ADDRESS	(PAGEWIDTH)
) SECOND0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(1'b1),
	
	.m_read_o	(i_read_o),
	.m_rack_i	(i_rack_i),
	.m_ready_i	(i_ready_i),
	.m_addr_o	(i_addr_o [PSB:0]),
	.m_data_i	(i_data_i),
	
	.if_lookup_i	(s_lookup),
	.if_l_addr_i	(s_l_addr),
	.if_packed_i	(s_packed),
	.if_ack_o	(s_ack),
	.if_hit_i	(s_hit),
	.if_miss_i	(s_miss),
	.if_pc_i	(s_pc),
	.if_busy_o	(s_busy),
	.if_update_o	(s_update),
	.if_u_addr_o	(s_u_addr),
	.if_packed_o	(s_u_pack),
	
	.br_update_o	(b_update),
	.br_newtag_o	(b_newtag),
	.br_lru_o	(b_lru),
	.br_bank_o	(b_bank),
	
	.de_instr_o	(s_instr),
	.de_packed_o	(d_packed),
	.de_valid_o	(s_valid),
	.de_nop_o	(s_nop)
);


//---------------------------------------------------------------------------
//  Stage III: Instruction Decode (D).
//
th_decode DECODE (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(1'b1),
	
	.is_instr_i	({d_packed, s_instr}),
	.is_nop_i	(s_nop),
	
	.tr_packed_o	(t_packed),
	.tr_instr_o	(t_instr),
	.tr_immed_o	(t_immed),
	.tr_nop_no	(t_nop_n),
	.tr_rf_idx_o	(t_rf_idx),
	.tr_bra_imm_o	(t_bra_imm),
	.tr_bra_reg_o	(t_bra_reg)
);


//---------------------------------------------------------------------------
//  Stage IV: Branch/Transport (T).
//
wire		branch;

wire	[MSB:0]	dp0, dp1, com;
wire	[7:0]	com_src_sel, dp0_src_sel, dp0_dst_sel, dp1_src_sel;
wire	[15:0]	dp1_dst_sel;

wire	[2:0]	dp0_src	= t_instr [2:0];
wire	[2:0]	dp0_dst	= t_instr [5:3];
wire	[2:0]	dp1_src	= t_instr [8:6];
wire	[3:0]	dp1_dst	= t_instr [12:9];
wire	[2:0]	com_src	= t_instr [15:13];

reg	[MSB:0]	diff, crd;
wire	[MSB:0]	inc, prod_hi, prod_lo, memhi, memlo, bits;
wire	[PSB:0]	pc_next;
reg		zf;

reg	[3:0]	rf_wr_idx	= 0;
reg	[MSB:0]	rf [DISTMEMSIZE-1:0];
reg	[MSB:0]	rf_data;


// FIXME
assign	#3 branch	= ((zf && dp1_dst == `D1D_PCZ) || (!zf && dp1_dst == `D1D_PCNZ) || (dp1_dst == `D1D_PC)) && t_nop_n;


//  Register File
always @(posedge clock_i)
	if (t_nop_n)	rf_data	<= #2 rf [t_rf_idx];

always @(posedge clock_i)
	if (t_nop_n)	rf_wr_idx	<= #2 t_rf_idx;

wire	#2 rf_sel	= t_nop_n && dp0_dst_sel [`D0D_RF];
always @(posedge clock_i)
	if (rf_sel)	rf [rf_wr_idx]	<= #2 dp0;


th_branch BRANCH0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(1'b1),
	
	.tr_pc_next_o	(pc_next),
	
	.de_lookup_i	(s_valid),
	.de_nop_i	(s_nop),
	.de_ack_o	(),
	.de_bra_imm_i	(t_bra_imm),
	.de_bra_reg_i	(t_bra_reg),
	.de_pc_bra_i	(t_immed [PSB:0]),
	
	.if_lookup_o	(f_lookup),
	.if_ack_i	(f_ack),
	.if_packed_i	(s_packed),
	.if_hit_i	(s_hit),
	.if_miss_i	(s_miss),
	.if_pc_o	(f_pc),
	.if_pre0_o	(f_pre0),
	.if_tag0_o	(f_tag0),
	.if_vld0_o	(f_vld0),
	.if_pre1_o	(f_pre1),
	.if_tag1_o	(f_tag1),
	.if_vld1_o	(f_vld1),
	
	.is_busy_i	(0),
	.is_update_i	(b_update),
	.is_newtag_i	(b_newtag),
	.is_lru_i	(b_lru),
	.is_bank_i	(b_bank)
);


//---------------------------------------------------------------------------
// Two 8 to 8 TTA streams, and one 8 to 16 TTA stream.
//
wire	dp0_enable	= t_nop_n || (dp0_dst == `D0D_NOP);
tta_stream8to8_sync #(
	.WIDTH		(WIDTH)
) DP0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(dp0_enable),
	
	.src_i		(dp0_src),
	.dst_i		(dp0_dst),
	
	.data0_i	(com),
	.data1_i	(rf_data),
	.data2_i	(memhi),
	.data3_i	(diff),
	.data4_i	(t_immed),
	.data5_i	(bits),
	.data6_i	(0),	// FIXME
	.data7_i	({{(WIDTH-PAGEWIDTH){1'b0}}, pc_next}),
	
	.srcsels_o	(dp0_src_sel),
	.dstsels_o	(dp0_dst_sel),
	.data_o		(dp0)
);


wire	dp1_enable	= t_nop_n || (dp1_dst == `D1D_NOP);
tta_stream8to16_sync #(
	.WIDTH		(WIDTH)
) DP1 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(dp1_enable),
	
	.src_i		(dp1_src),
	.dst_i		(dp1_dst),
	
	.data0_i	(com),
	.data1_i	(rf_data),
	.data2_i	(memlo),
	.data3_i	(inc),
	.data4_i	(t_immed),
	.data5_i	(),
	.data6_i	(),
	.data7_i	(),
	
	.srcsels_o	(dp1_src_sel),
	.dstsels_o	(dp1_dst_sel),
	.data_o		(dp1)
);


tta_stream8to8_sync #(
	.WIDTH		(WIDTH)
) COM (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(t_nop_n),
	
	.src_i		(com_src),
	.dst_i		(0),
	
	.data0_i	(com),		// NOP
	.data1_i	(rf_data),
	.data2_i	(t_immed),
	.data3_i	(prod_lo),
	.data4_i	(memlo),
	.data5_i	(inc),
	.data6_i	(diff),
	.data7_i	(bits),
	
	.srcsels_o	(com_src_sel),
	.dstsels_o	(),
	.data_o		(com)
);


//---------------------------------------------------------------------------
//  Stage V:  CPU Functional Units.
//

//---------------------------------------------------------------------------
//  Functional units.
//
reg	x_nop_n	= 1'b0;

wire	inc_zeroset, inc_zeroclr;
wire	bit_zeroset, bit_zeroclr;


always @(posedge clock_i)
	if (!reset_ni)	x_nop_n	<= #2 1'b0;
	else		x_nop_n	<= #2 t_nop_n;


wire	#3 bits_sel	= (dp0_dst_sel [`D0D_AND] || dp0_dst_sel [`D0D_OR] || dp0_dst_sel [`D0D_XOR]) && x_nop_n;
tta_bitwise #(
	.WIDTH		(WIDTH)
) BIT0 (
	.clock_i	(clock_i),
	.enable_i	(bits_sel),
	.mode_i		(dp0_dst [1:0]),
	.data0_i	(dp0),
	.data1_i	(com),
	.zeroset_o	(bit_zeroset),
	.zeroclr_o	(bit_zeroclr),
	.data_o		(bits)
);


wire	#2 sub_sel	= x_nop_n && dp0_dst_sel [`D0D_SUB];
always @(posedge clock_i)
	if (sub_sel)
		diff	<= dp0 - com;


wire	#2 mul_sel	= x_nop_n && dp1_dst_sel [`D1D_MUL];
// `ifdef __icarus
wire signed	[MSB:0]	faca	= com;
wire signed	[MSB:0]	facb	= dp1;
reg signed	[MSB+WIDTH:0]	prod;
assign	{prod_hi, prod_lo}	= prod;
always @(posedge clock_i)
	if (mul_sel)	prod	<= faca * facb;
/*
`else
MULT18X18S mul0 (
	.C	(clock_i),
	.CE	(mul_sel),
	.R	(1'b0),
	.A	(com),
	.B	(dp0),
	.P	({prod_hi, prod_lo})
);
`endif
*/

wire	#2 inc_wr	= x_nop_n && dp1_dst_sel [`D1D_INC];
tta_inc #(
	.WIDTH		(WIDTH)
) INC0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(x_nop_n),
	
	.rd_sel_i	(0),
	.wr_sel_i	(inc_wr),
	.data_i		(dp1),
	.zeroset_o	(inc_zeroset),
	.zeroclr_o	(inc_zeroclr),
	.count_o	(inc)
);


// TODO: This controller sux, it is too slow and complicated.
wire	#2 rad_sel	= x_nop_n && dp1_dst_sel [`D1D_RAD];
wire	#2 wad_sel	= x_nop_n && dp0_dst_sel [`D0D_WAD];
wire	#2 whi_sel	= x_nop_n && dp0_dst_sel [`D0D_MEMH];
wire	#2 wlo_sel	= x_nop_n && dp1_dst_sel [`D1D_MEML];
wire	#2 rd_sel	= (dp0_src == `D0S_MEMH || dp1_src == `D1S_MEML || com_src == `COM_MEML);
// wire	#2 rd_sel	= (dp0_src_sel [`D0S_MEMH] || dp1_src_sel [`D1S_MEML] || com_src_sel [`COM_MEML]);
wire	[31:0]	rdata, wdata;
wire	[3:0]	rbes_n, wbes_n;
tta_mem32 #(
	.WIDTH		(32),
	.ADDRESS	(ADDRESS)
) MEM32 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(1'b1),
	
	.c_stall_no	(mstall_n),
	.c_busy_o	(mem_busy),
	
	.c_raddr_ti	(rad_sel),	// Trigger address register change
	.c_raddr_i	({rseg, dp1 [PSB:0]}),
	.c_rbes_no	(rbes_n),
	.c_rdata_ti	(rd_sel),
	.c_rdata_o	(rdata),
	
	.c_reglo_i	(wlo_sel),
	.c_reghi_i	(whi_sel),
	.c_waddr_ti	(wad_sel),
	.c_waddr_i	({wseg, dp0 [PSB:0]}),
	.c_wbes_ni	(wbes_n),
	.c_wdata_i	(wdata),
	
	.m_read_o	(m_read_o),
	.m_write_o	(m_write_o),
	.m_rack_i	(m_rack_i),
	.m_wack_i	(m_wack_i),
	.m_ready_i	(m_ready_i),
	.m_busy_i	(m_busy_i),
	.m_addr_o	(m_addr_o),
	.m_bes_no	(m_bes_no),
	.m_bes_ni	(m_bes_ni),
	.m_data_i	(m_data_i),
	.m_data_o	(m_data_o)
);


// Control registers.
reg	[1:0]	cri	= 0;
wire	#2 cri_sel	= x_nop_n && dp1_dst_sel [`D1D_CRI];
always @(posedge clock_i)
	if (!reset_ni)		cri	<= #2 0;
	else if (cri_sel)	cri	<= #2 dp1 [1:0];

wire	#2 crd_sel	= x_nop_n && dp1_dst_sel [`D1D_CRD];
always @(posedge clock_i)
	if (!reset_ni)
		{iseg, wseg, rseg}	<= #2 0;
	else if (crd_sel) case (cri)
		0:	iseg	<= #2 dp1;
		1:	rseg	<= #2 dp1;
		2:	wseg	<= #2 dp1;
	endcase


// LEDs as a functional unit, what more could one want?
reg	[1:0]	leds_o	= 0;
wire	#2 led_sel	= x_nop_n && dp1_dst_sel [`D1D_LEDS];
always @(posedge clock_i)
	if (!reset_ni)
		leds_o	<= #1 0;
	else if (led_sel)
		leds_o	<= #1 dp1 [1:0];


//---------------------------------------------------------------------------
//  Stage V:   CPU Update.
//


// TODO: A voting system?
// TODO: Multiple zero flags?
always @(posedge clock_i)
	if (!reset_ni)
		zf	<= 1;
	else if (x_nop_n) begin
		if (bit_zeroset || inc_zeroset)
			zf	<= 1;
		else if (bit_zeroclr || inc_zeroclr)
			zf	<= 0;
		else
			zf	<= zf;
	end


`ifdef __icarus
reg	[PSB:0]	pc2, pc1;
always @(posedge clock_i)
	if (!reset_ni)		{pc2, pc1}	<= #2 0;
	else if (x_nop_n)	{pc2, pc1}	<= #2 {pc1, f_pc};

always @(posedge clock_i)
	if (x_nop_n)	$display ("Executing: (%x) %x", pc2, t_instr);
`endif

`ifdef __icarus
integer	i;
initial	for (i=0; i<16; i=i+1)	rf [i]	= 0;
`endif


endmodule	// th_top
