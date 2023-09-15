`timescale 1ns/100ps
module testclks;

reg	clk100	= 1;
reg	clk50	= 1;
reg	reset_n	= 1;

always	#5 clk100	<= ~clk100;
always	#10 clk50	<= ~clk50;

reg	read_f	= 0;
reg	read_s	= 0;
reg	ready_s	= 0;
reg	ack_f	= 0;
wire	ack_s;

assign	#2 ack_s	= read_s;

initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#2	reset_n	<= 0;
	#20	reset_n	<= 1;
	
	#20	read_f	<= 1;
	while	(!ack_s)	#10 ;
	read_f	<= 0;
	
	#30
	ready_s	<= 1;
	
	#20
	ready_s	<= 0;
	
	#200
	$finish;
end	// Sim

always @(posedge clk50)
	read_s	<= #2 read_f;

always @(posedge clk100)
	if (ack_f)	ack_f	<= #2 0;
	else		ack_f	<= #2 ack_s;

endmodule	// testclks
