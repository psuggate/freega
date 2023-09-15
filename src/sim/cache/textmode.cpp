/*
 * textmode.cpp
 *
 *  Created on: 5/12/2008
 *      Author: Patrick Suggate
 */

#include "textmode.h"
#include "wbmem.h"
#include "cache.h"

#include <stdio.h>

#ifdef __use_cache
extern	WBCachedMem	mem;
#else
extern	WBMem	mem;
#endif


extern int	sp_count;
extern int	gfr_count;
extern int	dcr_count;
extern int	dr_count;


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


// TODO: Optimisations:	Drawing two rows at a time halves the number of
//			accesses to the `font'.
//			Loop unrolling + sheep-run.
//			The same attribute byte is often used for an entire
//			screen, so check previous colour before palette index
//			calculation and colour retrieval?

// A row consists of 80 characters and 640 pixels.
uint32_t draw_row_fast32(uint32_t i_tb, uint32_t i_fb, uint16_t cr)
{
	mem.push(10);
	
	// FETCH_CHAR
	uint8_t	ch, at;
	uint16_t	tmp	= mem.getw(i_tb);
	ch	= (uint8_t) tmp;
	at	= (uint8_t) (tmp>>8);
	i_tb	+= 2;
	
	// DECODE_CHAR
	uint32_t	fg, bg;
	uint8_t	pr;
	pr	= mem.getb(FONT_SEG + ((uint32_t)ch << 4) + (uint32_t)cr);
	fg	= mem.getl(PAL_SEG + ((uint32_t)(at&0x0f)<<2));
	bg	= mem.getl(PAL_SEG + ((uint32_t)(at>>4)<<2));
	
	// used by DRAW_CHAR
	uint32_t	px;

	for (uint16_t n=1; n<CCOLS; n++) {
		// FETCH_CHAR(n)
		tmp	= mem.getw(i_tb);
		ch	= (uint8_t) tmp;
		at	= (uint8_t) (tmp>>8);
		i_tb	+= 2;
		
		// DRAW_CHAR(n-1)
		for (uint16_t i=0; i<8; i++) {
			px	= (pr & 0x80) ? bg : fg ;
			pr	<<= 1;
			mem.putl(i_fb, px);
			i_fb	+= 4;
		}
		
		// DECODE_CHAR(n)
		pr	= mem.getb(FONT_SEG + ((uint32_t)ch << 4) + (uint32_t)cr);
		fg	= mem.getl(PAL_SEG + ((uint32_t)(at&0x0f)<<2));
		bg	= mem.getl(PAL_SEG + ((uint32_t)(at>>4)<<2));
	}
	// DRAW_CHAR(n-1)
	for (uint16_t i=0; i<8; i++) {
		px	= (pr & 0x80) ? bg : fg ;
		pr	<<= 1;
		mem.putl(i_fb, px);
		i_fb	+= 4;
	}
	mem.pop(10);
	return	i_fb;
}


// A row consists of 80 characters and 640 pixels.
uint32_t draw_row_fast16(uint32_t i_tb, uint32_t i_fb, uint16_t cr)
{
	mem.push(10);
	
	// FETCH_CHAR
	uint8_t	ch, at;
	uint16_t	tmp	= mem.getw(i_tb);
	ch	= (uint8_t) tmp;
	at	= (uint8_t) (tmp>>8);
	i_tb	+= 2;
	
	// DECODE_CHAR
	uint16_t	fg, bg;
	uint8_t	pr;
	pr	= mem.getb(FONT_SEG + ((uint32_t)ch << 4) + (uint32_t)cr);
	fg	= mem.getw(PAL_SEG + ((uint32_t)(at&0x0f)<<1));
	bg	= mem.getw(PAL_SEG + ((uint32_t)(at>>4)<<1));
	
	// used by DRAW_CHAR
	uint16_t	px;

	for (uint16_t n=1; n<CCOLS; n++) {
		// FETCH_CHAR(n)
		tmp	= mem.getw(i_tb);
		ch	= (uint8_t) tmp;
		at	= (uint8_t) (tmp>>8);
		i_tb	+= 2;
		
		// DRAW_CHAR(n-1)
		for (uint16_t i=0; i<8; i++) {
			px	= (pr & 0x80) ? bg : fg ;
			pr	<<= 1;
			mem.putw(i_fb, px);
			i_fb	+= 2;
		}
		
		// DECODE_CHAR(n)
		pr	= mem.getb(FONT_SEG + ((uint32_t)ch << 4) + (uint32_t)cr);
		fg	= mem.getw(PAL_SEG + ((uint32_t)(at&0x0f)<<1));
		bg	= mem.getw(PAL_SEG + ((uint32_t)(at>>4)<<1));
	}
	// DRAW_CHAR(n-1)
	for (uint16_t i=0; i<8; i++) {
		px	= (pr & 0x80) ? bg : fg ;
		pr	<<= 1;
		mem.putw(i_fb, px);
		i_fb	+= 2;
	}
	mem.pop(10);
	return	i_fb;
}


