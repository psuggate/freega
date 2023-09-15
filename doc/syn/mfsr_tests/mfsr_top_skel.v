`timescale 1ns / 1ps

`define	WIDTH	WIDTH_XX
`define	H	(`WIDTH-1)

module top(
	input			clock,
	input		[`H:0]	in,
	output	reg	[`H:0]	out
);

reg	[`H:0]	in_r;
wire	[`H:0]	inc_w;

// Register inputs+outputs.
always @(posedge clock)
	{out, in_r}	<= #2 {inc_w, in};

TEST_MODULE_XX COUNTER (
	.count_i(in_r),
	.count_o(inc_w)
);

endmodule
