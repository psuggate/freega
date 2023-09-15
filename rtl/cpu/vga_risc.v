/***************************************************************************
 *                                                                         *
 *   vga_risc.v - A small 18-bit RISC CPU for converting VGA port accesses *
 *     into external register values and vice versa.                       *
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

/*

Instructions:
	
	1 arg:
		BRA
	
	2 args:
		LOAD, STORE
		NOT
		CMP
	
	3 args:
		AND, OR, XOR
		ADD, ADC, SUB, SBB, MUL
	
*/


`timescale 1ns/100ps
module vga_risc (
	clock_i,
	reset_ni,
	
	pc_o,
	hit_i,
	instr_i,
	
	newline_o,
	newpage_o,
	
	m_read_o,	// External memory. When used as part of FreeGA, this
	m_write_o,	// is a MMIO block.
	m_ready_i,
	m_addr_o,
	m_data_i,
	m_data_o
);

parameter	AW	= 16;
parameter	IW	= 32;
parameter	AMSB	= AW-1;
parameter	IMSB	= IW-1;

parameter	IAMSB	= 8;
parameter	IWORDS	= 512;
parameter	MAMSB	= 3;
parameter	MDMSB	= 10;

input	clock_i;
input	reset_ni;

output	[AMSB:0]	pc_o;
input	hit_i;
input	[IMSB:0]	instr_i;

output	newline_o;
output	newpage_o;

output	m_read_o;
output	m_write_o;
input	m_ready_i;
output	[MAMSB:0]	m_addr_o;
input	[MDMSB:0]	m_data_i;
output	[MDMSB:0]	m_data_o;


endmodule	// vga_risc
