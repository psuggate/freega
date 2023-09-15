/***************************************************************************
 *                                                                         *
 *   vga_tta.v - A light-weight TTA CPU for converting VGA port accesses   *
 *     into external register values and vice versa, complete with L1 & L2 *
 *     caches and system address space.                                    *
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
module vga_tta (
	clock_i,
	reset_ni,
	enable_i,
	
	mem_read_o,	// Memory interface
	mem_write_o,
	mem_rack_i,
	mem_wack_i,
	mem_ready_i,
	mem_busy_i,
	mem_addr_o,
	mem_bes_no,
	mem_data_o,
	mem_data_i,
	
	sys_read_o,	// MMIO
	sys_write_o,
	sys_rack_i,
	sys_wack_i,
	sys_ready_i,
	sys_busy_i,
	sys_addr_o,
	sys_bes_no,
	sys_bes_ni,
	sys_data_o,
	sys_data_i
);

parameter	WIDTH		= 18;	// CPU bit width
parameter	INSTRUCTION	= 32;
parameter	MEMORY		= 32;
parameter	ADDRESS		= 28;
parameter	PAGEWIDTH	= 10;

parameter	WSB	= WIDTH - 1;
parameter	MSB	= MEMORY - 1;
parameter	ISB	= INSTRUCTION - 1;
parameter	ASB	= ADDRESS - 1;
parameter	PSB	= PAGEWIDTH - 1;

input		clock_i;
input		reset_ni;
input		enable_i;

output		mem_read_o;
output		mem_write_o;
input		mem_rack_i;
input		mem_wack_i;
input		mem_ready_i;
input		mem_busy_i;
output	[ASB:0]	mem_addr_o;
output	[3:0]	mem_bes_no;
output	[MSB:0]	mem_data_o;
input	[MSB:0]	mem_data_i;

output		sys_read_o;
output		sys_write_o;
input		sys_rack_i;
input		sys_wack_i;
input		sys_ready_i;
input		sys_busy_i;
output	[ASB:0]	sys_addr_o;
output	[3:0]	sys_bes_no;
input	[3:0]	sys_bes_ni;
output	[MSB:0]	sys_data_o;
input	[MSB:0]	sys_data_i;


//---------------------------------------------------------------------------
//  The CPU.
//
tta_hybrid #(
	.WIDTH		(WIDTH),
	.INSTRUCTION	(INSTRUCTION),
	.ADDRESS	(ADDRESS),
	.PAGEWIDTH	(PAGEWIDTH)
) TTA0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	.enable_i	(enable_i),
	
	.i_read_o	(fetch),
	.i_rack_i	(rack),
	.i_addr_o	(pc),
	.i_ready_i	(hit),
	.i_data_i	(instr),
	
	.m_read_o	(),	// TTA to Memory
	.m_write_o	(),
	.m_rack_i	(0),
	.m_wack_i	(0),
	.m_ready_i	(0),
	.m_busy_i	(0),
	.m_raddr_o	(),
	.m_waddr_o	(),
	.m_bes_no	(),
	.m_data_i	(0),
	.m_data_o	()
);


//---------------------------------------------------------------------------
//  Some caches.
//
wire	L2_read, L2_rack, L2_ready;
wire	[PSB:0]	L2_addr;
ucache #(
	.WIDTH		(INSTRUCTION),
	.ADDRESS	(PAGEWIDTH)
) ICACHE_L1 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.m_read_i	(fetch),
	.m_rack_o	(rack),
	.m_ready_o	(hit),
	.m_addr_i	(pc [PSB:0]),
	.m_data_o	(instr),
	
	.s_read_o	(L2_read),
	.s_ready_i	(L2_ready),
	.s_rack_i	(L2_rack),
	.s_addr_o	(L2_addr),
	.s_data_i	(L2_data_from)
);


assign	#2 i_data_in	= boot_match ? b_data_from : mem_data_i;
cache1k #(
	.WIDTH		(INSTRUCTION),
	.ADDRESS	(ADDRESS-1)	// System space isn't cached
) ICACHE_L2 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.usr_read_i	(L2_read & ~pc [ASB]),
	.usr_write_i	(1'b0),
	.usr_rack_o	(L2_rack),
	.usr_wack_o	(),
	.usr_ready_o	(L2_ready),
	.usr_busy_o	(),
	.usr_addr_i	({pc [ASB-1:PAGEWIDTH], L2_addr}),
	.usr_bes_ni	(4'hF),
	.usr_data_i	(0),
	.usr_data_o	(L2_data_from),
	
	.mem_read_o	(i_read),
	.mem_write_o	(),
	.mem_ready_i	(i_ready),
	.mem_busy_i	(i_rack),
	.mem_addr_o	(i_addr),
	.mem_bes_no	(),
	.mem_data_i	(i_data_in),
	.mem_data_o	()
);


cache1k #(
	.WIDTH		(INSTRUCTION),
	.ADDRESS	(ADDRESS-1)	// System space isn't cached
) DCACHE_L1 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.usr_read_i	(read),
	.usr_write_i	(write),
	.usr_rack_o	(rack),
	.usr_wack_o	(wack),
	.usr_ready_o	(ready),
	.usr_busy_o	(busy),
	.usr_addr_i	(addr),
	.usr_bes_ni	(bes_n),
	.usr_data_i	(data_to),
	.usr_data_o	(data_from),
	
	.mem_read_o	(c_read),
	.mem_write_o	(c_write),
	.mem_ready_i	(c_ready),
	.mem_busy_i	(!(c_rack || c_wack)),
	.mem_addr_o	(c_addr),
	.mem_bes_no	(c_bes_n),
	.mem_data_i	(c_data_to),
	.mem_data_o	(c_data_from)
);


//---------------------------------------------------------------------------
//  CPU Boot Code.
//
`define	BOOT_ADDR	14'h0000
assign	#3 boot_match	= (pc [ASB:PAGEWIDTH] == `BOOT_ADDR);

bram4k RAM0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.read_i		(b_read),
	.write_i	(b_write),
	.rack_o		(b_rack),
	.wack_o		(b_wack),
	.ready_o	(b_ready),
	.busy_o		(b_busy),
	.addr_i		(b_addr),
	.bes_ni		(b_bes_n),
	.data_i		(b_data_to),
	.data_o		(b_data_from)
);


endmodule	// vga_tta
