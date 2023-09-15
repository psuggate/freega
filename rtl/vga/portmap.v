/***************************************************************************
 *                                                                         *
 *   portmap.v - Port-maps a memory-mapped interface.                      *
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

module portmap (
		clock_i,
		reset_i,
		
		addrwrite_i,
		datawrite_i,
		portaddr_i,
		portdata_i,
		portaddr_o,
		portdata_o,
		
		memwrite_o,
		memaddr_o,
		memdata_i,
		memdata_o
	);
	
	// 16 port-mapped registers by default.
	parameter	ADDR_BITS	= 4;
	
	input	clock_i;
	input	reset_i;
	
	// I/O port interface to outside world.
	input	addrwrite_i;
	input	datawrite_i;
	input	[ADDR_BITS-1:0]	portaddr_i;
	input	[7:0]		portdata_i;
	output	[ADDR_BITS-1:0]	portaddr_o;
	output	[7:0]		portdata_o;
	
	// Talk to the memory mapped registers.
	output	memwrite_o;
	output	[ADDR_BITS-1:0]	memaddr_o;
	input	[7:0]		memdata_i;
	output	[7:0]		memdata_o;
	
	
	// Registers for talking to memory-mapped I/O
	reg	memwrite_o	= 0;
	reg	[7:0]	memdata_o;
	
	
	// I/O port index (address) register.
	reg	[ADDR_BITS-1:0]	index	= 0;
	
	
	always @(posedge clock_i)
	begin
		if (reset_i)
		begin
			memwrite_o	<= 0;
			index		<= 0;
		end
		else
		begin
			case ({addrwrite_i, datawrite_i})
			
			// Write to the port address register only.
			2'b10: begin
				memwrite_o	<= 0;
				index		<= portaddr_i;
			end
			
			// Simultaneous write to both address and data ports.
			2'b11: begin
				memwrite_o	<= 1;
				index		<= portaddr_i;
				memdata_o	<= portdata_i;
			end
			
			// Write only to the data port.
			2'b01: begin
				memwrite_o	<= 1;
				memdata_o	<= portdata_i;
			end
			
			// Default action is a read of the address and data port.
			2'b00: begin
				memwrite_o	<= 0;
			end
			
			endcase
		end
	end
	
	
	//assign	memaddr_o	= (portsel_i & addrwrite_i) ? portaddr_i : index;
	assign	memaddr_o	= index;
	assign	portaddr_o	= index;
	assign	portdata_o	= memdata_i;
	
	
endmodule	// portmap
