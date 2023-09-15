`timescale 1ns/100ps
module th_tb;

parameter	WIDTH		= 18;
parameter	INSTRUCTION	= 32;
parameter	PAGEWIDTH	= 10;
parameter	ADDRESS		= WIDTH + PAGEWIDTH;

parameter	MSB	= WIDTH-1;
parameter	ISB	= INSTRUCTION-1;
parameter	ASB	= ADDRESS-1;
parameter	PSB	= PAGEWIDTH-1;


reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset_n	= 1;

reg	[31:0]	mem [15:0];

wire	read, rack;
reg	ready	= 0;
wire	[ASB:0]	addr;
wire	[31:0]	data;
// reg	[31:0]	data;

wire	[1:0]	leds;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	// Reset sequence must clear cache tag valids which are stored in
	// distributed RAM so takes n-cycles.
	#5
	reset_n	<= 0;
	
	#20
	reset_n	<= 1;
	
	#800
	$finish;
end	// Sim


assign	#2 rack	= read;

always @(posedge clock)
	if (!reset_n)	ready	<= #2 0;
	else		ready	<= #2 read;

/*
always @(posedge clock)
	if (read)	data	<= #2 mem [addr [3:0]];
*/

th_top TOP0 (
	.clock_i	(clock),
	.reset_ni	(reset_n),
	.enable_i	(1'b1),
	
	.i_read_o	(read),
	.i_rack_i	(rack),
	.i_ready_i	(ready),
	.i_addr_o	(addr),
	.i_data_i	(data),
	
// 	.leds_o		(leds),
	
	.m_read_o	(),
	.m_write_o	(),
	.m_rack_i	(0),
	.m_wack_i	(0),
	.m_ready_i	(0),
	.m_busy_i	(0),
	.m_addr_o	(),
	.m_bes_ni	(0),
	.m_bes_no	(),
	.m_data_i	(0),
	.m_data_o	()
);


//---------------------------------------------------------------------------
//  A program mem.
//

RAMB16_S36_S36 #(
	`include "prog.v"
) BRAM0 (
	.DIA	(0),
	.DIPA	(0),
	.ADDRA	(addr [8:0]),
	.ENA	(1'b1),
	.WEA	(0),
	.SSRA	(0),
	.CLKA	(clock),
	.DOA	(data),
	.DOPA	(),
	
	.DIB	(0),
	.DIPB	(0),
	.ADDRB	(0),
	.ENB	(0),
	.WEB	(0),
	.SSRB	(0),
	.CLKB	(0),
	.DOB	(),
	.DOPB	()
);


endmodule	// th_tb
