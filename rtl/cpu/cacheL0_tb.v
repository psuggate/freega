`timescale 1ns/100ps
module cacheL0_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset	= 0;

wire	init_done;

// 256kB of RAM accessable by the cache.
reg	[31:0]	iram [0:65535];

reg	ready	= 0;

reg	[31:0]	data;

reg	[15:0]	pc	= 1;
reg	invld	= 1;
reg	[3:0]	addr;

wire	fetch;
wire	hit;
wire	[31:0]	instr;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5
	reset	<= 1;
	
	#30
	reset	<= 0;
	
/*	#10
	invld	<= 1;
	
	#20
	invld	<= 0;
	*/
	#500
	$finish;
end	// Sim



// Instruction fetches.
reg	[3:0]	count	= 0;
always @(posedge clock) begin
	if (reset)
		count	<= 0;
	else begin
	
		if (fetch) begin
			count	<= #1 count + 1;
		end
		
		if (count != 0)
			count	<= #1 count + 1;
		
		if (fetch || count != 0)
			ready	<= #1 1;
		else
			ready	<= #1 0;
	end
end


always @(posedge clock) begin
	if (reset)
		addr	<= #1 0;
	else
		addr	<= #1 count;
end


always @(posedge clock)
	data	<= #1 iram [{pc [15:4], count}];



// On address hit, increment PC so that the same tag hash is used so that the
// replacement policy can be tested.
always @(posedge clock) begin
	if (reset) begin
		pc	<= #1 1;
		invld	<= #1 1;
	end
	else if (hit) begin
		if (pc[3:0] < 5)
			pc	<= #2 pc + 1;
		else begin
			pc[15:10]	<= #1 pc[15:10] + 1;
			invld		<= #1 1;
			pc[9:0]		<= #1 0;
		end
	end
	else
		invld	<= #1 0;
end


cacheL0 CACHE0 (
	.clock_i	(clock),
	.reset_ni	(~reset),
	
	.pc_i		(pc [3:0]),
	.hit_o		(hit),
	.instr_o	(instr),
	
	.fetch_o	(fetch),	// Get a new cache-line from the L1 cache
	.invld_i	(invld),
	.store_i	(ready),
	.addr_i		(addr),
	.data_i		(data)
);


//---------------------------------------------------------------------------
// Initialise the contents of the instruction memory to random values.
//
integer	i;
initial begin : Init
	for (i=0; i<65536; i=i+1)
		iram[i]	<= $random;
end


endmodule	// cacheL0_tb
