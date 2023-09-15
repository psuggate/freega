`timescale 1ns/100ps
module cache_ctrl_tb;

parameter	WIDTH	= 32;
parameter	ENABLES	= WIDTH / 8;
parameter	ADDRESS	= 18;
parameter	ICOUNT_BITS	= 4;
parameter	MSB	= WIDTH - 1;
parameter	ESB	= ENABLES - 1;
parameter	ASB	= ADDRESS - 1;


reg	clock	= 1;
reg	wb_clk	= 1;
reg	reset	= 1;

always	#5 clock	<= ~clock;
always	#15 wb_clk	<= ~wb_clk;


reg	newseg	= 0;
reg	s1_full	= 0;
reg	s2_full	= 0;
wire	miss_a;
reg	[ASB:0]	s1_pc, s2_pc, s3_pc;
wire	u_fetch, u_done, u_ack;
wire	[7:0]	u_addr;
wire	[MSB:0]	u_data;
wire	[ASB:0]	t_addr;
wire	s1_en, s2_en, s3_en;
wire	busy;
wire	t0_wr, t0_vld;
wire	t1_wr, t1_vld;


reg	wb_ack	= 0;
reg	wb_rty	= 0;
reg	wb_err	= 0;
reg	[ESB:0]	wb_sel;
reg	[MSB:0]	wb_dat;

wire	wb_cyc, wb_stb, wb_we;
wire	[2:0]	wb_cti;
wire	[1:0]	wb_bte;
wire	[ASB:0]	wb_adr;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#2	reset	= 1;	// Invalidate L1 contents takes >16 cycles
	#20	reset	= 0;
	
	#10	while (!s1_en)	#10 ;
		s1_pc	= 5; s1_full = 1;
	#10	s1_pc	= 6;
	#10	s1_full	= 0;
	
/*	#10	s2_full	= 1; s2_pc = s1_pc; miss_a = 1;
	#10	miss_a	= 0; s1_full = 0;
	#10	s3_pc = s2_pc;
	*/
	#2000
	$display ("Completed.");
	$finish;
end	// Sim


initial	#3000 $finish;

/*
always @(posedge clock)
	if (reset)	s1_full	<= #2 0;
	else if (s1_en)
		s1_full	<= #2 1;
*/
always @(posedge clock)
	if (reset)	s2_full	<= #2 0;
	else if (s2_en) begin
		s2_full	<= #2 s1_full;
		s2_pc	<= #2 s1_pc;
	end

// This will produce all misses.
assign	#2 miss_a	= (s2_full && s2_en);
always @(posedge clock)
	if (s3_en)
		s3_pc	<= #2 s2_pc;


always @(posedge wb_clk)
	if (reset)
		wb_ack	<= #2 0;
	else if (wb_cyc && wb_stb && !wb_we && !wb_ack) begin
		wb_ack	<= #2 1;
		wb_sel	<= #2 4'hf;
		wb_dat	<= #2 $random;
	end else if (wb_cyc && wb_stb && !wb_we && wb_cti == 3'b010) begin
		wb_ack	<= #2 1;
		wb_sel	<= #2 4'hf;
		wb_dat	<= #2 $random;
	end else
	begin
		wb_ack	<= #2 0;
		wb_sel	<= #2 'bx;
		wb_dat	<= #2 'bx;
	end


cache_ctrl #(
	.ADDRESS	(ADDRESS)
) CTRL0 (
	.clock_i	(clock),
	.reset_i	(reset),
	
	.newseg_i	(newseg),	// 1MB segment size
	.busy_o		(busy),
	
	.s1_enable_o	(s1_en),
	.s1_full_i	(s1_full),
	.s1_pc_i	(s1_pc),
	
	.s2_enable_o	(s2_en),
	.s2_full_i	(s2_full),
	.s2_pc_i	(s2_pc),
	
	.s3_enable_o	(s3_en),
	.s3_miss_ai	(miss_a),
	.s3_pc_i	(s3_pc),
	
	.u_fetch_o	(u_fetch),
	.u_ack_i	(u_ack),
	.u_done_i	(u_done),
	
	.t_write0_o	(t0_wr),
	.t_valid0_o	(t0_vld),
	.t_write1_o	(t1_wr),
	.t_valid1_o	(t1_vld),
	.t_addr_sel_o	(),
	.t_addr_o	(t_addr)
);


fetch_wb #(
	.WIDTH		(WIDTH),
	.ADDRESS	(ADDRESS),
	.CNTBITS	(ICOUNT_BITS)	// 16x32-bit words/cacheline
) FETCH0 (
	// Wishbone clock domain.
	.wb_clk_i	(wb_clk),
	.wb_rst_i	(reset),
	.wb_cyc_i	(0),
	.wb_cyc_o	(wb_cyc),
	.wb_stb_o	(wb_stb),
	.wb_we_o	(wb_we),
	.wb_ack_i	(wb_ack),
	.wb_rty_i	(wb_rty),
	.wb_err_i	(wb_err),
	.wb_cti_o	(wb_cti),
	.wb_bte_o	(wb_bte),
	.wb_adr_o	(wb_adr),
	.wb_sel_i	(wb_sel),
	.wb_dat_i	(wb_dat),
	
	// Sync. with WB clock, but can be many times faster.
	.clk_i		(clock),
	.miss_i		(u_fetch),
	.ack_o		(u_ack),
	.ready_o	(u_done),
	.busy_o		(f_busy),
	.addr_i		(t_addr),
	
	.u_write_o	(u_write),
	.u_vld_o	(u_vld [0]),
	.u_addr_o	(u_addr),
	.u_data_o	(u_data)
);


endmodule	// cache_ctrl_tb
