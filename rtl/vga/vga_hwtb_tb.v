`timescale 1ns/100ps
module vga_hwtb_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset	= 0;

wire	vsync, hsync;
wire	[7:0]	r, g, b;

initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5
	reset	<= 1;
	
	#40
	reset	<= 0;
	
	#500000
	$write ("\n");
	$finish;
end	// Sim


vga_hwtb VGA0 (
	.clk50		(clock),	// Character clock
	.reset		(reset),
	
	.dvi_hsync	(hsync),
	.dvi_vsync	(vsync),
	.dvi_red	(r),
	.dvi_green	(g),
	.dvi_blue	(b)
);


endmodule	// vga_hwtb_tb
