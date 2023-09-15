#include <stdio.h>
#include <stdlib.h>

#include "mytypes.h"
#include "wbmem.h"
#include "cache.h"

#define	TEST_SIZE	MEM_SIZE
//#define	TEST_SIZE	8192
#define	TEST_START	0

int main()
{
	WBMem	m(MEM_SIZE);
	WBCache	c(&m);
	uint32_t	r;
	uint16_t*	stash	= (uint16_t*) malloc(MEM_SIZE);
	uint32_t*	alt	= (uint32_t*) stash;

	// Control block.
	for (int i=0; i<TEST_SIZE/4; i++)
		alt[i]	= rand();

	// Write to cache.
	for (int i=TEST_START/2; i<TEST_SIZE/2; i++) {
		c.write(i, stash[i]);
		if ((r = c.read(i)) != stash[i])	printf("WR(%d):\t%04x\t%04x\n", i, stash[i], c.read(i));
	}

	// Read back and check.
	printf("\n\n");
	for (int i=TEST_START/2; i<TEST_SIZE/2; i++)
		if ((r = c.read(i)) != stash[i])	printf("RB(%d):\t%04x\t%04x (%04x)\n", i, stash[i], c.read(i), r);

	printf("\n\n");
	dump_defines();
	printf("\n\n");
	c.stats();

//
//	for (int i=0; i<128; i+=2) {
//		printf("%04x", c.read(i+1));
//		printf("%04x ", c.read(i));
//	}

	return	0;
}
