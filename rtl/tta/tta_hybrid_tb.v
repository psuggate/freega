`timescale 1ns/100ps
module tta_hybrid_tb;

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

wire	fetch, hit, rack;
wire	[ASB:0]	pc;
wire	[ISB:0]	instr;


`define	MEMSIZE	512
wire	m_read;
wire	m_rack;
reg	m_ready	= 0;
wire	[PSB:0]	m_addr;
wire	[ISB:0]	m_data_to;


// Block memory signals.
wire	b_read, b_write, b_ready, b_busy;
wire	#2 b_rack	= b_read && !b_busy;
wire	#2 b_wack	= b_write && !b_busy;
wire	[27:0]	b_addr;
wire	[3:0]	b_bes_n;
wire	[31:0]	b_data_to, b_data_from;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5
	reset_n	<= 0;
	
	#20
	reset_n	<= 1;
	
	#800
	$finish;
end	// Sim


wire	mark_to, mark_from;

mcache #(
	.WIDTH		(INSTRUCTION),
	.ADDRESS	(PAGEWIDTH)
) CACHE0 (
	.clock_i	(clock),
	.reset_ni	(reset_n),
	
	.m_read_i	(fetch),
	.m_mark_i	(mark_to),
	.m_mark_o	(mark_from),
	.m_rack_o	(rack),
	.m_ready_o	(hit),
	.m_addr_i	(pc [PSB:0]),
	.m_data_o	(instr),
	
	.s_read_o	(m_read),
	.s_ready_i	(m_ready),
	.s_rack_i	(m_rack),
	.s_addr_o	(m_addr),
	.s_data_i	(m_data_to)
);


tta_hybrid #(
	.WIDTH		(WIDTH),
	.INSTRUCTION	(INSTRUCTION),
	.ADDRESS	(ADDRESS),
	.PAGEWIDTH	(PAGEWIDTH)
) TTA0 (
	.clock_i	(clock),
	.reset_ni	(reset_n),
	.enable_i	(1'b1),
	
	.i_read_o	(fetch),
	.i_mark_o	(mark_to),
	.i_rack_i	(rack),
	.i_mark_i	(mark_from),
	.i_addr_o	(pc),
	.i_ready_i	(hit),
	.i_data_i	(instr),
	
	.m_read_o	(b_read),	// TTA to Memory
	.m_write_o	(b_write),
	.m_rack_i	(b_rack),
	.m_wack_i	(b_wack),
	.m_ready_i	(b_ready),
	.m_busy_i	(b_busy),
	.m_addr_o	(b_addr),
	.m_bes_ni	(0),
	.m_bes_no	(b_bes_n),
	.m_data_i	(b_data_from),
	.m_data_o	(b_data_to)
);


bram4k RAM0 (
	.clock_i	(clock),
	.reset_ni	(reset_n),
	
	.read_i		(b_read),
	.write_i	(b_write),
	.ready_o	(b_ready),
	.busy_o		(b_busy),
	.addr_i		(b_addr [9:0]),
	.bes_ni		(b_bes_n),
	.data_i		(b_data_to),
	.data_o		(b_data_from)
);


assign	#2 m_rack	= m_read;
wire	[8:0]	addr		= m_addr [8:0];
always @(posedge clock)
	if (!reset_n)	m_ready	<= #2 0;
	else		m_ready	<= #2 m_read;

/*
assign	#2 m_rack	= m_read;
reg	reading	= 0;
reg	[2:0]	r_addr;
wire	done;
always @(posedge clock)
	if (m_read)	reading	<= #2 1;
	else if (done)	reading	<= #2 0;

reg	[2:0]	rd_count	= 0;
assign	#2 done	= (rd_count == 7 && reading);
always @(posedge clock)
	if (reading) begin
		m_ready		<= #2 1;
		r_addr [2:0]	<= #2 rd_count < 7 ? r_addr [2:0] + 1 : r_addr;
		rd_count	<= #2 rd_count + 1;
	end else if (m_read) begin
		r_addr		<= #2 m_addr [2:0];
		m_ready		<= #2 1;
	end else
		m_ready		<= #2 0;


wire	[8:0] #2 addr	= reading ? {m_addr [8:3], r_addr} : m_addr [8:3] ;
*/
RAMB16_S36_S36 #(
	`include "prog.v"
) BRAM0 (
	.DIA	(0),
	.DIPA	(0),
	.ADDRA	(addr),
	.ENA	(1'b1),
	.WEA	(0),
	.SSRA	(0),
	.CLKA	(clock),
	.DOA	(m_data_to),
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


endmodule	// tta_hybrid_tb
