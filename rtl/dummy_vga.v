`define	PCI_IOREAD	4'b0010
`define	PCI_IOWRITE	4'b0011

`timescale 1ns/100ps
module dummy_vga (
	input		pci_clk_i,
	input		pci_rst_ni,
	input		pci_frame_ni,
	output		pci_devsel_no,
	input		pci_irdy_ni,
	output		pci_trdy_no,
	input	[3:0]	pci_cbe_ni,
	input	[31:0]	pci_ad_i,
	output	[31:0]	pci_ad_o
);


reg	pci_devsel_n	= 1;
reg	pci_wr	= 0;
reg	[31:0]	crap;
// reg	pci_trdy_n	= 1;

wire	vga_io_match;


assign	pci_devsel_no	= pci_devsel_n ? 1'bz : 0 ;
assign	pci_trdy_no	= pci_devsel_n ? 1'bz : 0 ;
assign	pci_ad_o	= pci_wr ? crap : 'bz ;

assign	#2 vga_io_match	= (pci_ad_i >= 32'h03b0 && pci_ad_i <= 32'h03df) &&
			  (pci_cbe_ni == `PCI_IOREAD || pci_cbe_ni == `PCI_IOWRITE) &&
			  !pci_frame_ni;


// initial	crap	= $random;
always @(posedge pci_wr)
	crap	= $random;


always @(posedge pci_clk_i)
	if (!pci_rst_ni)
		pci_devsel_n	<= #2 1;
	else if (pci_devsel_n && vga_io_match)
		pci_devsel_n	<= #2 0;
	else
		pci_devsel_n	<= #2 1;


always @(posedge pci_clk_i)
	if (!pci_rst_ni)
		pci_wr	<= #2 0;
	else if (pci_devsel_n && vga_io_match && !pci_cbe_ni [0])
		pci_wr	<= #2 1;
	else
		pci_wr	<= #2 0;


endmodule	// dummy_vga
