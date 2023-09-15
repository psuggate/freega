`timescale 1ns/100ps
module vga_tta_tb;

reg	clock	= 1;
always	#5 clock	<= ~clock;

reg	reset	= 0;

reg	hit	= 0;


initial begin : Sim
	$write ("%% ");
	$dumpfile ("tb.vcd");
	$dumpvars;
	
	#5
	reset	<= 1;
	
	#30
	reset	<= 0;
	hit	<= 1;
	
	#100
	hit	<= 0;
	
	#20
	hit	<= 1;
	
	#300
	$finish;
end	// Sim


wire	[15:0]	pc;
//wire	hit	= ~reset;
wire	[31:0]	instr;
reg	[31:0]	imem [0:511];
assign	#1 instr	= imem [pc [8:0]];

wire	newline, newpage;

wire	[3:0]	maddr;

vga_tta TTA0 (
	.clock_i	(clock),
	.reset_ni	(~reset),
	
	.pc_o		(pc),
	.hit_i		(hit),
	.instr_i	(instr),
	
	.newline_o	(newline),
	.newpage_o	(newpage),
	
	.m_read_o	(),	// VGA data to the vga contoller
	.m_write_o	(),
	.m_ready_i	(0),
	.m_addr_o	(maddr),
	.m_data_i	(0),
	.m_data_o	()
);


// Load some instructions into the instruction RAM.
integer	i;
initial begin : Init
	`include "prog.v"
/*	for (i=0; i<512; i=i+1)
		imem [i]	<= $random;
	
	
	imem[0]	<= 'bx;	// Should never get here
	//              IMM       RF0  RFW   WR  COM   ALU1     ALU0
	
	// NOP
	imem[1]	<= 32'b000000000__0000_0000__00__000__0_00_00__111_00;
	
	// mov { #11 -> crd ; nop -> cri ; r0 -> com ; com -> r0 }
	imem[2]	<= 32'b000001011__0000_0000__00__000__0_00_00__111_11;
	
	// mov { com -> crd ; nop -> cri ; r0 -> com ; alu0 -> r1 }
	imem[3]	<= 32'b000000000__0000_0001__01__000__0_00_00__111_00;
	
	// NOP
	imem[4]	<= 32'b000000000__0000_0000__00__000__0_00_00__111_00;
	
	// mov { r1 -> crd ; #4 -> cri ; r1 -> com ; com -> r0 }
	//imem[4]	<= 32'b000000100__0001_0000__00__000__0_00_11__111_01;
	imem[5]	<= 32'b000000100__0001_0000__00__000__0_00_11__111_01;
	
	// mov { com -> inc ; NOP ; NOP ; NOP }
	//imem[5]	<= 32'b000000000__0000_0000__00__000__0_00_00__110_00;
	
	// mov { com -> and ; #0 -> cri ; r0 -> com ; com -> r0 }
	imem[6]	<= 32'b000000000__0000_0000__00__000__0_00_11__000_00;
	
	//imem[6]	<= 32'b000000000__0000_0000__00__000__0_00_00__000_00;
	imem[7]	<= 32'b000000000__0000_0000__00__000__0_00_00__000_00;
	imem[8]	<= 32'b000000000__0000_0000__00__000__0_00_00__000_00;
	
	// mov { com -> and ; #01 -> pc ; r0 -> com ; nop -> r0 }
	imem[9]	<= 32'b000000010__0000_0000__00__000__0_11_00__000_00;
	*/
end	// Init


endmodule	// vga_tta_tb
