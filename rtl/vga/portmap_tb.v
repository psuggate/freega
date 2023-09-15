`define	REG_NUM		4
`define	ADDR_BITS	2

module portmap_tb;
	
	reg	clock	= 1;
	always	#5	clock	<= ~clock;
	
	reg	reset	= 0;
	
	reg	portsel		= 0;
	reg	addrwrite	= 0;
	reg	datawrite	= 0;
	reg	[`ADDR_BITS-1:0]	pci_portaddr	= 0;
	reg	[7:0]			pci_portdata	= 0;
	
	
	wire	mem_write;
	wire	[`ADDR_BITS-1:0]	mem_addr, dev_portaddr;
	wire	[7:0]			dev_portdata, mem_data_from, mem_data_to;
	wire	[`REG_NUM*8-1:0]	regs;
	
	
	initial begin : Sim
		$display ("Time CLK RST   Awr Dwr Aout Dout Ain Din   Mwr MAddr MDout MDin");
		$monitor ("%5t  %b  %b    %b  %b  %h   %h   %h  %h    %b  %h    %h    %h  ",
			$time, clock, reset,
			addrwrite, datawrite, pci_portaddr, pci_portdata, dev_portaddr, dev_portdata,
			mem_write, mem_addr, mem_data_to, mem_data_from
		);
		
		#5
		reset	<= 1;
		
		#10
		reset	<= 0;
		
		// Change the register address.
		#10
		addrwrite	<= 1;
		pci_portaddr	<= 2;
		
		#10
		addrwrite	<= 0;
		pci_portaddr	<= 'bx;
		
		// Change the I/O port data.
		#20
		datawrite	<= 1;
		pci_portdata	<= 8'd167;
		
		#10
		datawrite	<= 0;
		pci_portdata	<= 'bx;
		
		// Do a write to the address and data ports simultaneously.
		#20
		addrwrite	<= 1;
		datawrite	<= 1;
		pci_portaddr	<= 1;
		pci_portdata	<= 8'd219;
		
		#10
		addrwrite	<= 0;
		datawrite	<= 0;
		pci_portaddr	<= 'bx;
		pci_portdata	<= 'bx;
		
		#30
		$finish;
	end	// Sim
	
	
	defparam	PM0.ADDR_BITS	= `ADDR_BITS;
	portmap PM0 (
		.clock_i	(clock),
		.reset_i	(reset),
		
		.addrwrite_i	(addrwrite),
		.datawrite_i	(datawrite),
		.portaddr_i	(pci_portaddr),
		.portdata_i	(pci_portdata),
		.portaddr_o	(dev_portaddr),
		.portdata_o	(dev_portdata),
		
		.memwrite_o	(mem_write),
		.memaddr_o	(mem_addr),
		.memdata_i	(mem_data_from),
		.memdata_o	(mem_data_to)
	);
	
	
	// Defaults are 16 and 4.
	defparam	MM0.REG_NUM	= `REG_NUM;
	defparam	MM0.ADDR_BITS	= `ADDR_BITS;
	memmap MM0 (
		.clock_i	(clock),
		.reset_i	(reset),
		
		.portwrite_i	(mem_write),
		.portaddr_i	(mem_addr),
		.portdata_i	(mem_data_to),
		.portdata_o	(mem_data_from),
		
		.memwrite_i	(1'b0),
		
		.regs_o		(regs),
		.regs_i		(regs)
	);
	
endmodule	// portmap_tb
