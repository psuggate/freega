`timescale 1ns/100ps
module vga_iomap_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset_n	= 1;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5
	reset_n	<= 0;
	
	#30
	reset_n	<= 1;
	
	#50
	$finish;
end	// Sim


vga_iomap IOMAP0 (
	.clock_i			(clock),
	.reset_ni			(reset_n),
	
	.mem_write_i			(),
	.mem_addr_i			(),
	.mem_bes_ni			(),
	.mem_data_i			(),
	.mem_data_o			(),
	
	// CRTC Register values
	.crtc_horiz_total_o		(),
	.crtc_horiz_disp_en_cnt_o	(),
	.crtc_horiz_blank_start_o	(),
	.crtc_horiz_blank_end_o		(),
	.crtc_horiz_retrace_start_o	(),
	.crtc_horiz_retrace_end_o	(),
	
	.crtc_vert_total_o		(),
	.crtc_vert_retrace_start_o	(),
	.crtc_vert_retrace_end_o	(),
	.crtc_vert_disp_en_end_o	(),
	.crtc_vert_blank_start_o	(),
	.crtc_vert_blank_end_o		()
);


endmodule	// vga_iomap_tb
