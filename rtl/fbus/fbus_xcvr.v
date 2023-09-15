/***************************************************************************
 *                                                                         *
 *   fbus_read_xcvr.v - A transceiver for sending requests, and receiving  *
 *     data from other fbus devices.                                       *
 *                                                                         *
 *   Copyright (C) 2005 by Patrick Suggate                                 *
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

module fbus_xcvr (
		fbus_clk_i,	// 200 MHz
		host_clk_i,	// upto 100 MHz
		reset_i,
		
		fbus_rq_o,
		fbus_addr_o,
		fbus_data_i
	);
	
	
	input	fbus_clk_i;
	input	host_clk_i;
	input	reset_i;
	
	output	fbus_rq_o;
	output	[15:0]	fbus_addr_o;
	output	[15:0]	fbus_data_i;
	
	input	host_read_i;
	input	[31:0]	host_addr_i;
	output	host_done_o;
	output	[31:0]	host_data_o;
	
	wire	almost_full;
	wire	almost_empty;
	wire	not_empty;
	fifo16 #('d32) ADDR_FIFO0 (
		.read_clock_i(host_clk_i),
		.write_clock_i(fbus_clk_i),
		.reset_i(reset_i),
		.read_i(read),
		.write_i(write),
		.data_i(wr_data),
		.data_o(rd_data),
		.almost_full_o(almost_full),
		.almost_empty_o(almost_empty),
		.not_empty_o(not_empty)
	);
	
endmodule	// fbus_xcvr

