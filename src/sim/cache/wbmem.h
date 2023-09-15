/*
 * wbmem.h
 *
 *  Created on: 5/12/2008
 *      Author: patrick
 */

#ifndef WBMEM_H_
#define WBMEM_H_


#include "mytypes.h"


// So we can collect statistics, cache hit/miss, total accesses, etc.
#define	MEM_SIZE	8388608
class WBMem {
public:
	WBMem	(int s)	{ m	= new uint8_t[s]; r = 0; w = 0; }
	~WBMem	(void)	{ delete[] m; }

	inline uint32_t	getl(int p) { r+=2; return ((uint32_t*)m)[p>>2]; }
	inline uint16_t	getw(int p) { r++; return ((uint16_t*)m)[p>>1]; }
	inline uint8_t	getb(int p) { r++; return ((uint8_t*)m)[p]; }

#ifdef __use_cache
	// When using the cache, memory accesses are 32-bit, instead of 16-bit.
	inline uint32_t	putl(int p, uint32_t v) { w++; return ((uint32_t*)m)[p>>2]	= v; }
#else
	inline uint32_t	putl(int p, uint32_t v) { w+=2; return ((uint32_t*)m)[p>>2]	= v; }
#endif
	inline uint16_t	putw(int p, uint16_t v) { w++; return ((uint16_t*)m)[p>>1]	= v; }
	inline uint8_t	putb(int p, uint8_t v)  { w++; return ((uint8_t*)m)[p]		= v; }

	inline uint64_t	num_reads(void)		{ return r; }
	inline uint64_t	num_writes(void)	{ return w; }

	// Just used for stats gathering.
	inline void	push	(int n)	{ w += n; }
	inline void	pop	(int n)	{ r += n; }
private:
	uint8_t*	m;
	uint64_t	r, w;
};


#endif /* WBMEM_H_ */