void set_pixel(uint16_t x, uint16_t y, uint32_t c)
{
#ifdef __use_32_bit_colour
	mem.push(1);
	uint32_t	ptr	= ((uint32_t)y*PCOLS + (uint32_t)x)*4;
	mem.putl(FB_SEG+ptr, c);
	mem.pop(1);
#else
	uint32_t	ptr	= ((uint32_t)y*PCOLS + (uint32_t)x)*2;
	mem.putw(FB_SEG+ptr, c);
#endif
	sp_count++;	// Stats gathering
}


uint8_t	get_font_row(uint16_t row, uint8_t ch)
{
	gfr_count++;	// Stats gathering
	return	mem.getb(FONT_SEG + (((int) ch) << 4) + (int)row);
}


// TODO: This could be modified to draw two character-rows simultaneously?
void draw_char_row(uint16_t x, uint16_t y, uint8_t ch, uint8_t at)
{
	uint8_t		r	= get_font_row(y & 0x0f, ch);
#ifdef __use_32_bit_colour
	mem.push(10);
	uint32_t	f	= mem.getl(PAL_SEG+(int)((at&0x0f)*4));
	uint32_t	b	= mem.getl(PAL_SEG+(int)((at>>4)*4));
	mem.pop(10);
#else
	mem.push(8);
	uint32_t	f	= mem.getw(PAL_SEG+(int)((at&0x0f)*4));
	uint32_t	b	= mem.getw(PAL_SEG+(int)((at>>4)*4));
	mem.pop(8);
#endif

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
	uint16_t	i, p, idx;
	uint8_t	ch, at;

	mem.push(4);
	// Calc. index into TB from row.
	idx	= (r&0xfff0)*(CCOLS/16);
	for (i=0; i<PCOLS; i+=8) {
		p	= mem.getw(TB_SEG+(idx++)*2);
		ch	= p & 0xff;
		at	= p >> 8;
		draw_char_row(i, r, ch, at);
	}
	dr_count++;	// Stats gathering
	mem.pop(4);
}


#define	__use_optimised
#ifdef	__use_optimised
void update_fb()
{
	uint16_t	i;
	uint32_t	i_tb	= TB_SEG;
	uint32_t	i_fb	= FB_SEG;
	
	mem.push(2);
	// For each row in the TB, draw 16 rows to the FB.
	for (i=0; i<PROWS; i++) {
#ifdef __use_32_bit_colour
		i_fb	= draw_row_fast32(i_tb, i_fb, i&0x0f);
#else
		i_fb	= draw_row_fast16(i_tb, i_fb, i&0x0f);
#endif
		if ((i & 0x000f) == 0xf)
			i_tb	+= CCOLS*2;
	}
	mem.pop(2);
}

#else
void update_fb()
{
	uint16_t	i;
	mem.push(2);
	for (i=0; i<PROWS; i++) {
		draw_row(i);
	}
	mem.pop(2);
}
#endif	// !__use_optimised
