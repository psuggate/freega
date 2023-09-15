/***************************************************************************
 *                                                                         *
 *   tta_hybrid.v - A light-weight TTA CPU for converting VGA port         *
 *     accesses into external register values and vice versa. This is a    *
 *     mix of 32-bit and 16-bit functional units.                          *
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

`define	__debug


// ALU0
`define	D0S_COM		3'b000
`define	D0S_IMM		3'b001
`define	D0S_RF		3'b010
`define	D0S_INC		3'b011
`define	D0S_MEMH	3'b100
`define	D0S_DIFF	3'b101
`define	D0S_PLO		3'b110
`define	D0S_BITS	3'b111

`define	D0D_NOP		3'b000
`define	D0D_MUL		3'b001
`define	D0D_MEMH	3'b010
`define	D0D_INC		3'b011
`define	D0D_NOT		3'b100
`define	D0D_AND		3'b101
`define	D0D_OR		3'b110
`define	D0D_XOR		3'b111

// ALU1
`define	D1S_COM		3'b000
`define	D1S_IMM		3'b001
`define	D1S_RF		3'b010
`define	D1S_INC		3'b011
`define	D1S_MEML	3'b100
`define	D1S_DIFF	3'b101
`define	D1S_CRD		3'b110
`define	D1S_PC		3'b111

`define	D1D_NOP		4'b0000
`define	D1D_PC		4'b0001
`define	D1D_PCZ		4'b0010
`define	D1D_PCNZ	4'b0011
`define	D1D_WAD		4'b0100
`define	D1D_RAD		4'b0101
`define	D1D_CRI		4'b0110
`define	D1D_CRD		4'b0111

`define	D1D_RF		4'b1000
`define	D1D_RFZ		4'b1001
`define	D1D_RFNZ	4'b1010
`define	D1D_MEML	4'b1011
`define	D1D_SUB		4'b1100

`define	D1D_LEDS	4'b1111

// COM
`define	COM_NOP		3'b000
`define	COM_IMM		3'b001
`define	COM_RF		3'b010
`define	COM_DIFF	3'b011
`define	COM_MEML	3'b100
`define	COM_BITS	3'b101
`define	COM_PLO		3'b110
`define	COM_PHI		3'b111


`timescale 1ns/100ps
module tta_hybrid (
	clock_i,
	reset_ni,
	enable_i,
	
	i_read_o,
	i_mark_o,
	i_rack_i,
	i_mark_i,
	i_ready_i,
	i_addr_o,
	i_data_i,
	
	newline_o,	// These are for cache/memory control
	newpage_o,
	
`ifdef __debug
	leds_o,
`endif
	
	m_read_o,	// External memory. When used as part of FreeGA, this
	m_write_o,	// is a MMIO block.
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

parameter	WIDTH		= 18;
parameter	INSTRUCTION	= 32;
parameter	ADDRESS		= 28;
parameter	PAGEWIDTH	= 10;

parameter	MSB	= WIDTH - 1;
parameter	ISB	= INSTRUCTION - 1;
parameter	ASB	= ADDRESS - 1;
parameter	PSB	= PAGEWIDTH - 1;

input		clock_i;
input		reset_ni;
input		enable_i;

output		i_read_o;
output		i_mark_o;
input		i_rack_i;
input		i_mark_i;
input		i_ready_i;
output	[ASB:0]	i_addr_o;
input	[ISB:0]	i_data_i;

output		newline_o;
output		newpage_o;

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


// reg		i_read_o	= 1;
// reg	[ISB:0]	instr;
wire	[ISB:0]	instr;
wire	[PSB:0]	pc;
// reg	[PSB:0]	pc;
reg	[PSB:0]	rseg	= 0;
reg	[PSB:0]	wseg	= 0;
reg	[MSB:0]	page	= 0;

wire		stall_n, miss_n, mstall_n;
wire		branch, nop;
wire		mem_busy;
wire		sign;
wire	[MSB:0]	immed;

reg	[MSB:0]	diff;
wire	[MSB:0]	prod_lo, prod_hi, inc, bits, memlo, memhi, crd;

reg	[MSB:0]	rf_data;
reg	[MSB:0]	rf [15:0];
wire	[3:0]	rf_idx;

wire	[2:0]	dp0_src	= instr [2:0];
wire	[2:0]	dp0_dst	= instr [5:3];
wire	[2:0]	dp1_src	= instr [8:6];
wire	[3:0]	dp1_dst	= instr [12:9];
wire	[2:0]	com_src	= instr [15:13];

wire	[7:0]	dp0_src_sel, dp0_dst_sel, dp1_src_sel, com_src_sel;
wire	[15:0]	dp1_dst_sel;
wire	[MSB:0]	dp0, dp1, com;

wire	[3:0]	wbes_n	= {dp0 [MSB:MSB-1], dp1 [MSB:MSB-1]};
wire	[31:0]	wdata	= {dp0 [15:0], dp1 [15:0]};
wire	[3:0]	rbes_n;
wire	[31:0]	rdata;

reg	zf	= 1;
wire	bit_zeroset, bit_zeroclr, inc_zeroset, inc_zeroclr;


assign	sign	= instr [31];
assign	immed	= {{(WIDTH-11){sign}}, instr [30:20]};

assign	memhi	= {rbes_n [3:2], rdata [31:16]};
assign	memlo	= {rbes_n [1:0], rdata [15:0]};

assign	stall_n	= ~nop;

//---------------------------------------------------------------------------
//  Stage I:   CPU Bubble Logic & Instruction Fetch.
//


tta_fetch #(
	.INSTRUCTION	(INSTRUCTION),
	.ADDRESS	(PAGEWIDTH)
) FETCH0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
// 	.i_read_o	(i_read_o),	// To/from instr. cache
	.i_mark_o	(i_mark_o),
	.i_rack_i	(i_rack_i),
	.i_mark_i	(i_mark_i),
	.i_ready_i	(i_ready_i),
	.i_addr_o	(pc),
	.i_data_i	(i_data_i),
	
	.s2_branch_i	(branch),	// To/from stage II of the CPU pipeline
	.s2_baddr_i	(immed [PSB:0]),
	.s2_nop_o	(nop),
	.s2_instr_o	(instr)
);


ifetch IFETCH0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.next_packed_i	(1'b0),
// 	.next_packed_i	(i_data_i [31]),
	.mem_stall_i	(1'b0),
	.fetch_o	(i_read_o),
	.ready_i	(i_ready_i),
	.rack_i		(i_rack_i),
	
	.full_o		()
);


//---------------------------------------------------------------------------
//  Stage II:  CPU Data Fetch and Branch Logic.
//

assign	i_addr_o	= {page, pc};
assign	#3 branch	= ((zf && dp1_dst == `D1D_PCZ) || (!zf && dp1_dst == `D1D_PCNZ) || (dp1_dst == `D1D_PC));// && stall_n;

wire	[2:0] dp0_src_w	= i_data_i [2:0];
wire	[2:0] dp0_dst_w	= i_data_i [5:3];
wire	[2:0] dp1_src_w	= i_data_i [8:6];
wire	[2:0] dp1_dst_w	= i_data_i [12:9];
wire	[2:0] com_src_w	= i_data_i [15:13];
/*
wire	mem_busy, ilatch;
wire	#2 mem_op	= (dp0_dst_w == `D0D_MEMH) || (dp0_src_w == `D0S_MEMH) || (dp1_dst_w == `D1D_MEML) || (dp1_src_w == `D1S_MEML) || (com_src_w == `COM_MEML);
tta_pc #(
	.WIDTH		(PAGEWIDTH),
	.INIT		(0)
) PC0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(1'b1),
	
	.pc_o		(pc),
	.pc_i		(immed [PSB:0]),
	.fetch_o	(i_read_o),
	.latch_o	(ilatch),
	.ack_i		(i_rack_i),
	.hit_i		(i_ready_i),
	
	.branch_i	(branch),
	.memop_i	(mem_op),
	.mbusy_i	(mem_busy),	// Components that can stall the pipeline.
	
	.stall_no	(stall_n)
);

always @(posedge clock_i)
// 	instr	<= #2 i_data_i;
	if (ilatch)	instr	<= #2 i_data_i;
*/

