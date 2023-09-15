/***************************************************************************
 *                                                                         *
 *   mem_switch.v - Switches the control of the memory between the CPU and *
 *     the Video redraw logic. The CPU takes priority.                     *
 *                                                                         *
 *     This design of TTA is optimised for latency, not frequency.         *
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
module	mem_switch (
	clock_i,
	reset_ni,
	
	cpu_read_i,
	cpu_write_i,
	cpu_rack_o,
	cpu_wack_o,
	cpu_ready_o,
	cpu_busy_o,
	cpu_addr_i,
	cpu_bes_ni,
	cpu_data_i,
	cpu_data_o,
	
	vid_read_i,
	vid_rack_o,
	vid_ready_o,
	vid_addr_i,
	vid_data_o,
	
	mem_read_o,
	mem_write_o,
	mem_rack_i,
	mem_wack_i,
	mem_ready_i,
	mem_busy_i,
	mem_addr_o,
	mem_bes_no,
	mem_data_i,
	mem_data_o
);

parameter	WIDTH	= 32;
parameter	ADDRESS	= 21;

parameter	MSB	= WIDTH - 1;
parameter	ASB	= ADDRESS - 1;
parameter	ESB	= WIDTH / 8 - 1;

input		clock_i;
input		reset_ni;

input		cpu_read_i;
input		cpu_write_i;
output		cpu_rack_o;
output		cpu_wack_o;
output		cpu_ready_o;
output		cpu_busy_o;
input	[ASB:0]	cpu_addr_i;
input	[ESB:0]	cpu_bes_ni;
input	[MSB:0]	cpu_data_i;
output	[MSB:0]	cpu_data_o;

input		vid_read_i;
output		vid_rack_o;
output		vid_ready_o;
input	[ASB:0]	vid_addr_i;
output	[MSB:0]	vid_data_o;

output		mem_read_o;
output		mem_write_o;
input		mem_rack_i;
input		mem_wack_i;
input		mem_ready_i;
input		mem_busy_i;
output	[ASB:0]	mem_addr_o;
output	[ESB:0]	mem_bes_no;
input	[MSB:0]	mem_data_i;
output	[MSB:0]	mem_data_o;


// Both the PCI and the display want the memory, and potentially at the same
// time.
wire	read, write, rack, wack, ready, busy;
wire	[3:0]	bes_n;
wire	[ASB:0]	addr;
wire	[31:0]	wdata, rdata;

`define	MS_IDLE	3'b001
`define	MS_CPU	3'b010
`define	MS_VGA	3'b100
reg	[2:0]	state	= `MS_IDLE;
reg	[2:0]	rdcnt	= 0;


assign	#2 mem_read_o	= state == `MS_VGA ? vid_read_i : cpu_read_i ;
assign	#2 mem_write_o	= state == `MS_VGA ? 1'b0 : cpu_write_i;
assign	#2 mem_addr_o	= state == `MS_VGA ? vid_addr_i : cpu_addr_i ;
assign	mem_bes_no	= cpu_bes_ni;
assign	mem_data_o	= cpu_data_i;

assign	#2 vid_rack_o	= state == `MS_VGA ? mem_rack_i : 1'b0 ;
assign	#2 vid_ready_o	= state == `MS_VGA ? mem_ready_i : 1'b0 ;
assign	vid_data_o	= mem_data_i;

assign	#2 cpu_rack_o	= state == `MS_VGA ? 1'b0 : mem_rack_i ;
assign	#2 cpu_wack_o	= state == `MS_VGA ? 1'b0 : mem_wack_i ;
assign	#2 cpu_ready_o	= state == `MS_VGA ? 1'b0 : mem_ready_i ;
assign	cpu_data_o	= mem_data_i;


always @(posedge clock_i)
	if (!reset_ni)
		state	<= #2 `MS_IDLE;
	else case (state)
	
	`MS_IDLE: begin
		if (cpu_read_i)				state	<= #2 `MS_CPU;
		else if (vid_read_i && !cpu_write_i)	state	<= #2 `MS_VGA;
	end
	
	`MS_CPU: begin
		if (rdcnt == 7 && mem_ready_i)	state	<= #2 `MS_IDLE;
	end
	
	`MS_VGA: begin
		if (rdcnt == 7 && mem_ready_i)	state	<= #2 `MS_IDLE;
	end
	
	endcase


always @(posedge clock_i)
	if (!reset_ni)		rdcnt	<= #2 0;
	else if (mem_ready_i)	rdcnt	<= #2 rdcnt + 1;


endmodule	// mem_switch
