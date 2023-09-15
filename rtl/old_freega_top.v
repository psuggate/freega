/***************************************************************************
 *                                                                         *
 *   freega_top.v - A module that connects a block of memory, and a TTA    *
 *     CPU to the PCI Local Bus.                                           *
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
module freega_top (
	pci_clk,
	pci_rst_n,
	pci_frame_n,
	pci_irdy_n,
	pci_trdy_n,
	pci_devsel_n,
	pci_stop_n,
	pci_idsel,
	pci_par,
	pci_inta_n,
	pci_req_n,
	pci_gnt_n,
	pci_cbe_n,
	pci_ad,
	
	vgaclk,
	blank_n,
	sync_n,
	hsync,
	vsync,
	de,
	r,
	g,
	b,
	
	sdr_clk,		// SDRAM
	sdr_cke,
	sdr_cs_n,
	sdr_ras_n,
	sdr_cas_n,
	sdr_we_n,
	sdr_ba,
	sdr_a,
	sdr_dm,
	sdr_dq,
	
	pci_disable,	// Turns off the bus-switch, needs to be low
	clk50,
	leds		// LED that is controlled by PCI device
);

parameter	WIDTH	= 32;
parameter	ADDRESS	= 21;		// 8 MB
parameter	ASB	= ADDRESS - 1;

// PCI Pins
// synthesis attribute buffer_type of pci_clk is ibufg;
input	pci_clk;	// synthesis attribute period of pci_clk is "30 ns" ;
input	pci_rst_n;
input	pci_frame_n;
output	pci_devsel_n;	// synthesis attribute iob of pci_devsel_n is true ;
input	pci_irdy_n;
output	pci_trdy_n;	// synthesis attribute iob of pci_trdy_n is true ;
input	[3:0]	pci_cbe_n;
inout	[31:0]	pci_ad;	// synthesis attribute iob of pci_ad is true ;
input	pci_idsel;

output	pci_stop_n;
inout	pci_par;
output	pci_inta_n;
output	pci_req_n;
input	pci_gnt_n;

output		vgaclk;
output		sync_n;
output		blank_n;
output		de;
output		hsync;
output		vsync;
output	[7:0]	r;
output	[7:0]	g;
output	[7:0]	b;

output		sdr_clk;	// synthesis attribute iob of clk is true ;
output		sdr_cke;	// synthesis attribute iob of cke is true ;
output		sdr_cs_n;	// synthesis attribute iob of cs_n is true ;
output		sdr_ras_n;	// synthesis attribute iob of ras_n is true ;
output		sdr_cas_n;	// synthesis attribute iob of cas_n is true ;
output		sdr_we_n;	// synthesis attribute iob of we_n is true ;
output	[1:0]	sdr_ba;	// synthesis attribute iob of ba* is true ;
output	[12:0]	sdr_a;	// synthesis attribute iob of a* is true ;
output	[1:0]	sdr_dm;	// synthesis attribute iob of dm* is true ;
inout	[15:0]	sdr_dq;	// synthesis attribute iob of dq* is true ;

output pci_disable;
input	clk50;	// synthesis attribute buffer_type of clk50 is ibufg;
output	[1:0]	leds;


wire	mem_clk, dot_clk, chr_clk;

wire	p_read, p_write, p_rack, p_wack, p_ready, p_busy;
wire	[3:0]	p_bes_n;
wire	[ASB:0]	p_addr;
wire	[31:0]	p_wdata, p_rdata;


assign	vgaclk	= ~dot_clk;
assign	blank_n	= 1;
assign	sync_n	= 1;

assign	leds [0]	= 1'b0;


pci_top #(
	.ADDRESS	(ADDRESS)
) PCITOP0 (
	.pci_clk_i	(pci_clk),
	.mem_clk_i	(mem_clk),
	.reset_ni	(pci_rst_n),
	.enable_i	(1'b1),
	
	.enabled_o	(leds [1]),
	
	.pci_disable_o	(pci_disable),
	.pci_frame_ni	(pci_frame_n),
	.pci_devsel_no	(pci_devsel_n),
	.pci_irdy_ni	(pci_irdy_n),
	.pci_trdy_no	(pci_trdy_n),
	.pci_idsel_i	(pci_idsel),
	.pci_cbe_ni	(pci_cbe_n),
	.pci_ad_io	(pci_ad),
	.pci_stop_no	(pci_stop_n),
	.pci_par_io	(pci_par),
	.pci_inta_no	(pci_inta_n),
	.pci_req_no	(pci_req_n),
	.pci_gnt_ni	(pci_gnt_n),
	
	.mem_read_o	(p_read),
	.mem_write_o	(p_write),
	.mem_rack_i	(p_rack),
	.mem_wack_i	(p_wack),
	.mem_ready_i	(p_ready),
	.mem_busy_i	(p_busy),
	.mem_addr_o	(p_addr),
	.mem_bes_no	(p_bes_n),
	.mem_data_o	(p_wdata),
	.mem_data_i	(p_rdata)
);

/*
tta_top TTATOP0 (
);
*/

