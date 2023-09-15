// PCI Polling Loop.

// Memory mapped PCI control registers.
#define	PCI_RD_ADDR	0xA0000000
#define	PCI_RD_DATA	0xA0000001
#define	PCI_WR_ADDR	0xA0000002
#define	PCI_WR_DATA	0xA0000003
#define	PCI_MMIO_REG0	0xA0000004
#define	PCI_MMIO_SIZ0	0xA0000005
#define	PCI_FLAGS	0xA0000007

// The PCI flags for the asynchronous FIFO states.
// RAF	- Read Address FIFO
// WF	- Write FIFO (stores address, data, plus enables)
#define	PCI_F_RAF_NOT_EMPTY	0x00100
#define	PCI_F_WF_NOT_EMPTY	0x00200
#define	PCI_F_FUNCTION		0x00003

run_loop ()
{
	int	pci_flags, pci_addr, pci_data;
	
	while (1) {
		// Check for pending read/write.
		do {
			pci_flags	= peek (PCI_FLAGS);
			pci_flags	&= PCI_F_RAF_NOT_EMPTY | PCI_F_WF_NOT_EMPTY;
			
			// Check for v-sync beginning.
			vid_flags	= peek (VID_FLAGS);
			
		} while (!pci_flags && !vid_flags) ;
		
		// Decode the PCI request, check reads first as they are more
		// sensitive to latency.
		// These is MEMORY and IO (and CFG?) address space to check.
		if (pci_flags & PCI_F_RAF_NOT_EMPTY) {
			pci_addr	= peek (PCI_RD_ADDR);
			// TODO: This is gonna be slow!
			switch (pci_addr) {
			0x000A0000-0x000BFFFF:	// Legacy frame-buffer
			*PCI_MMIO_REG0:	// TODO
			}
		} else {				// Write
		}
		
		// Vertical retrace event handler.
		// TODO:
	}
}


	// Setup the read segment to point to memory mapped PCI registers.
	//  r0	- PCI Flags address
	//  r1	- RAF_NOT_EMPTY mask
	//  r2	- WF_NOT_EMPTY mask
	//
	{u]	,		RD_SEG->cri,			}
	{u]	,		PCI_SEG->crd,			}
	{u]	PCI_FLAGS->r0,	PCI_FLAGS->rad,			}
	{u]	PCI_RAF_NE->r1,	,				}
	{u]	PCI_WF_NE->r2,	,				}
	{p]	,		r0->rad,	meml->com	}
	{p]	r1->bits,	,				}
.align	4
main_loop:
	{p]	r2->bits,	,				}
	{p]	,		,				}
	{u]	,		bnz pci_read,			}
	{u]	,		bz main_loop,			}
	{p]	,		r0->rad,	meml->com	}
	{p]	r1->bits,	,				}
	
pci_write:
	{p]	,		,				}
	{p]	,		,				}
	
pci_read:
	{p]	,		,				}
	{p]	,		,				}
	
