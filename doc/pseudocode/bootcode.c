// Boot ROM code to fetch data from the Xilinx Serial Prom and store it to
// main memory.
// The data includes TTA code, mode information tables, and fonts.
#define	SYS_DATA_ADDR	0x80000000
#define	DATA_SIZE	100000

#define	PROM_DATA_ADDR	0x90000000
#define	PROM_FLAGS_ADDR	0x90000001

#define	PROM_FLAG_DATAFOUND	0x00001
#define	PROM_FLAG_DATAREADY	0x00002

// This code is stored at 0x80000000, system memory space.
boot ()
{
	// First, wait until the `data_found' flag is set.
	int	prom_flags, data_found, data_ready;
	int	index	= 0;
	
	do {
		prom_flags	= peek (PROM_FLAGS_ADDR);
		data_found	= prom_flags & PROM_FLAG_DATAFOUND;
	} while (!data_found);
	
	do {
		// Wait until a new word is fetched from the ROM.
		do {
			prom_flags	= peek (PROM_FLAGS_ADDR);
			data_ready	= prom_flags & PROM_FLAG_DATAREADY;
		} while (!data_ready) ;
		
		// Transfer to main memory.
		poke (SYS_DATA_ADDR + index, peek (PROM_DATA_ADDR));
		index++;
		
	} while (index < DATA_SIZE);
	
	run_loop ();
}
