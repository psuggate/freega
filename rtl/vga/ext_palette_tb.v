`timescale 1ns/100ps
module ext_palette_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset_n	= 0;

reg		de	= 0;
reg		write	= 0;
reg		wrset	= 0;
reg	[7:0]	waddr;
reg	[7:0]	wdata;

reg		read	= 0;
reg		rdset	= 0;
reg	[7:0]	raddr;
wire	[7:0]	rdata;

wire	[1:0]	readmode;

reg	[7:0]	colour	= 0;

wire	[7:0]	red;
wire	[7:0]	green;
wire	[7:0]	blue;

wire	de_w;

integer	i;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#65
	reset_n	<= 1;
	
	// Set the palette write address.
	#10
	wrset	<= 1;
	waddr	<= 0;
	
	#10
	wrset	<= 0;
	
	// Set all 256 palette RGB values.
	for (i=0; i<768; i=i+1)
	begin
		#10
		write	<= 1;
		wdata	<= $random;
	end
	
	#10
	write	<= 0;
	
	#10
	raddr	<= 255;
	rdset	<= 1;
	
	#10
	rdset	<= 0;
	
	#30
	read	<= 1;
	
	#10
	read	<= 0;
	
	#30
	read	<= 1;
	
	#10
	read	<= 0;
	
	#30
	read	<= 1;
	
	#10
	read	<= 0;
	
	// Read all 256 colours.
	for (i=0; i<256; i=i+1)
	begin
		#10
		de	<= 1;
		colour	<= i;
	end
	
	#10
	de	<= 0;
	
	#60
	$finish;
end	// Sim


ext_palette PAL0 (
	.clock_i	(clock),	// Character clock
	.reset_ni	(reset_n),
	
	.read_i		(read),
	.write_i	(write),
	.rd_addr_set_i	(rdset),
	.wr_addr_set_i	(wrset),
	.raddr_i	(raddr),
	.waddr_i	(waddr),
	.data_i		(wdata),
	.data_o		(rdata),
	
	.de_i		(de),
	.de_o		(de_w),
	
	.pel_mask_i	(8'hff),
	.readmode_o	(readmode),
	
	.colour_i	(colour),
	
	.red_o		(red),
	.green_o	(green),
	.blue_o		(blue)
);


endmodule	// ext_palette
