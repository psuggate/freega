/***************************************************************************
 *                                                                         *
 *   memmap.v - Maps a devices input ports to a memory mapped interface    *
 *     (with an optional port-mapping port.                                *
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
// TODO: Add another port

`timescale 1ns/100ps
module memmap (
	clock_i,
	reset_ni,
	
	port_write_i,
	port_addr_i,
	port_data_i,
	port_data_o,
	
	mem_write_i,
	mem_addr_i,
	mem_bes_ni,
	mem_data_i,
	mem_data_o,
	
	// These configure, or return data from, the VGA module's
	// registers.
	regs_o,
	regs_i
);

parameter	INIT		= 2048'b0;
parameter	REG_NUM		= 16;
parameter	REG_SIZE	= 16;
parameter	ADDR_BITS	= 3;
parameter	BES_BITS	= 4;
parameter	DATA_BITS	= 31;
parameter	REGS_BITS	= REG_NUM*REG_SIZE;

parameter	ADDR_MSB	= ADDR_BITS - 1;
parameter	BES_MSB		= BES_BITS - 1;
parameter	DATA_MSB	= DATA_BITS - 1;
parameter	REGS_MSB	= REGS_BITS - 1;


input	clock_i;
input	reset_ni;

input			port_write_i;
input	[ADDR_BITS-1:0]	port_addr_i;
input	[7:0]		port_data_i;
output	[7:0]		port_data_o;

input			mem_write_i;
input	[ADDR_MSB-1:0]	mem_addr_i;
input	[BES_MSB:0]	mem_bes_ni;
input	[DATA_MSB:0]	mem_data_i;
output	[DATA_MSB:0]	mem_data_o;

// Having these arranged like this allows a VGA module to have the
// ability to change some of the register values. If this feature is
// not required, `reg_o' can be fed straight back into `reg_i'.
// TODO: Currently no method to keep these in-sync has been
// done.
output	[REGS_MSB:0]	regs_o;
input	[REGS_MSB:0]	regs_i;


// All of the memory-mapped registers.
reg	[7:0]	regs	[0:REG_NUM-1];


// Assign all of the bits of the RAM to the output
generate	// XST needs this?
	genvar i;
	for (i=0; i<REG_NUM; i=i+1) assign regs_o [i*8+7:i*8] = regs [i];
endgenerate


// TODO: This makes the logic simpler to type, but adds one clock
// cycle of latency, so check how it synthesises.
reg	[7:0]	portdata_o;
reg	[7:0]	memdata_o;


integer	ii;
always @(posedge clock_i)
begin
	if (!reset_ni)
	begin
		// Fill in the initialisation values.
		for (ii = 0; ii < REGS_BITS; ii = ii + 1)
			regs [ii]	<= INIT [ii];
	end
	else
	begin
		// Memory-mapped I/O takes priority over port I/O.
		if (memwrite_i)		// A write to a memory-mapped port
			regs [memaddr_i]	<= memdata_i;
		else if (portwrite_i)	// A write to a memory-mapped port
			regs [portaddr_i]	<= portdata_i;
		
		// A read of a memory-mapped port.
		portdata_o [0]	<= regs_i [{portaddr_i, 3'b000}];
		portdata_o [1]	<= regs_i [{portaddr_i, 3'b001}];
		portdata_o [2]	<= regs_i [{portaddr_i, 3'b010}];
		portdata_o [3]	<= regs_i [{portaddr_i, 3'b011}];
		portdata_o [4]	<= regs_i [{portaddr_i, 3'b100}];
		portdata_o [5]	<= regs_i [{portaddr_i, 3'b101}];
		portdata_o [6]	<= regs_i [{portaddr_i, 3'b110}];
		portdata_o [7]	<= regs_i [{portaddr_i, 3'b111}];
		
		// A read of a memory-mapped port.
		memdata_o [0]	<= regs_i [{memaddr_i, 3'b000}];
		memdata_o [1]	<= regs_i [{memaddr_i, 3'b001}];
		memdata_o [2]	<= regs_i [{memaddr_i, 3'b010}];
		memdata_o [3]	<= regs_i [{memaddr_i, 3'b011}];
		memdata_o [4]	<= regs_i [{memaddr_i, 3'b100}];
		memdata_o [5]	<= regs_i [{memaddr_i, 3'b101}];
		memdata_o [6]	<= regs_i [{memaddr_i, 3'b110}];
		memdata_o [7]	<= regs_i [{memaddr_i, 3'b111}];
	end
end


endmodule	// memmap
