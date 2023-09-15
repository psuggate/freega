/*
 * main.cpp
 *
 *  Created on: 5/12/2008
 *      Author: patrick
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mytypes.h"
#include "textmode.h"
#include "wbmem.h"
#include "cache.h"


#ifdef __use_cache
WBCachedMem	mem(MEM_SIZE);
#else
WBMem		mem(MEM_SIZE);
#endif


// Gather procedure call statistics.
int	sp_count	= 0;
int	gfr_count	= 0;
int	dcr_count	= 0;
int	dr_count	= 0;


//---------------------------------------------------------------------------
// Simulation specific stuff below.
//
int read_txt_row(uint16_t idx, char* src, int p)
{
	int	n	= 0;
	while(n<CCOLS && src[p]!='\n')
		mem.putw(TB_SEG + (idx+n++)*2, ((uint16_t)src[p++]) | 0x0700);	// Grey on black
	while(n<CCOLS)
		mem.putw(TB_SEG + (idx+n++)*2, (uint16_t)0x0720);		// Space
	return	++p;
}


void read_font(char* fn)
{
	FILE*	fh	= fopen(fn, "r");
	int	i, p	= 0;
	char	str[16];
	uint32_t	dat;

	for (i=0; i<512; i++) {
		fscanf(fh, "%s ", (char*)str);
		sscanf(str, "%x", (uint32_t*)&dat);

		// Convert to little-endian.
		mem.putb(FONT_SEG+p++, (uint8_t)(dat >> 24));
		mem.putb(FONT_SEG+p++, (uint8_t)(dat >> 16));
		mem.putb(FONT_SEG+p++, (uint8_t)(dat >> 8));
		mem.putb(FONT_SEG+p++, (uint8_t)(dat));
	}
}


void fill_tb(char* tb_file)
{
	char*	str	= (char*) malloc(CCOLS*CROWS);
	FILE*	fh	= fopen(tb_file, "r");
	int	i, pos;

	i	= fread((void*) str, CCOLS*CROWS, 1, fh);
	pos	= 0;

//	i=0;
	for (i=0; i<CROWS; i++)
		pos	= read_txt_row(i*CCOLS, str, pos);

	fclose(fh);
	free(str);
}


void dump_fb()
{
	int	i, j;
	printf("VSYNC\n");
	for (i=0; i<PROWS; i++) {
		for (j=0; j<PCOLS; j++) {
#ifdef __use_32_bit_colour
			if (mem.getl(FB_SEG+(i*PCOLS+j)*4) != 0) printf("0 ");
#else
			if (mem.getw(FB_SEG+(i*PCOLS+j)*2) != 0) printf("0 ");
#endif
			else					 printf("1 ");
		}
		printf("\n");
	}
	printf("VSYNC\n");
	printf("\n");
}


void dump_font()
{
	int	i, j;
	for (i=0; i<256; i++) {
		for (j=0; j<16; j++) {
			printf("%x ", mem.getl(FONT_SEG + i*16+j));
		}
		printf("\n");
	}
}


void dump_tb()
{
	int	i, j;
	char	str[CCOLS+1];
	str	[CCOLS]	= '\0';
//	i=0;
	for (i=0; i<CROWS; i++) {
		for (j=0; j<CCOLS; j++)
			str[j]	= (char)mem.getw(TB_SEG + (i*CCOLS+j)*2);
		printf("%s\n", str);
	}
}


void dump_at()
{
	int	i, j;
	char	str[CCOLS+1];
	str	[CCOLS]	= '\0';
	for (i=0; i<CROWS; i++) {
		for (j=0; j<CCOLS; j++)
			str[j]	= (mem.getw(TB_SEG+i*CCOLS+j)>>8) == 0x07 ? '7' : '0' ;
		printf("%s\n", str);
	}
}


void dump_letter(char l)
{
	int	i, j, p	= ((int)l)<<4;
	uint8_t	b;
	for (i=0; i<TROWS; i++) {
		b	= mem.getb(FONT_SEG+p++);
		for (j=0; j<TCOLS; j++) {
			if (b & 0x01)	printf("1");
			else		printf("0");
			b	>>= 1;
		}
		printf("\n");
	}
}


void init()
{
#ifdef __use_32_bit_colour
	mem.putl(PAL_SEG+0, 0x00000000);	// Transparent + black
	mem.putl(PAL_SEG+28, 0xFF808080);	// Opaque + grey
#else
	mem.putw(PAL_SEG+0, 0x0000);	// Transparent + black
	mem.putw(PAL_SEG+14, 0x8410);	// Opaque + grey
#endif
//	fill_tb("../../data/splash.txt");
//	read_font("../../data/font.hex");
	fill_tb("splash.txt");
	read_font("font.hex");
}


// Dump stats or CRT data?
// #define __display_stats

int main()
{
	init();
// 	dump_tb();
	for (int i=REDRAW_NUM; i; i--)
		update_fb();
#ifdef	__display_stats
// 	dump_defines();
#ifdef __use_cache
	mem.stats();
#else
	uint64_t	r, w;
	printf("Memory Statistics:\n");
	printf("Reads:\t\t%ld\n", r=mem.num_reads());
	printf("Writes:\t\t%ld\n", w=mem.num_writes());
	printf("Total:\t\t\t%ld\n\n", r+w);
	uint64_t	cost	= (r+w)*(FAST_COST+AV_LATENCY);
	printf("Total CPU memory access cycles:\t%ld (Av: %2.1f/op)\n\n\n", cost, (float)cost/(float)(r+w));
#endif
#else
	dump_fb();
#endif

//	dump_font();
// 	dump_letter('A');
	return	0;
}
