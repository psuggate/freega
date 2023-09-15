// TODO: Prefixes for different groups of signals.
`timescale 1ns/100ps
module vga_tta_top (
	clock_i,
	reset_ni,
	
	ifetch_o,	// Get a new cache-line from the L1 cache
	iabort_o,
	iready_i,
	iaddr_o,
	idata_i,
	
	m_read_o,	// VGA data to the vga contoller
	m_write_o,
	m_ready_i,
	m_addr_o,
	m_data_i,
	m_data_o
);

parameter	AW	= 16;
parameter	IW	= 32;
parameter	AMSB	= AW-1;
parameter	IMSB	= IW-1;

parameter	IAMSB	= 8;
parameter	IWORDS	= 512;
parameter	MAMSB	= 3;
parameter	MDMSB	= 10;

input	clock_i;
input	reset_ni;

output	ifetch_o;	// Get a new cache-line from the L1 cache
output	iabort_o;
input	iready_i;
output	[15:0]		iaddr_o;
input	[IMSB:0]	idata_i;

output	m_read_o;
output	m_write_o;
input	m_ready_i;
output	[MAMSB:0]	m_addr_o;
input	[MDMSB:0]	m_data_i;
output	[MDMSB:0]	m_data_o;

wire	[15:0]	pc;
wire	hit;
wire	[31:0]	instr;

wire	newline;
wire	newpage;

/*
wire	ifetch;
wire	iinvld;
wire	iready;
wire	[15:0]	iaddr;
wire	[31:0]	idata;


assign	#1 iinvld	= newline | newpage;


//---------------------------------------------------------------------------
// Load instructions into the instruction memory.
//

// Instruction load from PCI.
always @(posedge clock_i) begin
	if (!reset_ni)
		i_ready_o	<= 0;
	else begin
		i_ready_o	<= i_read_i;
		i_data_o	<= iram [i_addr_i];
		
		if (i_write_i)
			iram [i_addr_i]	<= i_data_i;
	end
end
*/

assign	iaddr_o	= {pc[15:4], 4'b0000};

reg	[3:0]	count	= 0;
always @(posedge clock_i) begin
	if (!reset_ni)
		count	<= #1 0;
	else if (iabort_o)
		count	<= #1 0;
	else if (iready_i)
		count	<= #1 count + 1;
end


// A 64-byte L0 cache. Why L0? Because it isn't quite an L1 cache. But this
// cache runs at nearly 300 MHz in a Spartan III FPGA.
cacheL0 CACHE0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.pc_i		(pc [3:0]),
	.hit_o		(hit),
	.instr_o	(instr),
	
	.fetch_o	(ifetch_o),	// Get a new cache-line from the L1 cache
	.abort_o	(iabort_o),	// Abort the current cache-line fetch
	.invld_i	(newline),
	.store_i	(iready_i),
	.addr_i		(count),
	.data_i		(idata_i)
);


vga_tta TTA0 (
	.clock_i	(clock_i),
	.reset_ni	(reset_ni),
	
	.pc_o		(pc),
	.hit_i		(hit),
	.instr_i	(instr),
	
	.newline_o	(newline),	// These are for cache/memory control
	.newpage_o	(newpage),
	
	.m_read_o	(m_read_o),	// VGA data to the vga contoller
	.m_write_o	(m_write_o),
	.m_ready_i	(m_ready_i),
	.m_addr_o	(m_addr_o),
	.m_data_i	(m_data_i),
	.m_data_o	(m_data_o)
);


endmodule	// vga_tta_top
