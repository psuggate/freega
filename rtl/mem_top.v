/***************************************************************************
 *                                                                         *
 *   mem_top.v - Top level memory module for FreeGA.                       *
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

// FIXME: There seems to be a bug causing data to be written out of alignment
// by one address when writing large bursts. Maybe a PCI TARGET ABORT could
// be used to keep the bursts small to prevent this bug?
`define	__debug

`timescale 1ns/100ps
module	mem_top (
	sys_clk_i,
	mem_clk_o,
	reset_ni,
	
	pci_read_i,
	pci_write_i,
	pci_rack_o,
	pci_wack_o,
	pci_ready_o,
	pci_busy_o,
	pci_bes_ni,
	pci_addr_i,
	pci_data_i,
	pci_data_o,
	
	vid_read_i,
	vid_rack_o,
	vid_ready_o,
	vid_addr_i,
	vid_data_o,
	
	clk_o,		// SDRAM
	cke_o,
	cs_no,
	ras_no,
	cas_no,
	we_no,
	ba_o,
	a_o,
	dm_o,
	dq_io
);

parameter	WIDTH	= 32;
parameter	ADDRESS	= 21;

parameter	MSB	= WIDTH - 1;
parameter	ASB	= ADDRESS - 1;
parameter	ESB	= WIDTH / 8 - 1;

input		sys_clk_i;
output		mem_clk_o;
input		reset_ni;

input		pci_read_i;
input		pci_write_i;
output		pci_rack_o;
output		pci_wack_o;
output		pci_ready_o;
output		pci_busy_o;
input	[ASB:0]	pci_addr_i;
input	[ESB:0]	pci_bes_ni;
input	[MSB:0]	pci_data_i;
output	[MSB:0]	pci_data_o;

input		vid_read_i;
output		vid_rack_o;
output		vid_ready_o;
input	[ASB:0]	vid_addr_i;
output	[MSB:0]	vid_data_o;

output		clk_o;
output		cke_o;
output		cs_no;
output		ras_no;
output		cas_no;
output		we_no;
output	[1:0]	ba_o;
output	[12:0]	a_o;
output	[1:0]	dm_o;
inout	[15:0]	dq_io;


wire	mem_clk, latch_clk, sdr_clk;

wire	c_read, c_write, c_rack, c_wack, c_ready, c_busy;
wire	[ESB:0]	c_bes_n;
wire	[ASB:0]	c_addr;
wire	[MSB:0]	c_rdata, c_wdata;

wire	s_read, s_write, s_rack, s_wack, s_ready, s_busy;
wire	[ESB:0]	s_bes_n;
wire	[ASB:0]	s_addr;
wire	[MSB:0]	s_rdata, s_wdata;


assign	mem_clk_o	= mem_clk;
assign	a_o [12]	= 0;


// `define	__use_ll_cache
`ifdef	__use_ll_cache
llcache1k #(
	.WIDTH		(WIDTH),
	.ADDRESS	(ADDRESS),
	.CACHEWORDS	(256),
	.CACHEWORDSLOG2	(8),
	.LINESIZE	(8),
	.LINESIZELOG2	(3),
	.TAGNUMLOG2	(4),
	.ASSOCLOG2	(1),
	.READSTOISSUE	(1)
) CACHE0 (
	.clock_i	(mem_clk),
	.reset_ni	(reset_ni),
	
	.cpu_read_i	(pci_read_i),
	.cpu_write_i	(pci_write_i),
	.cpu_rack_o	(pci_rack_o),
	.cpu_wack_o	(pci_wack_o),
	.cpu_ready_o	(pci_ready_o),
	.cpu_busy_o	(pci_busy_o),
	.cpu_addr_i	(pci_addr_i),
	.cpu_bes_ni	(pci_bes_ni),
	.cpu_data_i	(pci_data_i),
	.cpu_data_o	(pci_data_o),
	
	.mem_read_o	(c_read),
	.mem_write_o	(c_write),
	.mem_rack_i	(c_rack),
	.mem_wack_i	(c_wack),
	.mem_ready_i	(c_ready),
	.mem_busy_i	(!(c_rack || c_wack)),
	.mem_addr_o	(c_addr),
	.mem_bes_no	(c_bes_n),
	.mem_data_i	(c_rdata),
	.mem_data_o	(c_wdata)
);
`else
cache1k #(
	.WIDTH		(WIDTH),
	.ADDRESS	(ADDRESS)
) CACHE0 (
	.clock_i	(mem_clk),
	.reset_ni	(reset_ni),
	
	.usr_read_i	(pci_read_i),
	.usr_write_i	(pci_write_i),
	.usr_rack_o	(pci_rack_o),
	.usr_wack_o	(pci_wack_o),
	.usr_ready_o	(pci_ready_o),
	.usr_busy_o	(pci_busy_o),
	.usr_addr_i	(pci_addr_i),
	.usr_bes_ni	(pci_bes_ni),
	.usr_data_i	(pci_data_i),
	.usr_data_o	(pci_data_o),
	
	.mem_read_o	(c_read),
	.mem_write_o	(c_write),
	.mem_ready_i	(c_ready),
	.mem_busy_i	(!(c_rack || c_wack)),
	.mem_addr_o	(c_addr),
	.mem_bes_no	(c_bes_n),
	.mem_data_i	(c_rdata),
	.mem_data_o	(c_wdata)
);
`endif	// __use_ll_cache


// Arbitrate between CPU and Video memory requests.
mem_switch #(
	.WIDTH		(WIDTH),
	.ADDRESS	(ADDRESS)
) MEMSWITCH0 (
	.clock_i	(mem_clk),
	.reset_ni	(reset_ni),
	
	.cpu_read_i	(c_read),
	.cpu_write_i	(c_write),
	.cpu_rack_o	(c_rack),
	.cpu_wack_o	(c_wack),
	.cpu_ready_o	(c_ready),
	.cpu_busy_o	(c_busy),
	.cpu_addr_i	(c_addr),
	.cpu_bes_ni	(c_bes_n),
	.cpu_data_i	(c_wdata),
	.cpu_data_o	(c_rdata),
	
	.vid_read_i	(vid_read_i),
	.vid_rack_o	(vid_rack_o),
	.vid_ready_o	(vid_ready_o),
	.vid_addr_i	(vid_addr_i),
	.vid_data_o	(vid_data_o),
	
	.mem_read_o	(s_read),
	.mem_write_o	(s_write),
	.mem_rack_i	(s_rack),
	.mem_wack_i	(s_wack),
	.mem_ready_i	(s_ready),
	.mem_busy_i	(s_busy),
	.mem_addr_o	(s_addr),
	.mem_bes_no	(s_bes_n),
	.mem_data_i	(s_rdata),
	.mem_data_o	(s_wdata)
);


sdram_ctrl #(
	.RFC_PERIOD	(1560),	// 100 MHz timings
	.tRAS		(4),
	.tRC		(6),
	.tRFC		(6)
// 	.RFC_PERIOD	(780),	// 50 MHz
// 	.tRAS		(3),
// 	.tRC		(3),
// 	.tRFC		(3)
) CTRL0 (
	.sys_clk_i	(mem_clk),
	.sdr_clk_i	(sdr_clk),
	.reg_clk_i	(latch_clk),
	.reset_ni	(reset_ni),
	
	.read_i		(s_read),
	.write_i	(s_write),
	.rack_o		(s_rack),
	.wack_o		(s_wack),
	.ready_o	(s_ready),
	.busy_o		(s_busy),
	.addr_i		({{(25-ADDRESS){1'b0}}, s_addr}),
	.bes_ni		(s_bes_n),
	.data_i		(s_wdata),
	.data_o		(s_rdata),
	
	// SDRAM pins.
	.CLK		(clk_o),
	.CKE		(cke_o),
	.CS_n		(cs_no),
	.RAS_n		(ras_no),
	.CAS_n		(cas_no),
	.WE_n		(we_no),
	.BA		(ba_o),
	.A		(a_o [11:0]),
	.DM		(dm_o),
	.DQ		(dq_io)
);


//---------------------------------------------------------------------------
//  Clocking stuff. Different phases of clocks are needed since there are
//  real-world delays, like IOB delays.
//
wire	GND	= 0;
wire	clk_out, clk90, clk180, clk270, lock;

// `define __100_MHz_SDRAM
// `define __83_MHz_SDRAM
`define __50_MHz_SDRAM

`ifdef __50_MHz_SDRAM
DCM #(
	.CLK_FEEDBACK		("1X"),
	.DLL_FREQUENCY_MODE	("LOW")
) dcm0 (
	.CLKIN	(sys_clk_i),
	.CLKFB	(mem_clk),
	.DSSEN	(GND),
	.PSEN	(GND),
	.RST	(~reset_ni),
	.CLK0	(clk_out),
	.CLK90	(clk90),
	.CLK180	(clk180),
	.CLK270	(clk270),
	.LOCKED	(lock)
);
`endif

`ifdef __100_MHz_SDRAM
DCM #(
	.CLK_FEEDBACK		("2X"),
	.DLL_FREQUENCY_MODE	("LOW")
) dcm0 (
	.CLKIN	(sys_clk_i),
	.CLKFB	(mem_clk),
	.DSSEN	(GND),
	.PSEN	(GND),
	.RST	(1'b0),
	.CLK2X		(clk_out),
	.CLK2X180	(clk180),
	.LOCKED	(lock)
);
`endif

`ifdef __83_MHz_SDRAM
// This works with SLOW slew.
DCM #(
	.CLK_FEEDBACK		("NONE"),
	.DLL_FREQUENCY_MODE	("LOW"),
	.CLKFX_MULTIPLY		(5),
	.CLKFX_DIVIDE		(3)
) dcm0 (
	.CLKIN		(sys_clk_i),
	.CLKFB		(GND),
	.DSSEN		(GND),
	.PSEN		(GND),
	.RST		(GND),
	.CLKFX		(clk_out),
	.CLKFX180	(clk180),
	.LOCKED		(lock)
);
`endif


BUFG mem_bufg (
	.I	(clk_out),
	.O	(mem_clk)
);

BUFG clk_bufg (
	.I	(clk180),
	.O	(sdr_clk)
);

assign	latch_clk	= sdr_clk;
// BUFG lclk_bufg (
// 	.I	(clk90),
// 	.O	(latch_clk)
// );


endmodule	// mem_top
