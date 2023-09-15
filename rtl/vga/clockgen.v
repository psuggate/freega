/***************************************************************************
 *                                                                         *
 *   clockgen.v - Generates the two VGA clocks, 25.175 MHz and 28.322 MHz, *
 *     from a 50 MHz input clock fed into a Xilinx DCM primitive.          *
 *     The DCM also generates 50 MHz and 100 MHz clocks too. The 50 MHz    *
 *     clock can be used to generate 800x600@75 Hz. The 100 MHz clock can  *
 *     generate the dot-clock for 1024x768@85 Hz, 1280x960@60 Hz, or       *
 *     1280x1024@54 Hz. When driving an LCD monitor, overdraw periods can  *
 *     be shorter, and this should enable 1280x1024@60 Hz to work on an    *
 *     LCD too.                                                            *
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
module clockgen (
	clk50_i,
	reset_i,
	
	clksel_i,	// 2-bit value, only values 0 & 1 are defined
	clock_o,
	locked_o
);

input		clk50_i;	// 50 MHz clock
input		reset_i;

input	[1:0]	clksel_i;
output		clock_o;
output		locked_o;


// This will only work for Xilinx
wire	clk25, clk28, clk_fb, clk100;
wire	GND	= 0;


// Allow either the 25 MHz or the 28.333 MHz clocks to be used for the dot-
// clock.
BUFGMUX	VGACLK0 (  
	.I0	(clk25),
	.I1	(clk28),
	.S	(clksel_i [0]),
	.O	(clock_o)
);

/*
// TODO: Allow 50 MHz & 100 MHz clocks to be used as the dot-clock also.
reg	dot_clock;
always @(clk25, clk28, clk_fb, clk100, clksel_i)
begin
	case (clksel_i)
	2'b00:	dot_clock	<= clk25;
	2'b01:	dot_clock	<= clk28;
	2'b10:	dot_clock	<= clk_fb;
	2'b11:	dot_clock	<= clk100;
	endcase
end

BUFGMUX clkmux0 (
	.I0	(1'b0),
	.I1	(dot_clock),
	.S	(locked_o),
	.O	(clock_o)
);
*/

`ifdef __icarus
reg	clk25_r	= 1;
reg	clk28_r	= 1;
reg	locked	= 0;

assign	clk25	= clk25_r;
assign	clk28	= clk25_r;	// FIXME

assign	locked_o	= locked;

always @(posedge clk50_i)
begin
	if (reset_i)
	begin
		clk25_r	<= 1;
		locked	<= 0;
	end
	else
	begin
		clk25_r	<= ~clk25_r;
		locked	<= 1;
	end
end

`else
// Instantiate the DCM primitive
defparam vga_dcm.CLKIN_PERIOD = 20 ;
defparam vga_dcm.DLL_FREQUENCY_MODE = "LOW" ;
defparam vga_dcm.DUTY_CYCLE_CORRECTION = "TRUE" ;
defparam vga_dcm.STARTUP_WAIT = "FALSE";
defparam vga_dcm.CLKDV_DIVIDE = 2 ;
defparam vga_dcm.CLKFX_MULTIPLY = 17 ;
defparam vga_dcm.CLKFX_DIVIDE = 30 ;

DCM vga_dcm (
	.CLKIN	(clk50_i),
	.CLKFB	(clk_fb),
	.DSSEN	(GND),
	.PSEN	(GND),
	.RST	(reset_i),
	.CLK0	(clk_fb),
	.CLK2X	(clk100),
	.CLKDV	(clk25),	// 25 MHz VGA dot clock
	.CLKFX	(clk28),
	.LOCKED	(locked_o)
);
`endif


endmodule	// clockgen
