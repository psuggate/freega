#include <stdio.h>
#include <stdlib.h>
#include <string.h>


typedef unsigned int	uint32_t;
typedef unsigned short	uint16_t;
typedef unsigned char	uint8_t;

uint32_t*	fb;	// RGBA, 8-bit/component
uint16_t*	tb;	// 8-bit ASCII char + 8-bit attribute
uint8_t*	font;	// 8x16 pixel font
uint32_t*	pal;	// 16 entry colour palette


// Gather procedure call statistics.
int	sp_count	= 0;
int	gfr_count	= 0;
int	dcr_count	= 0;
int	dr_count	= 0;


// Algorithms:
// Character at a time:
// - for each char in `tb' do:
//  - look up fg + bg colours from pal
//  - read a char from the `tb'
//  - for each row in char do:
//   - look up char row from font mem
//   - for each pixel in char row do:
//    - if pixel set, write fg colour to `fb'
//    - else write bg colour to `fb'

// FB-Row-At-A-Time:
// - for each row in FB do:
//  - calc offset into TB
//  - read char from TB
//  - look up fg + bg colours from pal
//...

// FB-Row-At-A-Time has the best SDRAM (+dcache) access behaviour?
#define	PCOLS	640
#define	PROWS	400
#define	CCOLS	80
#define	CROWS	25
#define	TCOLS	8
#define	TROWS	16


// TODO: Optimisations:	Drawing two rows at a time halves the number of
//			accesses to the `font'.
//			Loop unrolling + sheep-run.
//			The same attribute byte is often used for an entire
//			screen, so check previous colour before palette index
//			calculation and colour retrieval?

void set_pixel(uint16_t x, uint16_t y, uint32_t c)
{
	uint32_t	ptr	= (uint32_t)y*PCOLS + (uint32_t)x;
	fb[ptr]	= c;

	sp_count++;	// Stats gathering
}


uint8_t	get_font_row(uint16_t row, uint8_t ch)
{
	gfr_count++;	// Stats gathering
	return	font[(((uint16_t) ch) << 4) + row];
}


// TODO: This could be modified to draw two character-rows simultaneously?
void draw_char_row(uint16_t x, uint16_t y, uint8_t ch, uint8_t at)
{
	uint16_t	j;
	uint8_t		r	= get_font_row(y & 0x0f, ch);
	uint32_t	f	= pal[at&0x0f];
	uint32_t	b	= pal[at>>4];

	do {
		set_pixel(x++, y, r & (uint8_t) 0x80 ? b : f);
		r	<<= 1;
	} while (x&7);
	dcr_count++;	// Stats gathering
}


// This assumes width of 8 pixels/char and height of 16 pixels/char and 80
// chars per row.
void draw_row(uint16_t r)
{
	uint16_t	i, j, p, idx;
	uint8_t	ch, at;

	// Calc. index into TB from row.
	idx	= (r&0xfff0)*(CCOLS/16);
	for (i=0; i<PCOLS; i+=8) {
		p	= tb[idx++];
		ch	= p & 0xff;
		at	= p >> 8;
		draw_char_row(i, r, ch, at);
	}
	dr_count++;	// Stats gathering
}


void update_fb()
{
	uint16_t	i;
	for (i=0; i<PROWS; i++) {
		draw_row(i);
	}
}


//---------------------------------------------------------------------------
// Simulation specific stuff below.
//
int read_txt_row(uint16_t* dst, char* src, int p)
{
	int	n	= 0;
	while(n<CCOLS && src[p]!='\n')
		dst[n++]	= ((uint16_t)src[p++]) | 0x0700;	// Grey on black
	while(n<CCOLS)
		dst[n++]	= 0x0720;	// Space
	return	++p;
}


void read_font(char* fn)
{
	FILE*	fh	= fopen(fn, "r");
	int	i, p	= 0;
	char	str[16];
	uint32_t*	fp	= (uint32_t*) font;
	uint32_t	dat;

	for (i=0; i<512; i++) {
		fscanf(fh, "%s ", str);
		sscanf(str, "%x", &dat);

		// Convert to little-endian.
		font[p++]	= (uint8_t)(dat >> 24);
		font[p++]	= (uint8_t)(dat >> 16);
		font[p++]	= (uint8_t)(dat >> 8);
		font[p++]	= (uint8_t)(dat);
	}
}


void fill_tb(char* tb_file)
{
	char*	str	= malloc(CCOLS*CROWS);
	FILE*	fh	= fopen(tb_file, "r");
	int	i, pos;
	char	ch;

	fread((void*) str, CCOLS*CROWS, 1, fh);
	pos	= 0;

	for (i=0; i<CROWS; i++) {
		pos	= read_txt_row(&tb[i*CCOLS], str, pos);
	}

	fclose(fh);
	free(str);
}


void dump_fb()
{
	int	i, j;
	printf("VSYNC\n");
	for (i=0; i<PROWS; i++) {
		for (j=0; j<PCOLS; j++) {
			if (fb[i*PCOLS+j] != 0)	printf("0 ");
			else			printf("1 ");
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
			printf("%x ", font[i*16+j]);
		}
		printf("\n");
	}
}


void dump_tb()
{
	int	i, j;
	char	str[CCOLS+1];
	str	[CCOLS]	= '\0';
	for (i=0; i<CROWS; i++) {
		for (j=0; j<CCOLS; j++)
			str[j]	= (char)tb[i*CCOLS+j];
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
			str[j]	= (tb[i*CCOLS+j]>>8) == 0x07 ? '7' : '0' ;
		printf("%s\n", str);
	}
}


void dump_letter(char l)
{
	int	i, j, p	= ((int)l)<<4;
	uint8_t	b;
	for (i=0; i<TROWS; i++) {
		b	= font[p++];
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
	fb	= malloc(PCOLS*PROWS*sizeof(uint32_t));
	tb	= malloc(CCOLS*CROWS*sizeof(uint16_t));
	font	= malloc(256*sizeof(uint8_t)*TROWS);

	pal	= malloc(16*sizeof(uint32_t));
	pal[0]	= 0;		// Transparent + black
	pal[7]	= 0xFF808080;	// Opaque + grey

	fill_tb("../../data/splash.txt");
	read_font("../../data/font.hex");
}


int main()
{
	init();
//	dump_tb();
	update_fb();
//	dump_fb();
	printf("Statistics:\n");
	printf("set_pixel\t = %6d\n", sp_count);
	printf("get_font_row\t = %6d\n", gfr_count);
	printf("draw_char_row\t = %6d\n", dcr_count);
	printf("draw_row\t = %6d\n", dr_count);

//	memset((void*)fb, 0x00, PCOLS*PROWS*4);
//	dump_fb();
//	dump_font();
	dump_letter('A');
	return	0;
}
