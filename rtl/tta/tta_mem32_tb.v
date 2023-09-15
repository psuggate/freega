`timescale 1ns/100ps
module tta_mem32_tb;

parameter	WIDTH	= 18;
parameter	ADDRESS	= 28;
parameter	MSB	= WIDTH - 1;
parameter	ASB	= ADDRESS - 1;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset_n	= 1;
reg	enable	= 0;

reg		addr_sel	= 0;
reg	[ASB:0]	addr;
reg		data_rd	= 0;
reg		data_wr	= 0;
reg	[MSB:0]	data_to, m_data_to;

wire	m_ready;
reg	m_busy	= 0;

wire	[ASB:0]	m_addr;
wire	[MSB:0]	data_from, m_data_from;

wire	m_read, m_write, stall_n;

reg	[MSB:0]	mem [255:0];

initial begin : Sim
	$write ("%% ");
	$dumpfile ("mem.vcd");
	$dumpvars;
	
	#2	reset_n		<= 0;
	#20	reset_n		<= 1;
	
	#10	enable		<= 1;
	
	#10	addr_sel	<= 1;
		addr		<= $random;
	#10	addr_sel	<= 0;
		addr		<= 'bx;
	
	#10	data_rd		<= 1;
	#10	data_rd		<= 0;
	
	#400
	$finish;
end	// Sim


reg	[3:0]	readies	= 0;
assign	m_ready	= readies [3];
always @(posedge clock)
	if (!reset_n) begin
		readies	<= #2 0;
	end else if (enable) begin
		if (m_read && readies == 0)
			readies	<= #2 {readies [2:0], 1'b1};
		else
			readies	<= #2 {readies [2:0], 1'b0};
	end

always @(posedge clock)
	if (m_read)
		m_data_to	<= #32 mem [m_raddr [7:0]];

always @(posedge clock)
	if (m_write)
		mem [m_waddr [7:0]]	<= #2 m_data_from;


wire	[3:0]	rbes_n;
tta_mem32 #(
	.WIDTH		(WIDTH),
	.ADDRESS	(ADDRESS)
) MEM0 (
	.clock_i	(clock),
	.reset_ni	(reset_n),
	.enable_i	(enable),	// TODO: Why have an `enable'?
	
	.c_stall_no	(stall_n),
	
	.c_raddr_ti	(raddr_t),	// Trigger address register change
	.c_raddr_i	(raddr),
	.c_rbes_no	(rbes_n),
	.c_rdata_o	(data_from),
	
	.c_reglo_i	(data_wr),
	.c_reghi_i	(data_wr),
	.c_waddr_ti	(waddr_t),
	.c_waddr_i	(waddr),
	.c_wbes_ni	(4'b0),
	.c_wdata_i	(data_to),
	
	.m_read_o	(m_read),
	.m_write_o	(m_write),
	.m_rack_i	(),
	.m_wack_i	(),
	.m_ready_i	(readies [3]),
	.m_busy_i	(m_busy),
	.m_addr_o	(m_waddr),
	.m_bes_no	(),
	.m_bes_ni	(4'b0),
	.m_data_i	(m_data_to),
	.m_data_o	(m_data_from)
);


integer	ii;
initial begin : Init
	for (ii=0; ii<255; ii=ii+1)
		mem [ii]	<= $random;
end	// Init


endmodule	// tta_mem32_tb
