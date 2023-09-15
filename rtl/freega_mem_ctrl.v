/***************************************************************************
 *                                                                         *
 *   freega_mem_ctrl.v - The top-level memory controller interface for     *
 *     FreeGA. This handles memory requests from the PCI, VGA, and the     *
 *     embedded TTA CPU.                                                   *
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
module freega_mem_ctrl (
	
	// 33 MHz PCI clock domain memory requests.
	pci_clk_i,
	pci_rst_ni,
	
	pci_read_i,
	pci_write_i,
	pci_ack_o,
	pci_ready_o,
	pci_busy_o,
	pci_bes_ni,
	pci_addr_i,
	pci_data_i,
	pci_data_o,
	
	// These go to whichever low-level DRAM device controller is used.
	sdrst_no,
	start_no,
	read_no,
	write_no,
	term_no,
	init_no,
	rfc_no,
	rfcreq_i,
	ready_ni,
	busy_ni,
	addr_o,
	bes_no,
	data_o,
	data_i
);

input		pci_clk_i;
input		pci_rst_ni;

input		pci_read_i;
input		pci_write_i;
output		pci_ack_o;
output		pci_ready_o;
output		pci_busy_o;
input	[3:0]	pci_bes_ni;
input	[24:0]	pci_addr_i;
input	[31:0]	pci_data_i;
output	[31:0]	pci_data_o;

output		sdrst_no;
output		start_no;
output		read_no;
output		write_no;
output		term_no;
output		init_no;
output		rfc_no;
input		rfcreq_i;
input		ready_ni;
input		busy_ni;
output	[13:0]	addr_o;
output	[1:0]	bes_no;
output	[15:0]	data_o;
input	[15:0]	data_i;


//---------------------------------------------------------------------------
//  PCI Asynchronous FIFOs.
//

// Cancel all pending reads when the memory is deselected.
defparam	RAF0.WIDTH	= 10;
fifo16n RAF0 (
	.reset_ni	(pci_rst_ni),
	
	// Dequeue addresses and send to the memory.
	.rd_clk_i	(mem_clock_i),
	.rd_en_i	(mem_rack_i),
	.rd_data_o	(rd_addr),
	
	// Queue addresses coming from the PCI bus.
	.wr_clk_i	(pci_clk_i),
	.wr_en_i	(read),
	.wr_data_i	(addr),
	
	.wfull_o	(raf_full),
	.rempty_o	(raf_empty)
);


defparam	RDF0.WIDTH	= 32;
fifo16n RDF0 (
	.reset_ni	(pci_rst_ni),
	
	// Dequeue read data and send to the PCI bus.
	.rd_clk_i	(pci_clk_i),
	.rd_en_i	(rdf_empty_n),
	.rd_data_o	(rdata),
	
	// Store incoming data from the memory controller.
	.wr_clk_i	(mem_clock_i),
	.wr_en_i	(mem_ready_i),
	.wr_data_i	(mem_data_i),
	
	.wfull_o	(rdf_full),
	.rempty_o	(rdf_empty)
);


defparam	WF0.WIDTH	= 46;
fifo16n WF0 (
	.reset_ni	(pci_rst_ni),
	
	// Dequeue write data and send to the memory.
	.rd_clk_i	(mem_clock_i),
	.rd_en_i	(mem_wack_i),
	.rd_data_o	({wr_addr, mem_bes_no, mem_data_o}),
	
	// Store incoming commands from the PCI bus.
	.wr_clk_i	(pci_clk_i),
	.wr_en_i	(write),
	.wr_data_i	({addr, bes_n, wdata}),
	
	.wfull_o	(wf_full),
	.rempty_o	(wf_empty)
);


//---------------------------------------------------------------------------
//  DRAM Controller.
//

dram_ctrl DC0 (
	.clock_i	(dram_clk),
	.reset_ni	(dram_rst_n),
	
	.usr_read_i	(dram_read),
	.usr_write_i	(dram_write),
	.usr_ready_o	(dram_ready),
	.usr_busy_o	(dram_busy),
	.usr_addr_i	(dram_addr),
	.usr_bes_ni	(dram_bes_n),
	.usr_data_i	(dram_dto),
	.usr_data_o	(dram_dfrom),
	
	.sdrst_no	(sdrst_no),
	.start_no	(start_no),
	.read_no	(read_no),
	.write_no	(write_no),
	.term_no	(term_no),
	.init_no	(init_no),
	.rfc_no		(rfc_no),
	.rfcreq_i	(rfcreq_i),
	.ready_ni	(ready_ni),
	.busy_ni	(busy_ni),
	.addr_o		(addr_o),
	.bes_no		(bes_no),
	.data_o		(data_o),
	.data_i		(data_i)
);


endmodule	// freega_mem_ctrl
