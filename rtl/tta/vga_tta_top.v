/***************************************************************************
 *                                                                         *
 *   vga_tta_top.v - A TTA CPU with a some caches and a system/memory      *
 *     address decoder.                                                    *
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

// TODO: Prefixes for different groups of signals.
`timescale 1ns/100ps
module vga_tta_top (
	clock_i,
	reset_ni,
	enable_i,
	
	i_read_o,
	i_rack_i,
	i_addr_o,
	i_ready_i,
	i_data_i,
	
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

parameter	WIDTH		= 32;
parameter	ADDRESS		= 28;
parameter	PAGEWIDTH	= 10;

parameter	MSB	= WIDTH - 1;
parameter	ASB	= ADDRESS - 1;
parameter	PSB	= PAGEWIDTH - 1;


parameter	AW	= 16;
parameter	IW	= 32;
parameter	AMSB	= AW-1;
parameter	IMSB	= IW-1;

parameter	IAMSB	= 8;
parameter	IWORDS	= 512;
parameter	MAMSB	= 3;
parameter	MDMSB	= 10;

input		clock_i;
input		reset_ni;
input		enable_i;

output		i_read_o;
input		i_rack_i;
output	[ASB:0]	i_addr_o;
input		i_ready_i;
input	[MSB:0]	i_data_i;

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


reg	hit	= 0;
wire	fetch, rack;
wire	[ASB:0]	pc;
wire	[MSB:0]	instr;

reg	sys_addr	= 0;
wire	[31:0]	mdata, bdata;


assign	rack		= fetch;
assign	#2 mdata	= sys_addr ? bdata : m_data_i;


always @(posedge clock_i)
	if (!reset_ni)	sys_addr	<= #2 0;
	else		sys_addr	<= #2 m_addr_o [ASB];

always @(posedge clock_i)
	hit		<= #2 fetch;

/*
// Only stores two cache-lines.
ucache #(
	.WIDTH		(INSTRUCTION),
	.ADDRESS	(PAGEWIDTH)
) CACHE0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.m_read_i	(fetch),
	.m_rack_o	(rack),
	.m_ready_o	(hit),
	.m_addr_i	(pc [PSB:0]),
	.m_data_o	(instr),
	
	.s_read_o	(i_read_o),
	.s_ready_i	(i_ready_i),
	.s_rack_i	(i_rack_i),
	.s_addr_o	(i_addr_o),
	.s_data_i	(i_data_i)
);
*/

tta_hybrid #(
	.WIDTH		(18),
	.INSTRUCTION	(WIDTH),
	.ADDRESS	(ADDRESS),
	.PAGEWIDTH	(PAGEWIDTH)
) TTA0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(1'b1),
	
	.i_read_o	(fetch),
	.i_rack_i	(rack),
	.i_addr_o	(pc),
	.i_ready_i	(hit),
	.i_data_i	(instr),
	
	.m_read_o	(m_read_o),
	.m_write_o	(m_write_o),
	.m_rack_i	(m_rack_i),
	.m_wack_i	(m_wack_i),
	.m_ready_i	(m_ready_i),
	.m_busy_i	(m_busy_i),
	.m_addr_o	(m_addr_o),
	.m_bes_ni	(m_bes_ni),
	.m_bes_no	(m_bes_no),
	.m_data_i	(mdata),
	.m_data_o	(m_data_o)
);


// Stores boot code.
wire	#2 sys_mem_en	= ~m_addr_o [ASB];
RAMB16_S36_S36 #(
	`include "prog.v"
) BRAM0 (
	.DIA	(0),
	.DIPA	(0),
	.ADDRA	(pc [8:0]),
	.ENA	(fetch),
	.WEA	(0),
	.SSRA	(0),
	.CLKA	(clock_i),
	.DOA	(instr),
	.DOPA	(),
	
	.DIB	(m_data_o),
	.DIPB	(0),
	.ADDRB	(m_addr_o [8:0]),
	.ENB	(sys_mem_en),
	.WEB	(m_write_o),
	.SSRB	(0),
	.CLKB	(clock_i),
	.DOB	(bdata),
	.DOPB	()
);


endmodule	// vga_tta_top
