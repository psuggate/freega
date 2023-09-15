`define	REG_NUM		4
`define	ADDR_BITS	2

module memmap_tb;
	
	reg	clock	= 1;
	always	#5	clock	<= ~clock;
	
	reg	reset	= 0;
	
	reg	write	= 0;
	reg	[`ADDR_BITS-1:0]	addr	= 0;
	reg	[7:0]	data_to	= 0;
	wire	[7:0]	data_from;
	
	wire	[`REG_NUM*8-1:0]	regs;
	
	
	initial begin : Sim
		$display ("Time CLK RST   WR ADDR Dout Din");
		$monitor ("%5t  %b  %b    %b %h   %h   %h ",
			$time, clock, reset,
			write, addr, data_to, data_from
		);
		
		#5
		reset	<= 1;
		
		#10
		reset	<= 0;
		
		#10
		addr	<= 1;
		data_to	<= 8'd213;
		write	<= 1;
		
		#10
		write	<= 0;
		
		#20
		$finish;
	end	// Sim
	
	
	// Defaults are 16 and 4.
	defparam	MM0.REG_NUM	= `REG_NUM;
	defparam	MM0.ADDR_BITS	= `ADDR_BITS;
	memmap MM0 (
		.clock_i(clock),
		.reset_i(reset),
		
		.write_i(write),
		.addr_i	(addr),
		.data_i	(data_to),
		.data_o	(data_from),
		
		.regs_o	(regs)
	);
	
endmodule	// memmap_tb
