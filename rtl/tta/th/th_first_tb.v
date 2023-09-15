`timescale 1ns/100ps
module th_first_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset_n	= 1;

reg	f_lookup	= 0;
reg	[9:0]	f_pc	= 0;
reg	f_vld0	= 0, f_vld1	= 0;
reg	[6:0]	f_tag0, f_tag1;
wire	f_ack, f_busy;

wire	s_lookup, s_ack, s_packed_to, s_packed_from, s_hit, s_miss, s_update;
wire	[3:0]	s_l_addr, s_u_addr;
wire	[9:0]	s_pc;


assign	#2 s_ack	= s_lookup;
assign	s_busy		= 0;
assign	s_update	= 0;
assign	s_packed_from	= 0;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5	reset_n	<= 0;
	#20	reset_n	<= 1;
	
	#10	f_lookup	<= 1;	f_pc	<= 16;
	f_vld0	<= 1; f_tag0	<= 1;
	
	#10 f_vld1	<= 1; f_tag1	<= 2;
	
	#10	f_lookup	<= 0;
	
	#800
	$finish;
end	// Sim


th_first #(
	.ADDRESS	(10)
) FETCH0 (
	.clock_i	(clock),
	.reset_ni	(reset_n),
	.enable_i	(1'b1),
	
	.br_lookup_i	(f_lookup),
	.br_pc_i	(f_pc),
	.br_ack_o	(f_ack),
	.br_busy_o	(f_busy),
	.br_vld0_i	(f_vld0),
	.br_tag0_i	(f_tag0),
	.br_pre0_i	(f_pre0),
	.br_vld1_i	(f_vld1),
	.br_tag1_i	(f_tag1),
	.br_pre1_i	(f_pre1),
	
	.is_lookup_o	(s_lookup),
	.is_ack_i	(s_ack),
	.is_l_addr_o	(s_l_addr),
	.is_packed_o	(s_packed_to),
	.is_busy_i	(s_busy),
	.is_pc_o	(s_pc),
	.is_hit_o	(s_hit),
	.is_miss_o	(s_miss),
	.is_hit_co	(),
	.is_miss_co	(),
	.is_update_i	(s_update),
	.is_u_addr_i	(s_u_addr),
	.is_packed_i	(s_packed_from)
);


endmodule	// th_first_tb
