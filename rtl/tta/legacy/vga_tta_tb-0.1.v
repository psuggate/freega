`timescale 1ns/100ps
module vga_tta_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset	= 0;
reg	gate	= 0;

reg	iwr	= 0;
reg	[8:0]	iaddr;
reg	[35:0]	idata;

reg	p_pres	= 0;
reg	[7:0]	p_data	= 8'h5A;
wire	p_ack;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5
	reset	<= 1;
	
	#30
	reset	<= 0;
	
	#10
	p_pres	<= 1;
	
	iwr	<= 1;
	iaddr	<= 0;
	idata	<= $random;
	
	#10
	p_pres	<= 0;
	iwr	<= 0;
	
	#100
	p_pres	<= 1;
	p_data	<= $random;
	
	#10
	p_pres	<= 0;
	p_data	<= 'bx;
	
	#150
	$finish;
end	// Sim


initial begin : Pause
	// Gate the CPU for one clock.
	#105	gate	<= 0;
	#10	gate	<= 0;
end	// Pause


vga_tta TTA0 (
	.clock_i	(clock),
	.reset_ni	(~reset),
	.gate_ni	(~gate),
	
	.i_read_i	(0),	// Instruction data from the PCI bus
	.i_write_i	(0),
	.i_ready_o	(),
	.i_addr_i	(),
//	.i_bes_ni	(),
	.i_data_i	(),
	.i_data_o	(),
	
	.p_pres_i	(p_pres),	// Port data from the PCI bus
	.p_data_i	(p_data),
	.p_ack_o	(p_ack),
	.p_send_o	(),
	.p_data_o	(),
	
	.v_read_o	(),	// VGA data to the vga contoller
	.v_write_o	(),
	.v_ready_i	(0),
	.v_addr_o	(),
	.v_data_i	(),
	.v_data_o	()
);


endmodule	// vga_tta_tb
