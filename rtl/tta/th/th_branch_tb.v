`timescale 1ns/100ps
module th_branch_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset_n	= 1;

wire	d_nop;

wire	[9:0]	f_pc;
wire	f_vld0, f_vld1;
wire	[6:0]	f_tag0, f_tag1;
wire	f_lookup, f_busy;

wire	s_lookup, s_ack, s_update;
wire	[3:0]	s_l_addr, s_u_addr;
wire	[9:0]	s_pc;

wire	b_update;
wire	[6:0]	b_newtag;

// reg	f_ack		= 0;
reg	s_hit		= 0;
reg	s_miss		= 0;
reg	s_pack		= 0;
reg	branch		= 0;
reg	[9:0]	dest	= 0;

reg	[31:0]	i1, i0;
reg	n1	= 1, n0	= 1;
reg	d_packed	= 0;


assign	#2 f_ack	= f_lookup;
assign	f_busy		= 0;

assign	b_update	= 0;

assign	d_nop	= n1;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5	reset_n	<= 0;
	#20	reset_n	<= 1;
	
// 	#10	f_ack	<= 1;
	#20	s_hit	<= 1;
	#10	s_pack	<= 1;
// 	#10	f_ack	<= 0;
	#20	s_hit	<= 0;	s_pack	<= 0;
	
	#10	s_hit	<= 1;
	#10	s_hit	<= 0;
	#10	s_hit	<= 1;
	
	#800
	$finish;
end	// Sim


always @(posedge clock)
	if (!reset_n)	{i1, i0}	<= #2 {64'bx};
	else if (f_ack)	{i1, i0}	<= #2 {i0, {22{1'b0}}, f_pc};
	else		{i1, i0}	<= #2 {i0, 32'bx};

always @(posedge clock)
	if (!reset_n)	{n1, n0}	<= #2 2'b11;
	else		{n1, n0}	<= #2 {n0, ~f_ack};

always @(posedge clock)
	d_packed	<= #2 s_pack;


th_branch FETCH0 (
	.clock_i	(clock),
	.reset_ni	(reset_n),
	.enable_i	(1'b1),
	
	.de_lookup_i	(0),
	.de_nop_i	(0),
	.de_ack_o	(),
	.de_bra_imm_i	(branch),
	.de_bra_reg_i	(0),
	.de_pc_bra_i	(dest),
	
	.if_lookup_o	(f_lookup),
	.if_ack_i	(f_ack),
	.if_packed_i	(s_pack),
	.if_hit_i	(s_hit),
	.if_pc_o	(f_pc),
	.if_pre0_o	(f_pre0),
	.if_tag0_o	(f_tag0),
	.if_vld0_o	(f_vld0),
	.if_pre1_o	(f_pre1),
	.if_tag1_o	(f_tag1),
	.if_vld1_o	(f_vld1),
	
	.is_busy_i	(0),
	.is_update_i	(b_update),
	.is_newtag_i	(b_newtag),
	.is_lru_ni	(b_lru_n),
	.is_bank_i	(b_bank)
);


endmodule	// th_branch_tb