//---------------------------------------------------------------------------
//  Register File
//
assign	rf_idx	= i_data_i [19:16];
`ifdef __icarus
integer	i;
initial	for (i=0; i<16; i=i+1)	rf [i]	= 0;
`endif
always @(posedge clock_i)
	if (stall_n)	rf_data	<= #2 rf [rf_idx];

reg	[3:0]	rf_widx;
always @(posedge clock_i)
	if (stall_n)	rf_widx	<= #2 instr [19:16];

wire	#2 rf_sel	= stall_n && dp1_dst_sel [`D1D_RF];
always @(posedge clock_i)
	if (rf_sel)	rf [rf_widx]	<= #2 dp1;


//---------------------------------------------------------------------------
//  Stage III: CPU Transport
//

//---------------------------------------------------------------------------
// Two 8 to 8 TTA streams, and one 8 to 16 TTA stream.
//
tta_stream8to8_sync #(
	.WIDTH		(WIDTH)
) DP0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(stall_n),
	
	.src_i		(dp0_src),
	.dst_i		(dp0_dst),
	
	.data0_i	(com),
	.data1_i	(immed),
	.data2_i	(rf_data),
	.data3_i	(inc),
	.data4_i	(memhi),
	.data5_i	(diff),
	.data6_i	(prod_lo),
	.data7_i	(bits),
	
	.srcsels_o	(dp0_src_sel),
	.dstsels_o	(dp0_dst_sel),
	.data_o		(dp0)
);


