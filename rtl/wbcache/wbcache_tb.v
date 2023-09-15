`timescale 1ns/100ps
module wbcache_tb;

// `define	TEST_MAX	262144
`define	TEST_MAX	65536
// `define	TEST_MAX	1024
parameter	WIDTH	= 32;
parameter	ADDRESS	= 20;
parameter	MSB	= WIDTH - 1;
parameter	ASB	= ADDRESS - 1;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset	= 0;

reg	lookup	= 0;
reg	bra_imm	= 0;
reg	bra_reg	= 0;
reg	[ASB:0]	pc_nxt	= 0;
reg	[ASB:0]	pc_imm	= 0;
reg	[ASB:0]	pc_reg	= 0;

wire	valid, busy, miss;
wire	[MSB:0]	instr;

integer	miss_count	= 0;


initial begin : Sim
// 	$dumpfile("tb.vcd");
// 	$dumpvars();
	
	#2	reset	= 1;
	#10	reset	= 0;
	
	// Simple incrementing read.
	#10	lookup	= 1;
	while	(pc_nxt < `TEST_MAX)	#10 ;
	lookup	= 0;
	
	#3000
	$display ("\nHits\t= %d", `TEST_MAX - miss_count);
	$display ("Misses\t= %d", miss_count);
	$finish;
end	// Sim


always @(posedge clock)
	if (reset)	pc_nxt	<= #2 0;
	else if (lookup && !busy)
		pc_nxt	<= #2 pc_nxt + 1;


always @(posedge clock)
	if (reset)	miss_count	<= #2 0;
	else		miss_count	<= #2 miss_count + miss;

/*
always @(posedge clock)
	if (pc_nxt % 1000 == 0)
		$write (".");
*/

wbcache_dummy #(
	.HIGHZ		(0),
	.WIDTH		(32),
	.ADDRESS	(20),
	.WORDBITS	(9),
	.LINEBITS	(4)
) CACHE0 (
	.clock_i	(clock),
	.reset_i	(reset),
	
	.lookup_i	(lookup),
	.busy_o		(busy),
	.miss_o		(miss),
	.bra_imm_i	(bra_imm),
	.bra_reg_i	(bra_reg),
	.pc_nxt_i	(pc_nxt),
	.pc_imm_i	(pc_imm),
	.pc_reg_i	(pc_reg),
	
	.ready_o	(valid),
	.data_o		(instr),
	
	.wb_clk_i	(0),
	.wb_rst_i	(0),
	.wb_ack_i	(0),
	.wb_rty_i	(0),
	.wb_err_i	(0),
	.wb_sel_i	(0),
	.wb_dat_i	(0)
);	// CACHE0


endmodule	// wbcache_tb
