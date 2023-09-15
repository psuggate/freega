/***************************************************************************
 *                                                                         *
 *   vga_tta_lowlat.v - A light-weight TTA CPU for converting VGA port     *
 *     accesses into external register values and vice versa.              *
 *                                                                         *
 *     This design of TTA is optimised for latency, not frequency.         *
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

// TODOs & FIXMEs:
// - Blocking memory reads?
// - Finish `newline' and `newpage' signals.
// - A bug (the state-machine is too slow) means that the CPU will skip an
//   instruction upon a cache-miss if the `hit_i' signal is de-asserted for
//   only one clock cycle. This should never happen anyway (unless there is
//   some cache prefetch logic).
// - Debug.
// - Fix CPU clock-gating.
// - A branch inhibit signal so that a second branch is not issued while the
//   first is still in progress.

`timescale 1ns/100ps

// Having the asynchronous RF (Register File) option set, the CPU can read a
// register from the RF one cycle earlier, ie. the next clock after a write.
// This changes the CPU bhaviour and assembly files produced for one machine
// won't run on the other. The disadvantage of async. operation is a slight
// reduction in CPU Fmax.
//`define	__async_RF

// The hybrid-PC increments like a normal counter within a cache-line, but
// like a LFSR when moving to the next cache-line.
`define	__hybrid_PC
`ifdef __hybrid_PC
`define	PC_INIT	16
`else
`ifdef __icarus
`define	PC_INIT	0
`else
`define	PC_INIT	1
`endif	// __icarus
`endif	// __hybrid_PC


// An alternate method of choosing bitwise operations. It should be faster,
// but it seems to be slightly slower and use slightly more resources.
//`define	__use_alt_bits

// A fast-branch that performs instant branches to addresses within the same
// cache-line. The downsides are: that it can only take branch addresses from
// the immediate field of the instruction; there is only the BRA and BNZ
// branch cases; and Fmax is slightly lower.
//`define	__fast_branch

// Special purpose registers.
// ALU0
`define	A0S_COM		2'b00
`define	A0S_RF0		2'b01
`define	A0S_INC		2'b10
`define	A0S_IMM		2'b11

`define	A0D_NOP		3'b000
`define	A0D_AND		3'b001
`define	A0D_OR		3'b010
`define	A0D_XOR		3'b011
`define	A0D_MUL		3'b100
`define	A0D_SUB		3'b101
`define	A0D_INC		3'b110
`define	A0D_DMUX	3'b111

// ALU1
`define	A1S_NOP		2'b00
`define	A1S_RF0		2'b01
`define	A1S_MOV		2'b10
`define	A1S_IMM		2'b11

`define	A1D_CRI		3'b000
`define	A1D_MOV		3'b001
`define	A1D_STORE	3'b010
`define	A1D_PC		3'b011
`define	A1D_CRD		3'b100
`define	A1D_MOVNZ	3'b101
`define	A1D_PCZ		3'b110
`define	A1D_PCNZ	3'b111

// COM
// TODO: Needs a NOP.
`define	COM_RF0		3'b000
`define	COM_BITS	3'b001
`define	COM_PLO		3'b010
`define	COM_PHI		3'b011
`define	COM_MOV		3'b100
`define	COM_DIFF	3'b101
`define	COM_DMUX	3'b110
`define	COM_CRD		3'b111

// WRRF (WRite Register File stream)
// TODO: Needs a NOP.
`define	WRS_COM		2'b00
`define	WRS_ALU0	2'b01
`define	WRS_LOAD	2'b10
`define	WRS_PC		2'b11


module vga_tta (
	clock_i,
	reset_ni,
	
	pc_o,
	hit_i,		// IFETCH enable?
	instr_i,
	
	newline_o,	// These are for cache/memory control
	newpage_o,
	
	m_read_o,	// External memory. When used as part of FreeGA, this
	m_write_o,	// is a MMIO block.
	m_ready_i,
	m_addr_o,
	m_data_i,
	m_data_o
);

parameter	AW	= 16;
parameter	IW	= 32;
parameter	AMSB	= AW-1;
parameter	IMSB	= IW-1;

parameter	IAMSB	= 8;
parameter	IWORDS	= 512;
parameter	MAMSB	= 3;
parameter	MDMSB	= 10;

input	clock_i;
input	reset_ni;

output	[AMSB:0]	pc_o;
input	hit_i;
input	[IMSB:0]	instr_i;

output	newline_o;
output	newpage_o;

output	m_read_o;
output	m_write_o;
input	m_ready_i;
output	[MAMSB:0]	m_addr_o;
input	[MDMSB:0]	m_data_i;
output	[MDMSB:0]	m_data_o;


// Stage I: IFETCH registers and wires.
//
reg	[31:0]	instr;

reg	[AMSB:0]	pc_o		= `PC_INIT;
reg	[6:0]		page_addr	= 0;	// Set by CPU flag

wire	branch;
wire	[8:0]	pc_branch, pc_next, pc;

`ifdef __hybrid_PC
wire	[3:0]	pc_lo;
wire	[4:0]	pc_hi;
wire	[4:0]	pc_mfsr;
`endif

reg	[IAMSB:0]	pc_ret;


// Stage II: DFETCH registers and wires.
//
// Register file. This will require 1 LUT/width-bit on a 4-input LUT
// architecture (like a Spartan III).
reg	[MDMSB:0]	rf[0:15];

// Sign extend immediate.
wire	[MDMSB:0]	immed	= {{(MDMSB-7){instr[31]}}, instr[30:23]};

// Instruction decode.
wire	[1:0]	alu0_src	= instr[1:0];
wire	[2:0]	alu0_dst	= instr[4:2];
wire	[1:0]	alu1_src	= instr[6:5];
wire	[2:0]	alu1_dst	= instr[9:7];
wire	[2:0]	com_src		= instr[12:10];
wire	[1:0]	wrrf_src	= instr[14:13];
wire	[3:0]	rfw_idx		= instr[18:15];

`ifdef __async_RF
// Register file read index.
wire	[3:0]	rf0_idx	= instr[22:19];
wire	[MDMSB:0]	rf0_data;
`else
// Start the read a cycle earlier than above.
wire	[3:0]	rf0_idx	= instr_i[22:19];
reg	[MDMSB:0]	rf0_data;
`endif

wire	[MDMSB:0]	flags;


// Stage III: MOVE0 registers and wires.
//
// Used for writes and destructive reads.
reg	move0_ce	= 0;	// Clock enable for stage II

reg	[3:0]	alu0_src_sel	= 0, alu1_src_sel	= 0, wrrf_src_sel	= 0;
reg	[7:0]	alu0_dst_sel	= 0, com_src_sel	= 0;	// 3 to 8 de-mux.
reg	[4:0]	alu1_dst_sel	= 0;

reg	[MDMSB:0]	alu0_data, alu1_data, com, rfw_data;

`ifndef __fast_branch
`define	BRST_IDLE	3'b000
`define	BRST_PAUSE	3'b001
`define	BRST_RESUME	3'b010
`define	BRST_HOLD	3'b100

reg	[2:0]		bra_state	= `BRST_IDLE;
wire	bra_pause;
`endif

wire	alu1_nop	= (alu1_src == 2'b00);


// Stage IV: MOVE1 registers and wires.
//
reg	move1_ce	= 0;

reg	[MDMSB:0]	bitwise, prod_hi, prod_lo, mdata, diff, dmux, inc, cmov;

reg	m_read_o	= 0, m_write_o	= 0;
reg	[MAMSB:0]	m_addr_o;
reg	[MDMSB:0]	m_data_o;


// Stage V: UPDATE registers and wires.
//
reg	update_ce	= 0;

// Global flags.
reg	flag_z	= 0;	// Zero flag
reg	flag_z_set	= 0, flag_z_clr	= 0;

reg	bit_flag_z_set	= 0, bit_flag_z_clr	= 0;
reg	bitwise_sel	= 0;

wire	bitsel_w;
wire	bitwise_zero_w;

reg	flag_m	= 0;	// Memory data present flag
reg	flag_m_set	= 0, flag_m_clr	= 0;	// Mem reads set flag

reg	flag_o	= 0;	// Overflow flag
reg	flag_o_set	= 0, flag_o_clr	= 0;

// Control registers.
reg	[2:0]		cri	= 0;
reg	[MDMSB:0]	crd;


assign	#1 flags	= {{(MDMSB-2){1'b0}}, flag_m, flag_o, flag_z};


// TODO: This whole section is horridly slow!
// Invalidate the current cache-line if:
// - The counter increases past 4'hF .
// - A branch to an address outside the current cache-line.
// - The current cache-line is invalidated by a page adddress change.
reg	newline_o	= 1;
reg	newpage_o	= 1;
reg	newpage		= 1;

wire	pc_oflow, bra_miss;

assign	#2 pc_oflow	= (pc_o[3:0] == 4'hF && !branch);
assign	#2 bra_miss	= ((pc_o[8:4] != alu1_data [8:4]) && branch);

always @(posedge clock_i) begin
	if (!reset_ni)
		newline_o	<= #1 1;
	else if (pc_oflow)
		newline_o	<= #1 1;
	else if (bra_miss)
		newline_o	<= #1 1;
	else if (newpage)
		newline_o	<= #1 1;
	else
		newline_o	<= #1 0;
end

always @(posedge clock_i) begin
	if (!reset_ni)
		newpage_o	<= #1 1;
	else
		newpage_o	<= #1 newpage;
end


//---------------------------------------------------------------------------
//  Stage I: IFETCH
//  Instruction fetch.
//
`ifdef __fast_branch
assign	pc_branch	= instr_i[31:23];
assign	#1 branch	= (instr_i[8:7] == `A1D_PC) && (!instr_i[9] || !flag_z);
assign	#1 pc		= branch ? pc_branch : pc_next;
`endif

always @(posedge clock_i) begin
	if (!reset_ni)
		pc_o	<= #1 `PC_INIT;
	else if (hit_i)	// CE
		pc_o	<= #1 {page_addr, pc};
end


// assign	#1 newline_o	= (pc_o[3:0] == 4'hF);

always @(posedge clock_i) begin
	if (hit_i)
		instr	<= #1 instr_i;
end


// Use one of Roy's h4x MFSRs for the PC when synthesising.
`ifdef __hybrid_PC
assign	#2 pc_lo	= pc_o[3:0] + 1;
assign	#2 pc_hi	= (pc_o[3:0] == 4'hF) ? pc_mfsr : pc_o[8:4];
assign	pc_next		= {pc_hi, pc_lo};

mfsr5 MFSR0 (
	.count_i	(pc_o [8:4]),
	.count_o	(pc_mfsr)
);
`else
`ifdef __icarus
assign	#2 pc_next	= pc_o + 1;
`else
mfsr9 MFSR0 (
	.count_i	(pc_o),
	.count_o	(pc_next)
);
`endif
`endif	// __hybrid_PC


// If instruction load from the cache was successful, decode this instruction
// next clock cycle.
always @(posedge clock_i) begin
	if (!reset_ni)
		move0_ce	<= #1 0;
	else
		move0_ce	<= #1 hit_i;
end


//---------------------------------------------------------------------------
//  Stage II: MOVE0
//  Instruction decode.  :)
//  Retreive data from the registers.
//

`ifdef __async_RF
assign	#1 rf0_data	= rf[rf0_idx];
`else
always @(posedge clock_i) begin
	if (hit_i)
		rf0_data	<= #1 rf[rf0_idx];
end
`endif

always @(posedge clock_i) begin
	if (move0_ce)
		pc_ret	<= #1 pc_next;
end


// Enable the next pipeline stage?
always @(posedge clock_i) begin
	if (!reset_ni)
		move1_ce	<= #1 0;
	else
		move1_ce	<= #1 move0_ce;
end


//---------------------------------------------------------------------------
//  Stage III: MOVE0
//  Move data into the ALU's data streams.
//

// PC update logic for slow branches.
// This is complicated since a cache-miss once a branch has been issued
// causes wierd effects.
// TODO: Clean this up!
`ifndef __fast_branch
assign	#1 bra_pause	= (!hit_i && alu1_dst_sel[`A1D_PC]);
assign	#1 branch	= ((hit_i && alu1_dst_sel[`A1D_PC]) || (bra_state == `BRST_RESUME) || (bra_state == `BRST_HOLD));
assign	#1 pc		= branch ? alu1_data : pc_next;

always @(posedge clock_i) begin
	if (!reset_ni)
		bra_state	<= #1 `BRST_IDLE;
	else case (bra_state)
		`BRST_IDLE: begin
			if (bra_pause && !move0_ce)
				bra_state	<= #2 `BRST_PAUSE;
			else if (bra_pause)
				bra_state	<= #2 `BRST_HOLD;
		end
		`BRST_PAUSE:	if (hit_i)	bra_state	<= #2 `BRST_RESUME;
		`BRST_RESUME:			bra_state	<= #2 `BRST_IDLE;
		`BRST_HOLD:	if (hit_i)	bra_state	<= #2 `BRST_IDLE;
	endcase
end
`endif


// ALU0.
always @(posedge clock_i) begin
	if (!move0_ce) begin
		alu0_src_sel	<= 0;
		alu0_dst_sel	<= 0;
	end
	else begin
		// FIXME: These source selects should happen 1-cycle earlier?
		case (alu0_src)
		0:	alu0_src_sel	<= #1 1;
		1:	alu0_src_sel	<= #1 2;
		2:	alu0_src_sel	<= #1 4;
		3:	alu0_src_sel	<= #1 8;
		endcase
		
		case (alu0_dst)
		0:	alu0_dst_sel	<= #1 1;
		1:	alu0_dst_sel	<= #1 2;
		2:	alu0_dst_sel	<= #1 4;
		3:	alu0_dst_sel	<= #1 8;
		4:	alu0_dst_sel	<= #1 16;
		5:	alu0_dst_sel	<= #1 32;
		6:	alu0_dst_sel	<= #1 64;
		7:	alu0_dst_sel	<= #1 128;
		endcase
	end
end

always @(posedge clock_i) begin
	if (move0_ce)
		case (alu0_src)
			2'b00:	alu0_data	<= #1 com;
			2'b01:	alu0_data	<= #1 rf0_data;	
			2'b10:	alu0_data	<= #1 inc;
			2'b11:	alu0_data	<= #1 immed;
		endcase
end


// ALU1.
always @(posedge clock_i) begin
	if (!move0_ce || alu1_nop) begin
		alu1_src_sel	<= #1 0;
		alu1_dst_sel	<= #1 0;
	end
	else begin
		case (alu1_src)
			0: alu1_src_sel	<= #1 1;
			1: alu1_src_sel	<= #1 2;
			2: alu1_src_sel	<= #1 4;
			3: alu1_src_sel	<= #1 8;
		endcase
		
		case (alu1_dst)
			0: alu1_dst_sel	<= #1 1;	// CRI
			1: alu1_dst_sel	<= #1 2;	// MOV
			2: alu1_dst_sel	<= #1 4;	// STORE
			3: alu1_dst_sel	<= #1 8;	// PC
			4: alu1_dst_sel	<= #1 16;	// CRD
			5: alu1_dst_sel	<= #2 !flag_z ?	2 : 0;	// MOVNZ
			6: alu1_dst_sel	<= #2 flag_z ?	8 : 0;	// PCZ
			7: alu1_dst_sel	<= #2 !flag_z ?	8 : 0;	// PCNZ
		endcase
	end
end


always @(posedge clock_i) begin
	if (move0_ce)
		case (alu1_src)
			2'b00:	alu1_data	<= #1 alu1_data;	// NOP
			2'b01:	alu1_data	<= #1 rf0_data;
			2'b10:	alu1_data	<= #1 cmov;
			2'b11:	alu1_data	<= #1 immed;
		endcase
end


// COM.
always @(posedge clock_i) begin
	if (!move0_ce)
		com_src_sel	<= #1 0;
	else begin
		// FIXME: These source selects should happen 1-cycle earlier?
		case (com_src)
			0:	com	<= #1 rf0_data;
			1:	com	<= #1 bitwise;
			2:	com	<= #1 prod_lo;
			3:	com	<= #1 prod_hi;
			4:	com	<= #1 cmov;
			5:	com	<= #1 diff;
			6:	com	<= #1 dmux;
			7:	com	<= #1 crd;
		endcase
		
		case (com_src)
			0:	com_src_sel	<= #1 1;
			1:	com_src_sel	<= #1 2;
			2:	com_src_sel	<= #1 4;
			3:	com_src_sel	<= #1 8;
			4:	com_src_sel	<= #1 16;
			5:	com_src_sel	<= #1 32;
			6:	com_src_sel	<= #1 64;
			7:	com_src_sel	<= #1 128;
		endcase
	end
end


// WRRF.
always @(posedge clock_i) begin
	if (!reset_ni || !move0_ce)
		wrrf_src_sel	<= #1 0;
	else case (wrrf_src)
			0: wrrf_src_sel	<= #1 1;
			1: wrrf_src_sel	<= #1 2;
			2: wrrf_src_sel	<= #1 4;
			3: wrrf_src_sel	<= #1 8;
		endcase
end

always @* begin
	case (wrrf_src)
		0: rfw_data	<= #1 com;
		1: rfw_data	<= #1 alu0_data;
		2: rfw_data	<= #1 mdata;	// LOAD
		3: rfw_data	<= #1 pc_ret;
	endcase
end


// Enable the next pipeline stage?
always @(posedge clock_i) begin
	if (!reset_ni)
		move1_ce	<= #1 0;
	else
		move1_ce	<= #1 move0_ce;
end


//---------------------------------------------------------------------------
//  Stage IV: MOVE1
//  Move data from the ALU data streams into the CPU's special registers
//  (functional units.
//

// The register-file (RF) write-back.
always @(posedge clock_i) begin
	if (move0_ce)
		rf[rfw_idx]	<= #1 rfw_data;
end


// [Read from | Write to] an external memory.
always @(posedge clock_i) begin
	if (!reset_ni) begin
		m_write_o	<= #1 0;
		m_read_o	<= #1 0;
	end
	else if (alu1_dst_sel[`A1D_STORE]) begin
		m_data_o	<= alu1_data;
		m_write_o	<= #1 1;
		m_read_o	<= #1 0;
	end
	else if (wrrf_src_sel[`WRS_LOAD] && !flag_m) begin
		m_write_o	<= #1 0;
		m_read_o	<= #1 1;
	end
	else begin
		m_write_o	<= #1 0;
		m_read_o	<= #1 0;
	end
end


// CPU Control Registers.
// 0 unused (for NOP)
// 1 CPU Flags
// 2 CPU page address
// 3 CPU segment address (TODO)
// 4 Memory lower address
// 5 Memory page address
// 6 Memory segment address
always @(posedge clock_i) begin
	if (!reset_ni) begin
		page_addr	<= #1 0;
		m_addr_o	<= #1 0;
	end
	else if (alu1_dst_sel[`A1D_CRD])
	case (cri)
		2:	page_addr	<= #1 alu1_data;
		4:	m_addr_o	<= #1 alu1_data;
	endcase
end

always @(posedge clock_i) begin
	if (!reset_ni)
		cri	<= #1 0;
	else if (alu1_dst_sel[`A1D_CRI])
		cri	<= #1 alu1_data;
end

always @(posedge clock_i) begin
	case (cri)
	0:	crd	<= #1 0;
	1:	crd	<= #1 flags;
	2:	crd	<= #1 page_addr;
	4:	crd	<= #1 m_addr_o;
	endcase
end

// When a new page address is set, invalidate the current cache-line.
always @(posedge clock_i) begin
	if (!reset_ni)
		newpage	<= #1 1;
	else if (cri == 2 && alu1_dst_sel[`A1D_CRD])
		newpage	<= #1 1;
	else
		newpage	<= #1 0;
end


// When `v_ready_i' asserts, set the processor flag.
always @(posedge clock_i) begin
	if (!reset_ni) begin
		flag_m_set	<= #1 0;
		flag_m_clr	<= #1 0;
	end
	else if (m_ready_i) begin
		mdata		<= m_data_i;
		
		flag_m_set	<= #1 1;
		flag_m_clr	<= #1 0;
	end
	else if (wrrf_src_sel[`WRS_LOAD]) begin
		flag_m_set	<= #1 0;
		flag_m_clr	<= #1 1;
	end
	else begin
		flag_m_set	<= #1 0;
		flag_m_clr	<= #1 0;
	end
end


// Bitwise operations functional unit.
// TODO: This can be optimised so that only one layer of logic is needed?
`ifdef __use_alt_bits
always @(posedge clock_i) begin
	if (alu0_dst_sel[`A0D_XOR])
		bitwise	<= #1 com ^ alu0_data;
	else if (alu0_dst_sel[`A0D_AND])
		bitwise	<= #1 com & alu0_data;
	else if (alu0_dst_sel[`A0D_OR])
		bitwise	<= #1 com | alu0_data;
	else
		bitwise	<= #1 ~com;
end

`else
// TODO: This actually seems to use more resources than the above.
reg	[1:0]	bit_mode	= 0;
always @(posedge clock_i) begin
	if (!reset_ni)
		bit_mode	<= #1 0;
	else case (alu0_dst)
		1: bit_mode	<= #1 1;
		2: bit_mode	<= #1 2;
		3: bit_mode	<= #1 3;
		default: bit_mode	<= #1 0;
	endcase
end

always @(posedge clock_i) begin
	case (bit_mode)
		0: bitwise	<= #1 ~com;
		1: bitwise	<= #1 com & alu0_data;
		2: bitwise	<= #1 com | alu0_data;
		3: bitwise	<= #1 com ^ alu0_data;
	endcase
end
`endif


// This sets the zero flag when a bitwise operation (excluding NOT) causes a
// zero output.
assign	#2 bitwise_zero_w	= (bitwise == 0) ? 1 : 0;
assign	#1 bitsel_w	= alu0_dst_sel[`A0D_XOR] | alu0_dst_sel[`A0D_AND] | alu0_dst_sel[`A0D_OR];

always @(posedge clock_i)
	bitwise_sel	<= #1 bitsel_w;

always @* begin
	if (!reset_ni) begin
		bit_flag_z_set	<= #1 0;
		bit_flag_z_clr	<= #1 0;
	end
	else if (bitwise_sel) begin
		bit_flag_z_set	<= #2 (bitwise == 0);
		bit_flag_z_clr	<= #2 (bitwise != 0);
	end
	else
		{bit_flag_z_set, bit_flag_z_clr}	<= #1 0;
end


// Multiplication functional unit.
always @(posedge clock_i) begin
	if (alu0_dst_sel[`A0D_MUL])
		{prod_hi, prod_lo}	<= #2 com * alu0_data;
end


// Subtraction functional unit.
always @(posedge clock_i) begin
	if (alu0_dst_sel[`A0D_SUB])
		diff	<= #3 com - alu0_data;
end


// Increment functional unit.
always @(posedge clock_i) begin
	if (alu0_dst_sel[`A0D_INC])
		inc	<= #2 alu0_data + 1;
end


// 4-to-11 de-multiplexer.
always @(posedge clock_i) begin
	case (alu0_data[3:0])
	0:	dmux	<= #2 1;
	1:	dmux	<= #2 2;
	2:	dmux	<= #2 4;
	3:	dmux	<= #2 8;
	4:	dmux	<= #2 16;
	5:	dmux	<= #2 32;
	6:	dmux	<= #2 64;
	7:	dmux	<= #2 128;
	8:	dmux	<= #2 256;
	9:	dmux	<= #2 512;
	10:	dmux	<= #2 1024;
	default:dmux	<= #2 0;
	endcase
end


// Conditional move register.
always @(posedge clock_i) begin
	if (alu1_dst_sel[`A1D_MOV])
		cmov	<= alu1_data;
end


// Enable the next pipeline stage?
always @(posedge clock_i) begin
	if (!reset_ni)
		update_ce	<= #1 0;
	else
		update_ce	<= #1 move1_ce;
end


//---------------------------------------------------------------------------
//  Stage V: UPDATE
//  This stage updates the machine state flags.
//

// The CPU flags can be set from many sources and are implemented as latches.
always @*
begin
	if (!reset_ni)
		flag_z	<= #2 0;
	else if (bit_flag_z_set && update_ce)
		flag_z	<= #2 1;
	else if (bit_flag_z_clr && update_ce)
		flag_z	<= #2 0;
	else
		flag_z	<= #2 flag_z;
end

always @*
begin
	if (!reset_ni)
		flag_o	<= #2 0;
	else if (flag_o_set && update_ce)
		flag_o	<= #2 1;
	else if (flag_o_clr && update_ce)
		flag_o	<= #2 0;
	else
		flag_o	<= #2 flag_o;
end

always @*
begin
	if (!reset_ni)
		flag_m	<= #2 0;
	else if (flag_m_set && update_ce)
		flag_m	<= #2 1;
	else if (flag_m_clr && update_ce)
		flag_m	<= #2 0;
	else
		flag_m	<= #2 flag_m;
end


endmodule	// vga_tta
