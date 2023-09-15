`define	TEST_SIZE	43

`timescale 1ns/100ps
module sdrtest (
	clk50,
	
	sdr_clk,
	sdr_cke,
	sdr_cs_n,
	sdr_ras_n,
	sdr_cas_n,
	sdr_we_n,
	sdr_ba,
	sdr_a,
	sdr_dm,
	sdr_dq,
	
/*	data_read,
	data_in,*/
	init_done,
	pci_disable,
	pci_rst_n,
	leds
);

parameter	WIDTH	= 32;
parameter	ADDRESS	= 10;
parameter	MSB	= WIDTH - 1;
parameter	ASB	= ADDRESS - 1;

input		clk50;

// SDRAM pins
output		sdr_clk;	// synthesis attribute iob of clk is true ;
output		sdr_cke;	// synthesis attribute iob of cke is true ;
output		sdr_cs_n;	// synthesis attribute iob of cs_n is true ;
output		sdr_ras_n;	// synthesis attribute iob of ras_n is true ;
output		sdr_cas_n;	// synthesis attribute iob of cas_n is true ;
output		sdr_we_n;	// synthesis attribute iob of we_n is true ;
output	[1:0]	sdr_ba;		// synthesis attribute iob of ba<*> is true ;
output	[12:0]	sdr_a;		// synthesis attribute iob of a<*> is true ;
output	[1:0]	sdr_dm;		// synthesis attribute iob of dm<*> is true ;
inout	[15:0]	sdr_dq;		// synthesis attribute iob of dq<*> is true ;
/*
output	[31:0]	data_read;
output	[15:0]	data_in;
*/
output		init_done;
output		pci_disable;
input		pci_rst_n;
output	[1:0]	leds;


reg	[15:0]	data_in;	// synthesis attribute iob of data_in* is true ;
wire	[15:0]	dq_w;		// synthesis attribute iob of dq_w* is true ;

reg	[12:0]	count	= 0;
reg	[8:0]	addr	= 0;
reg	[31:0]	data_read;
wire	[35:0]	br_data;
// reg	[35:0]	br_data;
reg	sdr_cke	= 0;
reg	[1:0]	leds	= 0;	// synthesis attribute iob of leds* is true ;

wire	clk83, clk180;
wire	mclk, lclk, dclk, lock;
reg	latch;
reg	[15:0]	oe;


assign	pci_disable	= 0;
assign	sdr_clk		= ~mclk;
// assign	leds	= data_read [1:0];
/*
assign	cs_n	= br_data [3];
assign	ras_n	= br_data [2];
assign	cas_n	= br_data [1];
assign	we_n	= br_data [0];

assign	ba	= br_data [15:14];
assign	a [12:11]	= 0;	// These address bits are unused.
assign	a [10]	= br_data [13];
assign	a [9]		= 0;	// This address bit isn't used.
assign	a [8:0]	= br_data [12:4];

assign	dm	= br_data [33:32];
*/
reg	sdr_cs_n, sdr_ras_n, sdr_cas_n, sdr_we_n;
reg	[12:0]	sdr_a;
reg	[1:0]	sdr_ba, sdr_dm;
reg	[15:0]	dq_r;
/* synthesis attribute iob of cs_n is true ; */
/* synthesis attribute iob of ras_n is true ; */
/* synthesis attribute iob of cas_n is true ; */
/* synthesis attribute iob of we_n is true ; */
/* synthesis attribute iob of a* is true ; */
/* synthesis attribute iob of ba* is true ; */
/* synthesis attribute iob of dm* is true ; */
/* synthesis attribute iob of dq_r* is true ; */

always @(posedge mclk) begin
	sdr_cs_n	<= br_data [3];
	sdr_ras_n	<= br_data [2];
	sdr_cas_n	<= br_data [1];
	sdr_we_n	<= br_data [0];
	
	sdr_a	<= {2'b00, br_data [13], 1'b0, br_data [12:4]};
	sdr_ba	<= br_data [15:14];
	sdr_dm	<= br_data [33:32];
	
	latch	<= br_data [35];
end

always @(posedge dclk) begin
	oe	<= {16{br_data [34]}};
	dq_r	<= br_data [31:16];
end


assign	init_done	= count [12];


// Wait for the clock to stabilise.
always @(posedge mclk)
	if (!pci_rst_n)		count	<= #2 0;
	else if (!count [12])	count	<= #2 count + 1;