tta_stream8to16_sync #(
	.WIDTH		(WIDTH)
) DP1 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(stall_n),
	
	.src_i		(dp1_src),
	.dst_i		(dp1_dst),
	
	.data0_i	(com),
	.data1_i	(immed),
	.data2_i	(rf_data),
	.data3_i	(inc),
	.data4_i	(memlo),
	.data5_i	(diff),
	.data6_i	(crd),
	.data7_i	({{(WIDTH-PAGEWIDTH){1'b0}}, pc}),
	
	.srcsels_o	(dp1_src_sel),
	.dstsels_o	(dp1_dst_sel),
	.data_o		(dp1)
);


tta_stream8to8_sync #(
	.WIDTH		(WIDTH)
) COM (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(stall_n),
	
	.src_i		(com_src),
	.dst_i		(0),
	
	.data0_i	(com),		// NOP
	.data1_i	(immed),
	.data2_i	(rf_data),
	.data3_i	(diff),
	.data4_i	(memlo),
	.data5_i	(bits),
	.data6_i	(prod_lo),
	.data7_i	(prod_hi),
	
	.srcsels_o	(com_src_sel),
	.dstsels_o	(),
	.data_o		(com)
);


//---------------------------------------------------------------------------
//  Stage IV:  CPU Functional Unit Trigger.
//

//---------------------------------------------------------------------------
//  Functional units.
//
wire	#3 bits_sel	= (dp0_dst_sel [`D0D_AND] || dp0_dst_sel [`D0D_OR] || dp0_dst_sel [`D0D_XOR] || dp0_dst_sel [`D0D_NOT]) && stall_n;
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


wire	#2 sub_sel	= stall_n && dp1_dst_sel [`D1D_SUB];
always @(posedge clock_i)
	if (sub_sel)
		diff	<= com - dp0;


wire	#2 mul_sel	= stall_n && dp0_dst_sel [`D0D_MUL];
// `ifdef __icarus
wire signed	[MSB:0]	faca	= com;
wire signed	[MSB:0]	facb	= dp0;
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

wire	#2 inc_wr	= stall_n && dp0_dst_sel [`D0D_INC];
tta_inc #(
	.WIDTH		(WIDTH)
) INC0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(stall_n),
	
	.rd_sel_i	(0),
	.wr_sel_i	(inc_wr),
	.data_i		(dp0),
	.zeroset_o	(inc_zeroset),
	.zeroclr_o	(inc_zeroclr),
	.count_o	(inc)
);


