`timescale 1ns/100ps
module sdrtest_tb;

reg	clk50	= 1;
always	#10 clk50	<= ~clk50;

reg	reset_n	= 1;
wire	[1:0]	leds;
wire		done;

// SDRAM signals.
wire	clk, cke;
wire	cs_n, ras_n, cas_n, we_n;
wire	[1:0]	ba;
wire	[12:0]	a;
wire	[1:0]	dm;
wire	[15:0]	dq;


initial begin : Sim
	#5	reset_n	<= 0;
	#80	reset_n	<= 1;
	
	while (!done)	#10;
	
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#8000
	$finish;
end	// Sim


sdrtest SDRTEST0 (
	.clk50		(clk50),
	
	.sdr_clk	(clk),
	.sdr_cke	(cke),
	.sdr_cs_n	(cs_n),
	.sdr_ras_n	(ras_n),
	.sdr_cas_n	(cas_n),
	.sdr_we_n	(we_n),
	.sdr_ba		(ba),
	.sdr_a		(a),
	.sdr_dm		(dm),
	.sdr_dq		(dq),
	
	.init_done	(done),
	.pci_disable	(),
	.pci_rst_n	(reset_n),
	.leds		(leds)
);


mt48lc4m16a2 MEM0 (
	.Dq	(dq),
	.Addr	(a [11:0]),
	.Ba	(ba),
	.Clk	(clk),
	.Cke	(cke),
	.Cs_n	(cs_n),
	.Ras_n	(ras_n),
	.Cas_n	(cas_n),
	.We_n	(we_n),
	.Dqm	(dm)
);


endmodule	// sdrtest_tb
