`timescale 1ns/100ps
module icache_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset	= 0;

wire	init_done;

// 256kB of RAM accessable by the cache.
reg	[31:0]	iram [0:65535];

wire	read;
reg	ready	= 0;

wire	[15:0]	addr;
reg	[31:0]	data;

reg	[15:0]	pc	= 1;
reg	fetch	= 0;
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
	
	while (!init_done)	#10;
	
	pc	<= 20;
	fetch	<= 1;
	
	#10
	fetch	<= 0;
	
	#200
	$finish;
end	// Sim



// Instruction fetches.
reg	full	= 0;
reg	[3:0]	count	= 0;
always @(posedge clock) begin
	if (read) begin
		count	<= #1 count + 1;
	end
	
	if (count != 0)
		count	<= #1 count + 1;
	
	if (read || count != 0)
		ready	<= #1 1;
	else
		ready	<= #1 0;
end


always @(posedge clock)
	data	<= #1 iram [{addr[15:4], count}];



// On address hit, increment PC so that the same tag hash is used so that the
// replacement policy can be tested.
always @(posedge clock) begin
	if (reset)
		pc	<= 1;
	else if (hit) begin
		fetch	<= 1;
		if (pc[3:0] < 5)
			pc	<= pc + 1;
		else begin
			pc[15:10]	<= pc[15:10] + 1;
			pc[9:0]		<= 0;
		end
	end
	else
		fetch	<= 0;
end


cache_1way CACHE0 (
	.clock_i	(clock),
	.reset_ni	(~reset),
	.init_no	(init_done),
	
	.pc_i		(pc),
	.get_i		(fetch),
	.hit_o		(hit),
	.data_o		(instr),
	
	.invld_i	(0),
	.iaddr_i	(0),
	
	.read_o		(read),
	.full_i		(full),	// We're too fast!!
	.ready_i	(ready),
	.addr_o		(addr),
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


endmodule	// icache_tb