wire	v_read, v_rack, v_ready;
wire	[ASB:0]	v_addr;
wire	[31:0]	v_rdata;

vga_top #(
	.WIDTH		(WIDTH),
	.ADDRESS	(ADDRESS),
	.FBSIZE		(18),
	.FBOFF		(3'b000)
) VGATOP0 (
	.sys_clk_i	(clk50),
	.cpu_clk_i	(0),
	.mem_clk_i	(mem_clk),
	.dot_clk_o	(dot_clk),
	.chr_clk_o	(chr_clk),
	.reset_ni	(pci_rst_n),
	
	.mem_read_o	(v_read),
	.mem_rack_i	(v_rack),
	.mem_ready_i	(v_ready),
	.mem_addr_o	(v_addr),
	.mem_data_i	(v_rdata),
	
	.hsync_o	(hsync),
	.vsync_o	(vsync),
	.red_o		(r),
	.green_o	(g),
	.blue_o		(b),
	.de_o		(de)
);


mem_top #(
	.ADDRESS	(ADDRESS)
) MEMTOP0 (
	.sys_clk_i	(clk50),
	.mem_clk_o	(mem_clk),
	.reset_ni	(pci_rst_n),
	
	.pci_read_i	(p_read),
	.pci_write_i	(p_write),
	.pci_rack_o	(p_rack),
	.pci_wack_o	(p_wack),
	.pci_ready_o	(p_ready),
	.pci_busy_o	(p_busy),
	.pci_addr_i	(p_addr),
	.pci_bes_ni	(p_bes_n),
	.pci_data_i	(p_wdata),
	.pci_data_o	(p_rdata),
	
	.vid_read_i	(v_read),
	.vid_rack_o	(v_rack),
	.vid_ready_o	(v_ready),
	.vid_addr_i	(v_addr),
	.vid_data_o	(v_rdata),
	
	// SDRAM pins.
	.clk_o		(sdr_clk),
	.cke_o		(sdr_cke),
	.cs_no		(sdr_cs_n),
	.ras_no		(sdr_ras_n),
	.cas_no		(sdr_cas_n),
	.we_no		(sdr_we_n),
	.ba_o		(sdr_ba),
	.a_o		(sdr_a),
	.dm_o		(sdr_dm),
	.dq_io		(sdr_dq)
);


`ifdef __use_CPU
// CPU Top.
tta16_tile #(
	.ADDRESS	(ADDRESS)
) TTA0 (
	.wb_rst_i	(reset),
	.wb_clk_i	(wb_clk),	// 50 MHz
	.cpu_clk_i	(cpu_clk),	// 150 MHz, sync with WB clock
	
	.mem_cyc_o	(mem_cyc),
	.mem_stb_o	(mem_stb),
	.mem_we_o	(mem_we),
	.mem_ack_i	(mem_ack),
	.mem_rty_i	(mem_rty),
	.mem_err_i	(mem_err),
	.mem_cti_o	(mem_cti),
	.mem_bte_o	(mem_bte),
	.mem_adr_o	(mem_adr),
	.mem_sel_o	(mem_sel_f),
	.mem_dat_o	(mem_dat_f),
	.mem_sel_i	(mem_sel_t),
	.mem_dat_i	(mem_dat_t),
	
	.io_cyc_o	(io_cyc),
	.io_stb_o	(io_stb),
	.io_we_o	(io_we),
	.io_ack_i	(io_ack),
	.io_rty_i	(io_rty),
	.io_err_i	(io_err),
	.io_cti_o	(io_cti),
	.io_bte_o	(io_bte),
	.io_adr_o	(io_adr),
	.io_sel_o	(io_sel_f),
	.io_dat_o	(io_dat_f),
	.io_sel_i	(io_sel_t),
	.io_dat_i	(io_dat_t)
);
`endif	// __use_CPU


endmodule	// freega_top
