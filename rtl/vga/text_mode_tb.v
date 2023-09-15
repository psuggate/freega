`timescale 1ns/100ps
module text_mode_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset	= 0;

wire	de, vsync, hsync;

wire	de_w, vsync_w, hsync_w;
wire	r, g, b;

wire	[11:0]	addr;
wire	[15:0]	data_to	= 16'h07_30;

integer	ii, jj;

assign	de	= (jj >= 40) && (jj <440) && (ii<720);
assign	hsync	= (ii > 760) && (ii < 780);
assign	vsync	= (jj > 460) && (jj < 465);

initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5
	reset	<= 1;
	
	#40
	reset	<= 0;
	
	#10
	for (jj=0; jj<480; jj=jj+1) begin
		for (ii=0; ii<800; ii=ii+1)
			#10 ;
	end
	
	#50
	$finish;
end	// Sim


text_mode TM0 (
	.dot_clk_i	(clock),
	.chr_clk_i	(chr_clk),
	.reset_ni	(~reset),
	
	.de_i		(de),
	.vsync_i	(vsync),
	.hsync_i	(hsync),
	
	.addr_o		(addr),
	.data_i		(data_to),
	
	.vsync_o	(vsync_w),
	.hsync_o	(hsync_w),
	.de_o		(de_w),
	.red_o		(r),
	.green_o	(g),
	.blue_o		(b)
);


// Divide by 9 .
div9 DIV0 (
	.clock_i	(clock),
	.reset_ni	(1),
	.clock_o	(chr_clk)
);


endmodule	// text_mode_tb
