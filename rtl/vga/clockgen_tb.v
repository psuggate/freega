module clock_gen_tb;
	
	reg	clk_in	= 1;
	always	#5	clk_in	<= ~clk_in;
	
	reg	[7:0]	div	= 36;
	
	initial begin : Sim
		$display ("Time CLKI CLKO");
		$monitor ("%5t  %b   %b  ", $time, clk_in, clk_out);
		
		#1000
		$finish;
	end	// Sim
	
	clockgen CG0 (
		.clk200_i	(clk_in),
		.div_i		(div),
		.clk_o		(clk_out)
	);
	
endmodule	// clock_gen_tb
