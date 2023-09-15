`timescale 1ns / 1ps

`define	WIDTH	WIDTH_XX
`define	H	(`WIDTH-1)

module top(
	input		clock,
	input		[`H:0]	in,
	output	reg	[`H:0]	out
);

reg	[`H:0]	in_r;
wire	[`H:0]	inc_w;

assign	#2 inc_w	= in_r + 1;

// Register inputs.
always @(posedge clock)
	{out, in_r}	<= #2 {inc_w, in};

endmodule
