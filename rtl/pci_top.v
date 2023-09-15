/***************************************************************************
 *                                                                         *
 *   pci_top.v - PCI mapped memory controller.                             *
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
module pci_top (
	pci_clk_i,
	mem_clk_i,
	reset_ni,
	enable_i,
	
	enabled_o,
	
	pci_disable_o,	// Turns off the bus-switch, needs to be low
	pci_frame_ni,
	pci_devsel_no,
	pci_irdy_ni,
	pci_trdy_no,
	pci_idsel_i,
	pci_cbe_ni,
	pci_ad_io,
	pci_stop_no,
	pci_par_io,
	pci_inta_no,
	pci_req_no,
	pci_gnt_ni,
	
	mem_read_o,
	mem_write_o,
	mem_rack_i,
	mem_wack_i,
	mem_ready_i,
	mem_busy_i,
	mem_bes_no,
	mem_addr_o,
	mem_data_o,
	mem_data_i
);

parameter	WIDTH	= 32;
`ifdef __icarus
parameter	ADDRESS	= 10;	// 4kB
`else
parameter	ADDRESS	= 21;	// 8MB
`endif
parameter	MSB	= WIDTH - 1;
parameter	ASB	= ADDRESS - 1;

input		pci_clk_i;
input		mem_clk_i;
input		reset_ni;
input		enable_i;

output		enabled_o;

// PCI Pins
output		pci_disable_o;
input		pci_frame_ni;
output		pci_devsel_no;
input		pci_irdy_ni;
output		pci_trdy_no;
input		pci_idsel_i;
input	[3:0]	pci_cbe_ni;	// TODO: Make bi-directional one day.
inout	[31:0]	pci_ad_io;
output		pci_stop_no;
inout		pci_par_io;
output		pci_inta_no;
output		pci_req_no;
input		pci_gnt_ni;

output		mem_read_o;
output		mem_write_o;
input		mem_rack_i;
input		mem_wack_i;
input		mem_ready_i;
input		mem_busy_i;
output	[3:0]	mem_bes_no;
output	[ASB:0]	mem_addr_o;
output	[31:0]	mem_data_o;
input	[31:0]	mem_data_i;


// CFG space wires.
wire	cfg_devsel_n, cfg_trdy_n;
wire	cfg_active, cfg_sel;
wire	[31:0]	cfg_data;

wire	[(32-ADDRESS-3):0]	mm_addr;
wire	mm_enable;

// Mem to PCI signals.
wire	mem_devsel_n, mem_trdy_n;
wire	mem_active, mem_sel;
wire	[31:0]	mem_data;

wire	[31:0]	data_out;


assign	enabled_o	= mm_enable;
assign	pci_disable_o	= ~enable_i;

// TODO: This MUXing causes quite long combinational delays.
assign	#2 data_out	= cfg_active ? cfg_data : mem_data;
assign	#2 pci_ad_io	= (cfg_active || mem_active) ? data_out : 'bz;
assign	#2 pci_devsel_no	= (cfg_sel || mem_sel) ? (cfg_devsel_n & mem_devsel_n) : 'bz;
assign	#2 pci_trdy_no	= (cfg_sel || mem_sel) ? (cfg_trdy_n & mem_trdy_n) : 'bz;

// These are unused ATM.
assign	pci_stop_no	= 1'b1;
assign	pci_req_no	= 1'b1;
assign	pci_inta_no	= 1'b1;
assign	pci_par_io	= 1'bz;


// Allocates the memory-mapped regions on system boot-up.
cfgspace #(
	.ADDRESS	(ADDRESS+2)
) CFG0 (
	.pci_clk_i	(pci_clk_i),
	.pci_rst_ni	(reset_ni),
	
	.pci_frame_ni	(pci_frame_ni),
	.pci_devsel_no	(cfg_devsel_n),
	.pci_irdy_ni	(pci_irdy_ni),
	.pci_trdy_no	(cfg_trdy_n),
	
	.pci_cbe_ni	(pci_cbe_ni),
	.pci_ad_i	(pci_ad_io),
	.pci_ad_o	(cfg_data),
	
	.pci_idsel_i	(pci_idsel_i),
	
	.active_o	(cfg_active),
	.selected_o	(cfg_sel),
	.memen_o	(mm_enable),
	.addr_o		(mm_addr)
);


// This wraps the `pcimem' module so that the memory commands are
// changed to the memory clock domain. It uses asynchronous FIFOs.
pci_mem_async #(
	.ADDRESS	(ADDRESS)
) MEM0 (
	.pci_clk_i	(pci_clk_i),
	.pci_rst_ni	(reset_ni),
	
	.pci_frame_ni	(pci_frame_ni),
	.pci_devsel_no	(mem_devsel_n),
	.pci_irdy_ni	(pci_irdy_ni),
	.pci_trdy_no	(mem_trdy_n),
	
	.pci_cbe_ni	(pci_cbe_ni),
	.pci_ad_i	(pci_ad_io),
	.pci_ad_o	(mem_data),
	
	.active_o	(mem_active),
	.selected_o	(mem_sel),
	
	.mm_enable_i	(mm_enable),
	.mm_addr_i	(mm_addr),
	
	.mem_clk_i	(mem_clk_i),
	.mem_read_o	(mem_read_o),
	.mem_write_o	(mem_write_o),
	.mem_rack_i	(mem_rack_i),
	.mem_wack_i	(mem_wack_i),
	.mem_ready_i	(mem_ready_i),
	.mem_busy_i	(mem_busy_i),
	.mem_bes_no	(mem_bes_no),
	.mem_addr_o	(mem_addr_o),
	.mem_data_o	(mem_data_o),
	.mem_data_i	(mem_data_i)
);


endmodule	// pci_top
