`timescale 1ns/100ps
module th_second_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset_n	= 1;

// A small instruction memory.
reg	[31:0]	mem [15:0];

wire	read, rack;
reg	ready	= 0;
wire	[9:0]	addr;
reg	[31:0]	data;


reg	s_lookup	= 0;
reg	s_packed	= 0;
reg	s_hit	= 0;
reg	s_miss	= 0;
wire	s_busy, s_ack;
reg	[9:0]	s_pc	= 0;
reg	[3:0]	s_l_addr	= 0;

wire	s_valid, s_nop;			// Instruction + flags to decode stage
wire	[30:0]	s_instr;

wire	f_update, f_packed;		// Packed flag update signals
wire	[3:0]	f_u_addr;

wire	b_update, b_bank, b_lru_n;	// Tag update signals
wire	[6:0]	b_newtag;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5	reset_n	<= 0;
	#20	reset_n	<= 1;
	
	#10	s_lookup	<= 1;	s_miss	<= 1;
	#10	s_lookup	<= 0;	s_miss	<= 0;
	
	#100	s_lookup	<= 1;	s_hit	<= 1;	s_l_addr	<= 9;
	#10	s_lookup	<= 0;	s_hit	<= 0;
	
	#800
	$finish;
end	// Sim


th_second #(
	.ADDRESS	(10)
) SECOND0 (
	.clock_i	(clock),
	.reset_ni	(reset_n),
	.enable_i	(1'b1),
	
	.m_read_o	(read),
	.m_rack_i	(rack),
	.m_ready_i	(ready),
	.m_addr_o	(addr),
	.m_data_i	(data),
	
	.if_lookup_i	(s_lookup),
	.if_l_addr_i	(s_l_addr),
	.if_packed_i	(s_packed),
	.if_ack_o	(s_ack),
	.if_hit_i	(s_hit),
	.if_miss_i	(s_miss),
	.if_pc_i	(s_pc),
	.if_busy_o	(s_busy),
	.if_update_o	(f_update),
	.if_u_addr_o	(f_u_addr),
	.if_packed_o	(f_packed),
	
	.br_update_o	(b_update),
	.br_newtag_o	(b_newtag),
	.br_lru_no	(b_lru_n),
	.br_bank_o	(b_bank),
	
	.de_instr_o	(s_instr),
	.de_valid_o	(s_valid),
	.de_nop_o	(s_nop)
);


//---------------------------------------------------------------------------
//  A small instruction memory.
//
assign	#2 rack	= read;

always @(posedge clock)
	if (!reset_n)	ready	<= #2 0;
	else		ready	<= #2 read;

always @(posedge clock)
	if (read)	data	<= #2 mem [addr [3:0]];


initial begin : Init
	mem [0]	<= 32'h0000_0000;	// NOP
	mem [1]	<= 32'h1000_0000;	// NOP
	mem [2]	<= 32'h1000_0000;	// NOPx2
	mem [3]	<= 32'h0000_0000;	// NOP
	
	mem [4]	<= 32'h0000_0000;	// NOP
	mem [5]	<= 32'h0000_0000;	// NOP
	mem [6]	<= 32'h0000_0000;	// NOP
	mem [7]	<= 32'h0000_0000;	// NOP
end	// Init


endmodule	// th_second_tb
