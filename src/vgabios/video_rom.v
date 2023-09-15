module video_rom( ib_clk, ib_en, ib_ready, ib_address, ib_data_out );
	
	input	ib_clk;
	input	ib_en;
	output	ib_ready;
	input	[8:0]	ib_address;	//	How to handle 16/32-bit reads?
	output	[31:0]	ib_data_out;
	
	reg		ib_ready	= 0;
	wire	[31:0]	rom_data;
	
	assign	ib_data_out	= ib_en ? rom_data : 32'bz;
	
	//------------------------------------------
	//	Minimal VGA Bios Implementation
	//------------------------------------------
	
//	The VGA Bios file is loaded into a Xilinx RAM block
`include "../data/vgabios.v"
	
	always @(posedge ib_clk)
		ib_ready	<= ib_en;
		
	
	RAMB16_S36 vgabios0 (
		.CLK(ib_clk),
		.EN(ib_en),
		.WE(1'b0),		// ROMs are read only
		.ADDR(ib_address),	// 9-bit address bus
		.SSR(1'b0),
		.DO(rom_data)
		//.DI(ib_data_in)
	);
	
endmodule	//	video_rom
