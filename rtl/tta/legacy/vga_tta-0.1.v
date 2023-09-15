/***************************************************************************
 *                                                                         *
 *   vga_tta.v - A light-weight TTA CPU for converting VGA port accesses   *
 *     into external register values and vice versa.                       *
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

// Special purpose registers.
// ALU0
`define	A0S_COM		2'b00
`define	A0S_RF0		2'b01
`define	A0S_BITS	2'b10
`define	A0S_IMM		2'b11

`define	A0D_COM		3'b000
`define	A0D_XOR		3'b001
`define	A0D_AND		3'b010
`define	A0D_OR		3'b011
`define	A0D_SUB		3'b100
`define	A0D_DMUX	3'b101
`define	A0D_ADDR	3'b110
`define	A0D_CMOV	3'b111

// ALU1
`define	A1S_PLO		2'b00
`define	A1S_PHI		2'b01
`define	A1S_DMUX	2'b10
`define	A1S_RF1		2'b11

`define	A1D_COM		2'b00
`define	A1D_PUT		2'b01
`define	A1D_STORE	2'b10
`define	A1D_MUL		2'b11

// ALU2
`define	A2S_COM		2'b00
`define	A2S_INC		2'b01
`define	A2S_FLAGS	2'b10
`define	A2S_PC		2'b11

`define	A2D_COM		2'b00
`define	A2D_INC		2'b01
`define	A2D_FLAGS	2'b10
`define	A2D_BRA		2'b11

// WRRF (WRite Register File stream)
`define	WRS_COM		2'b00
`define	WRS_GET		2'b01
`define	WRS_LOAD	2'b10
`define	WRS_DIFF	2'b11


module vga_tta (
	clock_i,
	reset_ni,
	
	i_read_i,	// Instruction data from the PCI bus
	i_write_i,
	i_ready_o,
	i_addr_i,
//	i_bes_ni,
	i_data_i,
	i_data_o,
	
	p_pres_i,	// Port data from the PCI bus
	p_ack_o,
	p_data_i,
	p_send_o,
	p_data_o,
	
	v_read_o,	// VGA data to the vga contoller
	v_write_o,
	v_ready_i,
	v_addr_o,
	v_data_i,
	v_data_o
);


parameter	IAMSB	= 8;
parameter	IWORDS	= 512;
parameter	VAMSB	= 3;
parameter	VDMSB	= 10;
parameter	PCMSB	= IAMSB;

input	clock_i;
input	reset_ni;

input	i_read_i;
input	i_write_i;
output	i_ready_o;
input	[IAMSB:0]	i_addr_i;
//input	[3:0]	i_bes_ni;
input	[35:0]	i_data_i;
output	[35:0]	i_data_o;

input	p_pres_i;	// Port data present
output	p_ack_o;
input	[7:0]	p_data_i;
output	p_send_o;
output	[7:0]	p_data_o;

output	v_read_o;
output	v_write_o;
input	v_ready_i;
output	[VAMSB:0]	v_addr_o;
input	[VDMSB:0]	v_data_i;
output	[VDMSB:0]	v_data_o;


reg	i_ready_o	= 0;
reg	[35:0]	i_data_o;

reg	[35:0]	instr;
reg	[PCMSB:0]	pc_reg, pc_branch;
reg	branch	= 0;

reg	flag_z	= 0;	// The only global CPU flag
reg	flag_z_set	= 0, flag_z_clr	= 0;

reg	bit_flag_z_set	= 0, bit_flag_z_clr	= 0;
reg	bitwise_sel	= 0;

wire	bitsel_w;
wire	bitwise_zero_w;

reg	flag_v	= 0;
reg	flag_v_set	= 0, flag_v_clr	= 0;	// VGA mem reads set flag

reg	flag_p	= 0;
reg	flag_p_set	= 0, flag_p_clr	= 0;	// Port reads can set flag

reg	[VDMSB:0]	com;	// The common register for ALU operations

// This is basically just an extra layer of registers after the block RAM
// so it can clock faster.
reg	[2:0]	alu0_dst;
reg	[1:0]	alu0_src, alu1_src, alu1_dst, alu2_src, alu2_dst, wrrf_src;
reg	[3:0]	rf0_idx, rf1_idx, rf2_idx;
reg	[VDMSB:0]	rf0_data, rf1_data, rf2_data;
reg	[VDMSB:0]	alu0_data, alu1_data, alu2_data, wr_data;
reg	[VDMSB:0]	immed;

// Used for writes and destructive reads.
reg	[3:0]	alu0_src_sel	= 0, alu1_src_sel	= 0, alu2_src_sel	= 0;
reg	[7:0]	alu0_dst_sel	= 0;	// 3 to 8 de-mux.
reg	[3:0]	alu1_dst_sel	= 0, alu2_dst_sel	= 0, wrrf_src_sel	= 0;

reg	pdata_pres	= 0;
reg	[7:0]	pdata;

reg	v_read_o	= 0, v_write_o	= 0;
reg	[VAMSB:0]	v_addr_o;
reg	[VDMSB:0]	v_data_o;

reg	[VDMSB:0]	bitwise, prod_hi, prod_lo, vdata, diff, dmux, inc;

wire	[PCMSB:0]	pc;

// These are the sources and destinations of register moves. These are broken
// out as wires so that the `KEEP' constraint can be applied to them.
wire	[1:0]	alu0_src_w	= instr[1:0];
wire	[2:0]	alu0_dst_w	= instr[4:2];

wire	[1:0]	alu1_src_w	= instr[6:5];
wire	[1:0]	alu1_dst_w	= instr[8:7];

wire	[1:0]	alu2_src_w	= instr[10:9];
wire	[1:0]	alu2_dst_w	= instr[12:11];

wire	[1:0]	wrrf_src_w	= instr[14:13];

// Register file read/write indices.
wire	[3:0]	rf0_idx_w	= instr[18:15];
wire	[3:0]	rf1_idx_w	= instr[22:19];
wire	[3:0]	rf2_idx_w	= instr[26:23];

// Immediates used for branching and loading.
wire	[PCMSB:0]	branch_addr	= instr[35:27];
wire	[VDMSB:0]	immed_w		= {{(VDMSB-7){instr[35]}}, instr[34:27]};

// A 2kB chunk of block RAM for instructions.
reg	[35:0]	iram [0:IWORDS-1];


assign	pc	= branch ? pc_branch : pc_reg;

//assign	p_ack_o	= 

// Instruction fetch.
always @(posedge clock_i)
	instr	<= iram [pc];


// Instruction decode.  :)
always @(posedge clock_i) begin
	alu0_src	<= alu0_src_w;
	alu0_dst	<= alu0_dst_w;
	alu1_src	<= alu1_src_w;
	alu1_dst	<= alu1_dst_w;
	alu2_src	<= alu2_src_w;
	alu2_dst	<= alu2_dst_w;
	wrrf_src	<= wrrf_src_w;
	
	immed		<= immed_w;
end


// Use one of Roy's h4x MFSRs for the PC when synthesising.
wire	[8:0]	next_pc;
`ifdef __icarus
assign	next_pc	= pc + 1;
`else
mfsr9 MFSR0 (
	.count_i	(pc),
	.count_o	(next_pc)
);
`endif

// Branch control logic.
always @(posedge clock_i) begin
	if (!reset_ni) begin
		pc_branch	<= 1;
		pc_reg		<= 1;
		branch		<= 0;
	end else
	begin
		pc_reg		<= next_pc;
		pc_branch	<= branch_addr;
		branch		<= (!flag_z && (alu2_dst == `A2D_BRA));
	end
end


// Register file. This will require 4 LUTs/bit on a 4-input LUT architecture.
reg	[VDMSB:0]	rf [0:15];
always @(posedge clock_i) begin
	rf [rf2_idx]	<= wr_data;
	
	rf0_idx		<= rf0_idx_w;
	rf1_idx		<= rf1_idx_w;
	rf2_idx		<= rf2_idx_w;
	
	rf0_data	<= rf [rf0_idx];
	rf1_data	<= rf [rf1_idx];
	rf2_data	<= rf [rf2_idx];
end


// The CPU flags can be set from many sources and are implemented as latches.
always @(bit_flag_z_set, bit_flag_z_clr, reset_ni) begin
	if (!reset_ni)
		flag_z	<= 0;
	else if (bit_flag_z_set)
		flag_z	<= 1;
	else if (bit_flag_z_clr)
		flag_z	<= 0;
	else
		flag_z	<= flag_z;
end

always @(flag_p_set, flag_p_clr, reset_ni) begin
	if (!reset_ni)
		flag_p	<= 0;
	else if (flag_p_set)
		flag_p	<= 1;
	else if (flag_p_clr)
		flag_p	<= 0;
	else
		flag_p	<= flag_p;
end

always @(flag_v_set, flag_v_clr, reset_ni) begin
	if (!reset_ni)
		flag_v	<= 0;
	else if (flag_v_set)
		flag_v	<= 1;
	else if (flag_v_clr)
		flag_v	<= 0;
	else
		flag_v	<= flag_v;
end


//---------------------------------------------------------------------------
// ALU instruction streams.
//

// ALU0.
always @(posedge clock_i) begin
	if (!reset_ni)
		alu0_dst_sel	<= 0;
	else case (alu0_dst)
		0:	alu0_dst_sel	<= 1;
		1:	alu0_dst_sel	<= 2;
		2:	alu0_dst_sel	<= 4;
		3:	alu0_dst_sel	<= 8;
		4:	alu0_dst_sel	<= 16;
		5:	alu0_dst_sel	<= 32;
		6:	alu0_dst_sel	<= 64;
		7:	alu0_dst_sel	<= 128;
	endcase
end

always @(posedge clock_i) begin
	if (!reset_ni)
		alu0_src_sel	<= 0;
	else case (alu0_src)
		2'b00: begin
			alu0_data	<= com;
			alu0_src_sel	<= 1;
		end
		
		2'b01:	begin
			alu0_data	<= rf0_data;	// Load from the RF0
			alu0_src_sel	<= 2;
		end
		
		2'b10:	begin
			alu0_data	<= bitwise;
			alu0_src_sel	<= 4;
		end
		
		2'b11:	begin
			alu0_data	<= immed;
			alu0_src_sel	<= 8;
		end
	endcase
end


// ALU1.
always @(posedge clock_i) begin
	if (!reset_ni)
		alu1_dst_sel	<= 0;
	else case (alu1_dst)
		0:	alu1_dst_sel	<= 1;
		1:	alu1_dst_sel	<= 2;
		2:	alu1_dst_sel	<= 4;
		3:	alu1_dst_sel	<= 8;
	endcase
end

always @(posedge clock_i) begin
	if (!reset_ni)
		alu1_src_sel	<= 0;
	else case (alu1_src)
		2'b00:	begin
			alu1_data	<= prod_lo;
			alu1_src_sel	<= 1;
		end
		
		2'b01:	begin
			alu1_data	<= prod_hi;
			alu1_src_sel	<= 2;
		end
		
		2'b10:	begin
			alu1_data	<= dmux;
			alu1_src_sel	<= 4;
		end
		
		2'b11:	begin
			alu1_data	<= rf1_data;
			alu1_src_sel	<= 8;
		end
	endcase
end


// ALU2.
always @(posedge clock_i) begin
	if (!reset_ni)
		alu2_dst_sel	<= 0;
	else case (alu2_dst)
		0:	alu2_dst_sel	<= 1;
		1:	alu2_dst_sel	<= 2;
		2:	alu2_dst_sel	<= 4;
		3:	alu2_dst_sel	<= 8;
	endcase
end

always @(posedge clock_i) begin
	if (!reset_ni)
		alu2_src_sel	<= 0;
	else case (alu2_src)
		2'b00:	begin
			alu2_data	<= com;
			alu2_src_sel	<= 1;
		end
		
		2'b01:	begin
			alu2_data	<= inc;
			alu2_src_sel	<= 2;
		end
		
		2'b10:	begin
			alu2_data	<= {{(VDMSB-2){1'b0}}, {flag_p, flag_v, flag_z}};
			alu2_src_sel	<= 4;
		end
		
		2'b11:	begin
			alu2_data	<= pc;	// Store PC when branching
			alu2_src_sel	<= 8;
		end
	endcase
end


// WRR.
always @(posedge clock_i) begin
	if (!reset_ni)
		wrrf_src_sel	<= 0;
	else case (wrrf_src)
		0:	begin
			wrrf_src_sel	<= 1;
			wr_data		<= com;
		end
		
		1:	begin
			wrrf_src_sel	<= 2;
			wr_data		<= pdata;	// GET
		end
		
		2:	begin
			wrrf_src_sel	<= 4;
			wr_data		<= vdata;	// LOAD
		end
		
		3:	begin
			wrrf_src_sel	<= 8;
			wr_data		<= diff;
		end
	endcase
end


// The `COM' register is used by the ALU. ALU0 stream takes priority, then
// ALU1.
always @(posedge clock_i) begin
	if (alu0_dst_sel[`A0D_CMOV] && !flag_z)
		com	<= alu0_data;
	else if (alu0_dst_sel[`A0D_COM])
		com	<= alu0_data;
	else if (alu1_dst_sel[`A1D_COM])
		com	<= alu1_data;
	else if (alu2_dst_sel[`A2D_COM])
		com	<= alu2_data;
	else
		com	<= com;
end


//---------------------------------------------------------------------------
// Functional units.
//

assign	p_ack_o	= flag_p_set;

// When port data is present on the inputs, register it. When this port is
// read, set the CPU flag if data is present.
always @(posedge clock_i) begin
	if (!reset_ni) begin
		pdata_pres	<= 0;
		
		flag_p_set	<= 0;
		flag_p_clr	<= 0;
	end
	else if (p_pres_i) begin
		pdata_pres	<= 1;
		pdata		<= p_data_i;
		
		flag_p_set	<= 0;
		flag_p_clr	<= 0;
	end
	else if (wrrf_src_sel[`WRS_GET]) begin	// Reg. read
		pdata_pres	<= 0;
		
		flag_p_set	<= pdata_pres;	// Control the setting/
		flag_p_clr	<= ~pdata_pres;	// clearing of the CPU flag.
	end
	else begin
		flag_p_set	<= 0;
		flag_p_clr	<= 0;
	end
end


// [Read from | Write to] an external memory.
always @(posedge clock_i) begin
	if (!reset_ni) begin
		v_write_o	<= 0;
		v_read_o	<= 0;
	end
	else if (alu1_dst_sel[`A1D_STORE]) begin
		v_data_o	<= alu1_data;
		v_write_o	<= 1;
		v_read_o	<= 0;
	end
	else if (wrrf_src_sel[`WRS_LOAD] && !flag_v) begin
		v_write_o	<= 0;
		v_read_o	<= 1;
	end
	else begin
		v_write_o	<= 0;
		v_read_o	<= 0;
	end
end

// Set the address.
always @(posedge clock_i) begin
	if (alu0_dst_sel[`A0D_ADDR])
		v_addr_o	<= alu1_data;
end

// When `v_ready_i' asserts, set the processor flag.
always @(posedge clock_i) begin
	if (!reset_ni) begin
		flag_v_set	<= 0;
		flag_v_clr	<= 0;
	end
	else if (v_ready_i) begin
		vdata		<= v_data_i;
		
		flag_v_set	<= 1;
		flag_v_clr	<= 0;
	end
	else if (wrrf_src_sel[`WRS_LOAD]) begin
		flag_v_set	<= 0;
		flag_v_clr	<= 1;
	end
	else begin
		flag_v_set	<= 0;
		flag_v_clr	<= 0;
	end
end


// Bitwise operations functional unit.
// TODO: This can be optimised so that only one layer of logic is needed?
wire	com_sel	= alu0_dst_sel[`A0D_COM] | alu1_dst_sel[`A1D_COM] | alu2_dst_sel[`A2D_COM];
always @(posedge clock_i) begin
	if (alu0_dst_sel[`A0D_XOR])
		bitwise	<= com ^ alu0_data;
	else if (alu0_dst_sel[`A0D_AND])
		bitwise	<= com & alu0_data;
	else if (alu0_dst_sel[`A0D_OR])
		bitwise	<= com | alu0_data;
	else if (com_sel)
		bitwise	<= ~com;
	else
		bitwise	<= bitwise;
end

// This sets the zero flag when a bitwise operation (excluding NOT) causes a
// zero output.
assign	#2 bitwise_zero_w	= (bitwise == 0) ? 1 : 0;
assign	bitsel_w	= alu0_dst_sel[`A0D_XOR] | alu0_dst_sel[`A0D_AND] | alu0_dst_sel[`A0D_OR];

always @(posedge clock_i) begin
	if (!reset_ni) begin
		bit_flag_z_set	<= 0;
		bit_flag_z_clr	<= 0;
		
		bitwise_sel	<= 0;
	end
	else begin
		bitwise_sel	<= bitsel_w;
		
		if (bitwise_sel) begin
			if (bitwise_zero_w) begin
				bit_flag_z_set	<= 1;
				bit_flag_z_clr	<= 0;
			end
			else begin
				bit_flag_z_set	<= 0;
				bit_flag_z_clr	<= 1;
			end
		end
		else begin
			bit_flag_z_set	<= 0;
			bit_flag_z_clr	<= 0;
		end
	end
end


// Multiplication functional unit.
always @(posedge clock_i) begin
	if (alu1_dst_sel[`A1D_MUL])
		{prod_hi, prod_lo}	<= com * alu1_data;
end


// Subtraction functional unit.
always @(posedge clock_i) begin
	if (alu0_dst_sel[`A0D_SUB])
		diff	<= com - alu0_data;
end


// Increment functional unit.
always @(posedge clock_i) begin
	if (alu2_dst_sel[`A2D_INC])
		inc	<= alu2_data + 1;
end


// 3-to-8 de-multiplexer.
always @(posedge clock_i) begin
	case (alu0_dst)
	0:	dmux	<= 1;
	1:	dmux	<= 2;
	2:	dmux	<= 4;
	3:	dmux	<= 8;
	4:	dmux	<= 16;
	5:	dmux	<= 32;
	6:	dmux	<= 64;
	7:	dmux	<= 128;
	endcase
end


//---------------------------------------------------------------------------
// Load instructions into the instruction memory.
//

// Instruction load from PCI.
always @(posedge clock_i) begin
	if (!reset_ni)
		i_ready_o	<= 0;
	else begin
		i_ready_o	<= i_read_i;
		i_data_o	<= iram [i_addr_i];
		
		if (i_write_i)
			iram [i_addr_i]	<= i_data_i;
	end
end


// Load some instructions into the instruction RAM.
initial begin : Init
	iram[0]	<= 'bx;	// Should never get here
	//               IMM       R2   R1   R0   WR   ALU2   ALU1   ALU0
	
	// NOP
	iram[1]	<= 36'b000000000__0000_0000_0000__00__00_00__00_00__000_00;
	
	// mov { com -> com ; plo -> com ; com -> com ; get \> r2 ; }
	iram[2]	<= 36'b000000000__0000_0000_0000__01__00_00__00_00__000_00;
	
	// mov { com -> com ; plo -> com ; com -> com ; com \> r0 ; }
	iram[3]	<= 36'b000000100__0010_0000_0010__00__00_00__00_00__000_00;
	
	// mov { com -> sub ; plo -> mul ; flags -> com ; com \> r0 ; }
	iram[4]	<= 36'b000000000__0000_0000_0000__00__00_10__11_00__100_00;
	
	// mov { #04 -> and ; plo -> com ; com -> com ; com \> r0 ; }
	iram[5]	<= 36'b000000100__0000_0000_0000__00__00_00__00_00__010_11;
	
	iram[6]	<= 36'b000000000__0000_0000_0000__00__00_00__00_00__000_00;
	iram[7]	<= 36'b000000000__0000_0000_0000__00__00_00__00_00__000_00;
	iram[8]	<= 36'b000000000__0000_0000_0000__00__00_00__00_00__000_00;
	iram[9]	<= 36'b000000000__0000_0000_0000__00__00_00__00_00__000_00;
/*	
	iram[1]	<= 36'b000000001__0000_0000_0000__00__00_00__00_00__000_00;	// NOP
	// mov {imm -> com ; plo -> com ; com -> com ; com -> r0}
	iram[2]	<= 36'b000000011__0000_0000_0000__00__00_00__00_00__000_11;
	iram[3]	<= 36'b000000010__0000_0000_0000__00__00_00__00_00__000_00;	// NOP
	// mov {imm -> com ; plo -> com ; com -> com ; com \> r1}
	iram[4]	<= 36'b000000100__0000_0000_0000__00__00_00__00_00__000_11;
	// mov {com -> com ; plo -> com ; com -> com ; com \> r0}
	iram[5]	<= 36'b000000010__0001_0000_0000__00__00_00__00_00__000_00;	// NOP
	iram[6]	<= 36'b000000010__0000_0001_0000__00__00_00__00_00__000_00;	// NOP
	// mov {com -> com ; r1 \> mul ; imm \> pc ; com \> r0}
	iram[7]	<= 36'b000000010__0000_0000_0000__00__11_00__11_11__000_00;
	iram[8]	<= 36'b000000001__0000_0000_0000__00__00_00__00_00__000_00;	// NOP
	iram[9]	<= 36'b000000010__0000_0000_0000__00__00_00__00_00__000_00;	// NOP
	
/*	Simple looping demo code.
	iram[1]	<= 36'b000000001__0000_0000_0000__00__00_00__00_00__000_00;
	iram[2]	<= 36'b000000010__0000_0000_0000__00__00_00__00_00__000_00;
	iram[3]	<= 36'b000000011__0000_0000_0000__00__00_00__00_00__000_00;
	iram[4]	<= 36'b000000100__0000_0000_0000__00__00_00__00_00__000_00;
	iram[5]	<= 36'b000000101__0000_0000_0000__00__11_00__00_00__000_00;
	iram[6]	<= 36'b000000001__0000_0000_0000__00__00_00__00_00__000_00;
	iram[7]	<= 36'b000000111__0000_0000_0000__00__00_00__00_00__000_00;
	iram[8]	<= 36'b000001000__0000_0000_0000__00__00_00__00_00__000_00;
	iram[9]	<= 36'b000001001__0000_0000_0000__00__00_00__00_00__000_00;
	*/
end	// Init


endmodule	// vga_tta
