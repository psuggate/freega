`timescale 1ns/100ps
module wb_demo;


reg	CLK	= 0;
reg	RST	= 0;
reg	CYC_O	= 0;
wire	STB_O	= CYC_O;
reg	WE_O	= 0;
reg	ACK_I	= 0;
reg	[9:0]	ADR_O	= 'bx;
reg	[1:0]	SEL_O	= 'bx;
reg	[15:0]	DAT_O	= 'bx;


always	#5 CLK	<= ~CLK;


initial begin : Sim
	$dumpfile("tb.vcd");
	$dumpvars;
	
	#17 CYC_O = 1; WE_O = 1; ADR_O = $random; SEL_O = 2'b11; DAT_O = $random;
	#10 ACK_I = 1;
	#10 CYC_O = 0; WE_O = 0; ADR_O = 'bx; SEL_O = 'bx; DAT_O = 'bx; ACK_I = 0;
	
	#10 $finish;
end	// Sim


endmodule	// wb_demo
