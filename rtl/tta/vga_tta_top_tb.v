`timescale 1ns/100ps
module vga_tta_top_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset_n	= 1;

wire	fetch, abort;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5
	reset_n	<= 0;
	
	#30
	reset_n	<= 1;
	
	#2000
	$finish;
end	// Sim


// Fetch an entire cache-line.
reg	[3:0]	count	= 0;
wire	ready;
always @(posedge clock) begin
	if (!reset_n)
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


vga_tta_top #(
	.WIDTH		(32),
	.ADDRESS	(28),
	.PAGEWIDTH	(10)
) TTATOP0 (
	.clock_i	(clock),
	.reset_ni	(reset_n),
	.enable_i	(1'b1),
	
	.i_read_o	(fetch),	// Get a new cache-line from the L1 cache
	.i_rack_i	(rack),
	.i_ready_i	(hit),
	.i_addr_o	(addr),
	.i_data_i	(instr),
`ifdef __debug
	.leds_o		(leds),
`endif
	.m_read_o	(),
	.m_write_o	(),
	.m_rack_i	(0),
	.m_wack_i	(0),
	.m_ready_i	(0),
	.m_addr_o	(maddr),
	.m_bes_ni	(0),
	.m_bes_no	(),
	.m_data_i	(0),
	.m_data_o	()
);


endmodule	// vga_tta_top_tb
