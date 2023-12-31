/***************************************************************************
 *                                                                         *
 *   freega_cpu.v - A Wishbone compliant data cache (can be used for       *
 *      instructions too, but has more features than needed).              *
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

// `define __use_TTA

`timescale 1ns/100ps
module freega_cpu #(
	parameter	HIGHZ	= 0,
	parameter	ADDRESS	= 25,
	parameter	CWIDTH	= 16,
	parameter	WWIDTH	= 32,
	parameter	BSIZE	= 9,	// BRAM size (2^BSIZE entries at WWDITH)
	parameter	PCBITS	= 10,
	parameter	ENABLES	= CWIDTH / 8,
	parameter	SELECTS	= WWIDTH / 8,
	parameter	MSB	= CWIDTH - 1,
	parameter	WSB	= WWIDTH - 1,
	parameter	ASB	= ADDRESS - 1,
	parameter	ESB	= ENABLES - 1,
	parameter	SSB	= SELECTS - 1
) (
	input		cpu_clk_i,	// Dual (but syncronous) clocks
	input		wb_clk_i,
	input		wb_rst_i,
	
	output		rd_cyc_o,	// Reads go straight to SDRAM controller
	output		rd_stb_o,
	output		rd_we_o,
	input		rd_ack_i,
	input		rd_rty_i,
	input		rd_err_i,
	output	[2:0]	rd_cti_o,
	output	[1:0]	rd_bte_o,
	output	[ASB-1:0]	rd_adr_o,
	
	output		wr_cyc_o,	// Writes are buffered
	output		wr_stb_o,
	output		wr_we_o,
	input		wr_ack_i,
	input		wr_rty_i,
	input		wr_err_i,
	output	[2:0]	wr_cti_o,
	output	[1:0]	wr_bte_o,
	output	[ASB-1:0]	wr_adr_o,
	
	output	[SSB:0]	wb_sel_o,
	output	[WSB:0]	wb_dat_o,
	input	[SSB:0]	wb_sel_i,
	input	[WSB:0]	wb_dat_i,

	output		io_cyc_o,	// Writes are buffered
	output		io_stb_o,
	output		io_we_o,
	input		io_ack_i,
	input		io_rty_i,
	input		io_err_i,
	output	[2:0]	io_cti_o,
	output	[1:0]	io_bte_o,
	output	[ASB-1:0]	io_adr_o,
	
	output	[SSB:0]	io_sel_o,
	output	[WSB:0]	io_dat_o,
	input	[SSB:0]	io_sel_i,
	input	[WSB:0]	io_dat_i
);


wire	cpu_cyc, cpu_stb, cpu_we, cpu_ack, cpu_rty, cpu_err;
wire	[2:0]	cpu_cti;
wire	[1:0]	cpu_bte;
wire	[ASB:0]	cpu_adr;
wire	[ESB:0]	cpu_sel_t, cpu_sel_f;
wire	[MSB:0]	cpu_dat_t, cpu_dat_f;


`ifdef __use_TTA
tta_wide #(
`else
risc16 #(
`endif
	.HIGHZ		(0),
	.WIDTH		(CWIDTH),
	.INSTR		(CWIDTH),
	.ADDRESS	(ADDRESS),
	.PCBITS		(PCBITS),
	.WBBITS		(CWIDTH)
) CPU (
	.cpu_clk_i	(cpu_clk_i),
	.cpu_rst_i	(wb_rst_i),
	
	.wb_clk_i	(cpu_clk_i),	// 16-bit CPU-to-cache WB interface
	.wb_rst_i	(wb_rst_i),
	.wb_cyc_o	(cpu_cyc),
	.wb_stb_o	(cpu_stb),
	.wb_we_o	(cpu_we),
	.wb_ack_i	(cpu_ack),
	.wb_rty_i	(cpu_rty),
	.wb_err_i	(cpu_err),
	.wb_cti_o	(cpu_cti),
	.wb_bte_o	(cpu_bte),
	.wb_adr_o	(cpu_adr),
	.wb_sel_o	(cpu_sel_t),
	.wb_dat_o	(cpu_dat_t),
	.wb_sel_i	(cpu_sel_f),
	.wb_dat_i	(cpu_dat_f)
);


wb_dcache #(
	.HIGHZ		(HIGHZ),
	.ADDRESS	(ADDRESS-1),
	.CWIDTH		(CWIDTH),
	.WWIDTH		(WWIDTH),
	.SIZE		(BSIZE+1)		// 2kB (32x512)
) CACHE0 (
	.wb_clk_i	(wb_clk_i),
	.wb_rst_i	(wb_rst_i),
	
	.cpu_clk_i	(cpu_clk_i),	// Dual (but syncronous) clocks
	.cpu_cyc_i	(cpu_cyc),	// Master drives this from the hi-side
	.cpu_stb_i	(cpu_stb),
	.cpu_we_i	(cpu_we),
	.cpu_ack_o	(cpu_ack),
	.cpu_rty_o	(cpu_rty),
	.cpu_err_o	(cpu_err),
	.cpu_cti_i	(cpu_cti),
	.cpu_bte_i	(cpu_bte),
	.cpu_adr_i	(cpu_adr),
	
	.cpu_sel_i	(cpu_sel_t),
	.cpu_dat_i	(cpu_dat_t),
	.cpu_sel_o	(cpu_sel_f),
	.cpu_dat_o	(cpu_dat_f),
	
	.rd_cyc_o	(rd_cyc_o),
	.rd_stb_o	(rd_stb_o),
	.rd_we_o	(rd_we_o),
	.rd_ack_i	(rd_ack_i),
	.rd_rty_i	(rd_rty_i),
	.rd_err_i	(rd_err_i),
	.rd_cti_o	(rd_cti_o),
	.rd_bte_o	(rd_bte_o),
	.rd_adr_o	(rd_adr_o),
	
	.wr_cyc_o	(wr_cyc_o),
	.wr_stb_o	(wr_stb_o),
	.wr_we_o	(wr_we_o),
	.wr_ack_i	(wr_ack_i),
	.wr_rty_i	(wr_rty_i),
	.wr_err_i	(wr_err_i),
	.wr_cti_o	(wr_cti_o),
	.wr_bte_o	(wr_bte_o),
	.wr_adr_o	(wr_adr_o),
	
	.wb_sel_o	(wb_sel_o),
	.wb_dat_o	(wb_dat_o),
	.wb_sel_i	(wb_sel_i),
	.wb_dat_i	(wb_dat_i)
);


endmodule	// freega_cpu
