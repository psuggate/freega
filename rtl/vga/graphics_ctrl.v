/***************************************************************************
 *                                                                         *
 *   graphics_ctrl.v - The VGA grapics controller.                         *
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
module graphics_ctrl (
	clock_i,
	reset_ni,
	
	set_reset_mask_i,	// Masks for read/write operations
	set_reset_en_i,
	colour_cmp_mask_i,
	colour_dont_care_i,
	bit_mask_i,
	
	data_rotate_i,
	logic_function_i,
	read_map_sel_i,
	read_mode_i,
	mem_access_mode_i,
	graphics_shift_i,
	graphics256_ctrl_i,
	disp_gen_mode_i,
	plane_pairing_i,
	mem_map_mode_i
);

input		clock_i;
input		reset_ni;

input	[3:0]	set_reset_mask_i;
input	[3:0]	set_reset_en_i;
input	[3:0]	colour_cmp_mask_i;
input	[3:0]	colour_dont_care_i;
input	[7:0]	bit_mask_i;

input	[2:0]	data_rotate_i;
input	[1:0]	logic_function_i;
input	[1:0]	read_map_sel_i;		// Text, multi-plane, packed-pixel
input	[1:0]	write_mode_i;
input		read_mode_i;
input		mem_access_mode_i;
input		graphics_shift_i;
input		graphics256_ctrl_i;
input		disp_gen_mode_i;
input		plane_pairing_i;
input	[1:0]	mem_map_mode_i;


endmodule	// graphics_ctrl
