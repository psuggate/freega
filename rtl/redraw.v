/***************************************************************************
 *                                                                         *
 *   redraw.v - Redraws a screen.                                          *
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
module redraw (
	memclk_i,
	dotclk_i,
	reset_ni,
	enable_i,
	
	m_read_o,
	m_rack_i,
	m_ready_i,
	m_busy_i,
	m_addr_o,
	m_data_i
);

parameter	ADDRESS	= 20;	// 1 Mega-Words (4MB)
parameter	ASB	= ADDRESS - 1;

input		memclk_i;
input		dotclk_i;
input		reset_ni;
input		enable_i;

output		m_read_o;
input		m_rack_i;
input		m_ready_i;
input		m_busy_i;
output	[ASB:0]	m_addr_o;	// 1024 MB RAM!
input	[31:0]	m_data_i;





endmodule	// redraw
