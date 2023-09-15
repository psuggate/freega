/***************************************************************************
 *                                                                         *
 *   div_ctrl.v - Drives a SiI or TI DVI driver IC.                        *
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
module dvi_ctrl (
	clock_i,	// VGA dot clock
	reset_ni,
	
	hsync_i,
	vsync_i,
	de_i,
	red_i,
	green_i,
	blue_i,
	
	dvi_clock_o,
	dvi_hsync_o,
	dvi_vsync_o,
	dvi_de_o,
	dvi_red_o,
	dvi_green_o,
	dvi_blue_o,
	
	dvi_msen_i,
	dvi_pd_no
);

parameter	DUALEDGEMODE	= 0;
parameter	CMSB	= 7 - 4*DUALEDGEMODE;

input	clock_i;	// VGA dot clock
input	reset_ni;

input	hsync_i;
input	vsync_i;
input	de_i;
input	[7:0]	red_i;
input	[7:0]	green_i;
input	[7:0]	blue_i;

output		dvi_clock_o;
output reg	dvi_hsync_o;
output reg	dvi_vsync_o;
output reg	dvi_de_o;
output reg	[CMSB:0]	dvi_red_o;
output reg	[CMSB:0]	dvi_green_o;
output reg	[CMSB:0]	dvi_blue_o;

input	dvi_msen_i;
output	dvi_pd_no;


assign	dvi_clock_o	= clock_i;
assign	dvi_pd_no	= 1'b1;


// TODO: Support DDR mode.
always @(posedge clock_i) begin
	if (!reset_ni) begin
		dvi_de_o	<= #1 0;
		dvi_hsync_o	<= #1 0;
		dvi_vsync_o	<= #1 0;
		dvi_red_o	<= #1 0;
		dvi_green_o	<= #1 0;
		dvi_blue_o	<= #1 0;
	end
	else begin // if (dvi_msen_i) begin
		dvi_de_o	<= #1 de_i;
		dvi_hsync_o	<= #1 hsync_i;
		dvi_vsync_o	<= #1 vsync_i;
		dvi_red_o	<= #1 red_i;
		dvi_green_o	<= #1 green_i;
		dvi_blue_o	<= #1 blue_i;
	end
end


endmodule	// dvi_ctrl
