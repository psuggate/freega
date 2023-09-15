`timescale 1ns/100ps
module vga_tta_top_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset	= 0;

wire	fetch, abort;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5
	reset	<= 1;
	
	#30
	reset	<= 0;
	
	#2000
	$finish;
end	// Sim


// Fetch an entire cache-line.
reg	[3:0]	count	= 0;
wire	ready;
always @(posedge clock) begin
	if (reset)
		count	<= #1 0;
	else if (abort)
		count	<= #1 0;
	else if (fetch || count != 0)
		count	<= #1 count + 1;
end


wire	[15:0]	addr;
wire	[31:0]	data_to;
reg	[31:0]	imem [0:511];
assign	#1 data_to	= imem [{addr [8:4], count}];
assign	#1 ready	= fetch || (count != 0);

wire	[3:0]	maddr;


vga_tta_top TTATOP0 (
	.clock_i	(clock),
	.reset_ni	(~reset),
	
	.ifetch_o	(fetch),	// Get a new cache-line from the L1 cache
	.iabort_o	(abort),
	.iready_i	(ready),
	.iaddr_o	(addr),
	.idata_i	(data_to),
	
	.m_read_o	(),	// VGA data to the vga contoller
	.m_write_o	(),
	.m_ready_i	(0),
	.m_addr_o	(maddr),
	.m_data_i	(0),
	.m_data_o	()
);


// Load some instructions into the instruction RAM.
integer	i;
initial begin : Init
	`include "prog.v"
end	// Init


endmodule	// vga_tta_top_tb