// Upon clock stabilisation, step through the commands in the block RAM.
always @(posedge mclk)
	if (!pci_rst_n)
		addr	<= #2 0;
	else if (count [12] && addr < `TEST_SIZE)
		addr	<= #2 addr + 1;


always @(posedge mclk)
	sdr_cke	<= #2 (count [12:11] > 0) && (addr != `TEST_SIZE);


// Latch the incoming data.
always @(posedge lclk)
	data_in	<= #2 dq_w;

always @(posedge mclk)
	if (!pci_rst_n)
		data_read	<= #2 0;
	else if (latch)
		data_read	<= #2 {data_in, data_read [31:16]};


// Perform test and output result.
always @(posedge mclk)
	if (!pci_rst_n) begin
		leds	<= #2 0;
		$display ("SDRAM test starting.");
	end else if (addr == `TEST_SIZE) begin
// 		if (data_read [31:16] == 16'ha37d) begin
		if (data_read == 32'h3333_a37d) begin
			leds	<= #2 2'b10;
`ifdef __icarus
			$display ("PBSUCCESS");
			$finish;
`endif
		end else begin
			leds	<= #2 2'b11;
`ifdef __icarus
			$display ("ERROR: Test failed (%x)", data_read);
			$finish;
`endif
		end
	end else if (addr < `TEST_SIZE && addr > 0)
		leds	<= #2 2'b01;


// assign	#8 sdr_dq	= oe ? dq_r : 'bz ;
// assign	#2 dq_w	= sdr_dq;

// Data IOBs
OBUFT
/*`ifdef __icarus
 #(
	.ODELAY	(14.5)
)
`endif*/
DQ_obufs [15:0] (
	.I	(dq_r),
	.T	(~oe),
	.O	(sdr_dq)
);


IBUF DQ_ibufs [15:0] (
	.I	(sdr_dq),
	.O	(dq_w)
);


//---------------------------------------------------------------------------
//  Clocks.
//
// // assign	mclk	= clk50;
// assign	lclk	= clk50;

wire	GND	= 0;

/*
DCM #(
	.CLK_FEEDBACK		("1X"),
	.DLL_FREQUENCY_MODE	("LOW")
) dcm0 (
	.CLKIN		(clk50),
	.CLKFB		(clk_50),
	.DSSEN		(GND),
	.PSEN		(GND),
	.RST		(GND),
	.CLK0		(clk_50),
	.CLK90		(clk_90),
	.CLK180		(clk_n),
	.LOCKED		(lock)
);

// BUFG dclk_bufg (
// 	.I	(clk_n),
// 	.O	(dclk)
// );

BUFG lclk_bufg (
	.I	(clk_n),
	.O	(lclk)
);

BUFG clk_bufg (
	.I	(clk_50),
	.O	(mclk)
);
assign	dclk	= mclk;
*/

DCM #(
	.CLK_FEEDBACK		("NONE"),
	.DLL_FREQUENCY_MODE	("LOW"),
	.CLKFX_MULTIPLY		(13),
	.CLKFX_DIVIDE		(5)
) dcm0 (
	.CLKIN		(clk50),
	.CLKFB		(GND),
	.DSSEN		(GND),
	.PSEN		(GND),
	.RST		(GND),
	.CLKFX		(clk83),
	.CLKFX180	(clk180),
	.LOCKED		(lock)
);

BUFG lclk_bufg (
	.I	(clk180),
	.O	(lclk)
);

BUFG clk_bufg (
	.I	(clk83),
	.O	(mclk)
);
assign	dclk	= mclk;