wire	#2 rad_sel	= stall_n && dp1_dst_sel [`D1D_RAD];
wire	#2 wad_sel	= stall_n && dp1_dst_sel [`D1D_WAD];
wire	#2 whi_sel	= stall_n && dp0_dst_sel [`D0D_MEMH];
wire	#2 wlo_sel	= stall_n && dp1_dst_sel [`D1D_MEML];
wire	#2 rd_sel	= (dp0_src == `D0S_MEMH || dp1_src == `D1S_MEML || com_src == `COM_MEML);
// wire	#2 rd_sel	= (dp0_src_sel [`D0S_MEMH] || dp1_src_sel [`D1S_MEML] || com_src_sel [`COM_MEML]);
tta_mem32 #(
	.WIDTH		(32),
	.ADDRESS	(ADDRESS)
) MEM0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(1'b1),
	
	.c_stall_no	(mstall_n),
	.c_busy_o	(mem_busy),
	
	.c_raddr_ti	(rad_sel),	// Trigger address register change
	.c_raddr_i	({rseg, dp1}),
	.c_rbes_no	(rbes_n),
	.c_rdata_ti	(rd_sel),
	.c_rdata_o	(rdata),
	
	.c_reglo_i	(wlo_sel),
	.c_reghi_i	(whi_sel),
	.c_waddr_ti	(wad_sel),
	.c_waddr_i	({wseg, dp1}),
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
wire	#2 cri_sel	= stall_n && dp1_dst_sel [`D1D_CRI];
always @(posedge clock_i)
	if (!reset_ni)		cri	<= #2 0;
	else if (cri_sel)	cri	<= #2 dp1 [1:0];

wire	#2 crd_sel	= stall_n && dp1_dst_sel [`D1D_CRD];
always @(posedge clock_i)
	if (!reset_ni)
		{page, wseg, rseg}	<= #2 0;
	else if (crd_sel) case (cri)
		0:	page	<= #2 dp1;
		1:	rseg	<= #2 dp1 [PSB:0];
		2:	wseg	<= #2 dp1 [PSB:0];
	endcase


// LEDs as a functional unit, what more could one want?
reg	[1:0]	leds_o	= 0;
wire	#2 led_sel	= stall_n && dp1_dst_sel [`D1D_LEDS];
always @(posedge clock_i)
	if (!reset_ni)
		leds_o	<= #1 0;
	else if (led_sel)
		leds_o	<= #1 dp1 [1:0];


//---------------------------------------------------------------------------
//  Stage V:   CPU Update.
//


// TODO: A voting system?
always @(posedge clock_i)
	if (!reset_ni)
		zf	<= 1;
	else if (stall_n) begin
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
	else if (stall_n)	{pc2, pc1}	<= #2 {pc1, pc};

always @(posedge clock_i)
	if (stall_n)	$display ("Executing: (%x) %x", pc2, instr);
`endif


endmodule	// tta_hybrid


/*
// The goal is to have two instruction-word fetches outstanding. But this can
// be upto four instructions.
module th_decode (
	clock_i,
	reset_ni,
	
	valid_i,
	instr_i,
	
	fetch_o,
	valid_o;
	instr_o,
	rf_ad_o,
	branch_o
);

parameter	WIDTH	= 32;
parameter	BUBBLE	= 0;

parameter	MSB	= WIDTH - 1;

input	clock_i;
input	reset_ni;

input		valid_i;
input	[MSB:0]	instr_i;

output		fetch_o;
// input		ack_i;
output		valid_o;
output	[MSB:0]	instr_o;
output	[3:0]	rf_ad_o;	// Combinatorial
output		branch_o;


reg	[MSB:0]	this_instr, next_instr;
reg	valid_o	= 0;


assign	instr_o	= this_instr;


always @(posedge clock_i)
	if (!reset_ni)	valid_o	<= #2 0;
	else		valid_o	<= #2 valid_i;


always @(posedge clock_i)
	if (!reset_ni)
		instr_o	<= #2 BUBBLE;
	else if (valid_i && fetch_o) begin
		if (instr_i [MSB]) begin
			// Decode packed instruction
			
		end else
			instr_o	<= #2 instr_i;
	end else
		instr_o	<= #2 BUBBLE;


th_unpack UNPACK0 (
	.instr_i	(instr_i),
	.instr0_o	(instr0),
	.instr1_o	(instr1)
);


// th_unpack2 UNPACK0 (
// 	.instr_i	(instr_i),
// 	.sel_i		(select),
// 	.instr_o	(instr)
// );


endmodule	// th_decode


module th_unpack (
	instr_i,
	instr0_o,
	instr1_o,
);

input	[31:0]	instr_i;
output	[30:0]	instr0_o;
output	[30:0]	instr1_o;


wire		p;
wire	[31:0]	i	= instr_i;

wire		sign;
wire	[9:0]	immed;

wire	[2:0]	s00, d00, s01, com0;
wire	[3:0]	d01, r0;
wire	[2:0]	s10, d10, s11, com1;
wire	[3:0]	d11, r1;


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


assign	instr0_o	= {r0, com0, d01, s01, d00, s00};
assign	instr1_o	= {r1, com1, d11, s11, d10, s10};


endmodule	// th_unpack


module th_unpack2 (
	instr_i,
	sel_i,
	instr_o,
);

input	[31:0]	instr_i;
input		sel_i,
output	[30:0]	instr_o;


wire		p;
wire	[31:0]	i	= instr_i;

wire		sign;
wire	[9:0]	immed;

wire	[2:0]	s00, d00, s01, com0;
wire	[3:0]	d01, r0;
wire	[2:0]	s10, d10, s11, com1;
wire	[3:0]	d11, r1;


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


assign	instr0	= {r0, com0, d01, s01, d00, s00};
assign	instr1	= {r1, com1, d11, s11, d10, s10};

assign	#2 instr_o	= sel_i ? instr1 : instr0 ;


endmodule	// th_unpack2
*/
