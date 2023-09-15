`timescale 1ns/100ps
module pc_gen (
	clock_i,
	reset_ni,
	gate_ni,
	
	bra_ctl_i,
	immed_i,
	reg_i,
	
	pc_o
);

parameter	PCMSB	= 8;

input	clock_i;
input	reset_ni;
input	gate_ni;

input	[1:0]	bra_ctl_i;
input	[PCMSB:0]	immed_i;
input	[PCMSB:0]	reg_i;

output	[PCMSB:0]	pc_o;

reg	[PCMSB:0]	pc	= 1;

wire	[PCMSB:0]	next_pc;


assign	pc_o	= pc;


always @(posedge clock_i) begin
	if (!reset_ni)
		pc	<= 1;
	else if (gate_ni) begin
		case (bra_ctl_i)
		0:	pc	<= next_pc;
		1:	pc	<= 0;		// Interrupt
		2:	pc	<= immed_i;
		3:	pc	<= reg_i;
		endcase
	end
end


`ifdef __icarus
assign	next_pc	= pc + 1;
`else
mfsr9 MFSR0 (
	.count_i	(pc),
	.count_o	(next_pc)
);
`endif


endmodule	// pc_gen
