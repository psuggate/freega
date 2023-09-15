`timescale 1ns/100ps
module charclock_gen_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset_n	= 0;


reg	mode	= 0;
wire	char_clock;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#25
	reset_n	<= 1;
	
	#500
	mode	<= 1;
	
	#500
	$finish;
end	// Sim


charclock_gen CLKGEN0 (
	.clock_i	(clock),
	.mode8_i	(mode),
	.clock_o	(char_clock)
);


endmodule	// charclock_gen_tb
