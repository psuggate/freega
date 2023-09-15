`timescale 1ns/100ps
module crct_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset_n	= 0;

wire	vsync, hsync;
wire	vblank, hblank;
wire	de, de_next;

wire	[15:0]	mem_addr;
wire	[4:0]	row_addr;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#65
	reset_n	<= 1;
	
	#500000
	$write ("\n");
	$finish;
end	// Sim


always @(posedge clock)
begin
	if (reset_n)
	begin
		if (de)
			$write ("D");
		else if (vsync)
			$write ("|");
		else if (hsync)
			$write ("-");
		else
			$write (".");
	end
end


always @(posedge hsync)
	$display;


crtc CRTC0 (
	.clock_i		(clock),	// Character clock
	.reset_ni		(reset_n),
	
	// CRTC Register values
	// Horizontal redrawing stuff
	.horiz_total_i		(8'h5f),
	.horiz_disp_en_cnt_i	(8'h4f),
	.horiz_blank_start_i	(8'h50),
	.horiz_blank_end_i	(6'h22),
	.horiz_disp_en_skew_i	(2'b0),	// TODO
	.horiz_retrace_start_i	(8'h54),
	.horiz_retrace_end_i	(5'h01),
	.horiz_retrace_skew_i	(2'b0),	// TODO
	.horiz_retrace_div_i	(1'b0),
	
	// Vertical redrawing stuff
	.vert_total_i		(10'h1bf),
	.vert_retrace_start_i	(10'h183),
	.vert_retrace_end_i	(4'h5),
	.vert_disp_en_end_i	(10'h15d),
	.vert_blank_start_i	(10'h163),
	.vert_blank_end_i	(8'hba),
	.vert_int_en_ni		(1'b0),
	.vert_int_clr_ni	(1'b0),
	.vert_int_o		(),
	
	// Scan-lines within a char. stuff
	.scan_row_preset_i	(5'b0),
	.scan_max_i		(5'h0f),
	.scan_double_i		(1'b0),	// TODO
	.scan_cursor_en_ni	(1'b0),
	.scan_cursor_start_i	(5'h0d),
	.scan_cursor_end_i	(5'h0e),
	.scan_cursor_skew_i	(2'b0),
	.scan_uline_loc_i	(5'h1f),
	
	// Misc. regs
	.mem_start_i		('b0),
	.cursor_location_i	('b0),
	.refresh_bandwidth_i	(1'b0),
	.write_protect_i	(1'b1),
	.display_word_size_i	(2'b00),
	.display_img_off_i	(8'h28),
	.dwell_i		(2'b00),
	.light_pen_en_ni	(1'b1),
	
	.hsync_o		(hsync),
	.hblank_o		(hblank),
	
	.vsync_o		(vsync),
	.vblank_o		(vblank),
	
	.DE_o			(de),	// Display enable
	.DEnext_o		(de_next),
	
	.cursor_o		(),
	.uline_o		(),
	
	.memory_ptr_o		(mem_addr),	// Used for text & graphics modes
	.row_address_o		(row_addr)	// Used for text-mode
);


endmodule	// crtc_tb
