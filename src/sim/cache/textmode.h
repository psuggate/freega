/*
 * textmode.h
 *
 *  Created on: 5/12/2008
 *      Author: patrick
 */

#ifndef TEXTMODE_H_
#define TEXTMODE_H_

#include "mytypes.h"

// These are byte-aligned addresses.
#define	FB_SEG		0x00400000
#define	TB_SEG		0x00008000
#define	FONT_SEG	0x0000C000
#define	PAL_SEG		0x0000E000


// FB-Row-At-A-Time has the best SDRAM (+dcache) access behaviour?
#define	PCOLS	640
#define	PROWS	400
#define	CCOLS	80
#define	CROWS	25
#define	TCOLS	8
#define	TROWS	16

void	set_pixel	(uint16_t x, uint16_t y, uint32_t c);
uint8_t	get_font_row	(uint16_t row, uint8_t ch);
void	draw_char_row	(uint16_t x, uint16_t y, uint8_t ch, uint8_t at);
void	draw_row	(uint16_t r);
void	update_fb	(void);

// Optimised version
uint32_t	draw_row_fast2	(uint32_t i_tb, uint32_t i_fb, uint16_t cr);


#endif /* TEXTMODE_H_ */