RAMB16_S36_S36 #(
`include "sdrcmds.v"
) RAM0 (
	.DIA	(0),
	.DIPA	(0),
	.ADDRA	(addr),
	.ENA	(1'b1),
	.WEA	(0),
	.SSRA	(0),
	.CLKA	(mclk),
	.DOA	(br_data [31:0]),
	.DOPA	(br_data [35:32]),
	
	.DIB	(0),
	.DIPB	(0),
	.ADDRB	(0),
	.ENB	(0),
	.WEB	(0),
	.SSRB	(0),
	.CLKB	(0),
	.DOB	(),
	.DOPB	()
);

/*
// 	Bit field description:
// 	15-14	BA
// 	13-4	A
// 	
// 	31-16	DQ
// 	33-32	DM
// 	34	DQ output enable
// 	35	DQ latch
// 	
// 	3	CS#
// 	2	RAS#
// 	1	CAS#
// 	0	WE#

always @(posedge mclk)
	case (addr)
		00: br_data <= 36'h0_0000_000F;	// NOP
		01: br_data <= 36'h0_0000_0007;	// NOP
		
		02: br_data <= 36'h0_0000_2002;	// PRECHARGE
		03: br_data <= 36'h0_0000_0007;	// NOP
		
		04: br_data <= 36'h0_0000_0001;	// REFRESH
		05: br_data <= 36'h0_0000_0007;	// NOP
		06: br_data <= 36'h0_0000_0007;	// NOP
		07: br_data <= 36'h0_0000_0007;	// NOP
		08: br_data <= 36'h0_0000_0007;	// NOP
		09: br_data <= 36'h0_0000_0007;	// NOP
		10: br_data <= 36'h0_0000_0007;	// NOP
		11: br_data <= 36'h0_0000_0007;	// NOP
		12: br_data <= 36'h0_0000_0007;	// NOP
		13: br_data <= 36'h0_0000_0007;	// NOP
		
		14: br_data <= 36'h0_0000_0001;	// REFRESH
		15: br_data <= 36'h0_0000_0007;	// NOP
		16: br_data <= 36'h0_0000_0007;	// NOP
		17: br_data <= 36'h0_0000_0007;	// NOP
		18: br_data <= 36'h0_0000_0007;	// NOP
		19: br_data <= 36'h0_0000_0007;	// NOP
		20: br_data <= 36'h0_0000_0007;	// NOP
		21: br_data <= 36'h0_0000_0007;	// NOP
		22: br_data <= 36'h0_0000_0007;	// NOP
		23: br_data <= 36'h0_0000_0007;	// NOP
		
		24: br_data <= 36'h0_0000_0210;	// LMR (CL=2, Burst=2)
		25: br_data <= 36'h0_0000_0007;	// NOP
		
`ifdef __working_test
		26: br_data <= 36'h0_0000_0003;	// ACTIVE
		27: br_data <= 36'h0_0000_0007;	// NOP
		28: br_data <= 36'h4_a37d_0004;	// WRITE
		29: br_data <= 36'h4_3333_0007;	// NOP (2nd word of burst)
		
		30: br_data <= 36'h0_0000_0007;	// NOP
		31: br_data <= 36'h0_0000_0007;	// NOP
		32: br_data <= 36'h0_0000_0005;	// READ
		33: br_data <= 36'h0_0000_0007;	// NOP
		34: br_data <= 36'h8_0000_0007;	// NOP (1st word)
		35: br_data <= 36'h8_0000_0007;	// NOP (2nd word)
		36: br_data <= 36'h0_0000_2002;	// PRECHARGE
		37: br_data <= 36'h0_0000_0007;	// NOP
		38: br_data <= 36'h0_0000_0001;	// SELF REFRESH
`else	// __working_test
		26: br_data <= 36'h0_0000_0003;	// ACTIVE
		27: br_data <= 36'h0_0000_0007;	// NOP
		28: br_data <= 36'h4_8888_0004;	// WRITE
		29: br_data <= 36'h4_9999_0007;	// NOP (2nd word of burst)
		30: br_data <= 36'h4_a37d_0024;	// WRITE
		31: br_data <= 36'h4_3333_0007;	// NOP (2nd word of burst)
		
		32: br_data <= 36'h0_0000_0007;	// NOP
		33: br_data <= 36'h0_0000_0007;	// NOP
		34: br_data <= 36'h0_0000_0005;	// READ
		35: br_data <= 36'h0_0000_0007;	// NOP
		36: br_data <= 36'h8_0000_0025;	// READ (+latch 1st word)
		37: br_data <= 36'h8_0000_0007;	// NOP (2nd word)
		38: br_data <= 36'h8_0000_0007;	// NOP (3rd word)
		39: br_data <= 36'h8_0000_0007;	// NOP (4th word)
		40: br_data <= 36'h0_0000_2002;	// PRECHARGE
		41: br_data <= 36'h0_0000_0007;	// NOP
		42: br_data <= 36'h0_0000_0001;	// SELF REFRESH
`endif	// __working_test
		default:	br_data	<= 36'h0_0000_0007;	// NOP
	endcase
*/

endmodule	// dumb_sdram_ctrl
