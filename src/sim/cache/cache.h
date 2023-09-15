/*
 * cache.h
 *
 *  Created on: 5/12/2008
 *      Author: patrick
 */

#ifndef CACHE_H_
#define CACHE_H_


#include "mytypes.h"
#include "wbmem.h"


//----------------------------------------------------------------------------
// Default are settings for a cache with a line-size of 64 bytes, addressable
// memory of 22-bits, with a word-size of 2 bytes, giving a total of 8 MB of
// cacheable memory. Total cache storage is 2048 bytes, associativity is set
// to 2, and is not modifiable (yet).
//
// Tag format:
//	{VALID(1), DIRTY(1), DATA(13), INDEX(4), OFFSET(5)}
//

#define	CACHE_ADDRBITS	22
#define	CACHE_MEMBITS	11
#define	CACHE_MEMSIZE	(1<<CACHE_MEMBITS)
#define	CACHE_WORDBITS	1
#define	CACHE_WORDSIZE	(1<<CACHE_WORDBITS)
#define	CACHE_LINEBITS	6
#define	CACHE_LINESIZE	(1<<CACHE_LINEBITS)
#define	CACHE_ASSOCBITS	1
#define	CACHE_ASSOC	(1<<CACHE_ASSOCBITS)
#define	CACHE_BANKBITS	(CACHE_MEMBITS-CACHE_WORDBITS-CACHE_ASSOCBITS)
#define	CACHE_BANKSIZE	(1<<CACHE_BANKBITS)
#define	CACHE_BANKNUM	CACHE_ASSOC
#define	CACHE_OFFBITS	(CACHE_LINEBITS-CACHE_WORDBITS)
#define	CACHE_IDXBITS	(CACHE_BANKBITS-CACHE_OFFBITS)
#define	CACHE_DATABITS	((CACHE_ADDRBITS+CACHE_WORDBITS+CACHE_ASSOCBITS)-CACHE_MEMBITS)
#define	CACHE_TAGNUM	(1<<CACHE_IDXBITS)
#define	CACHE_ADDRMAX	((1<<(CACHE_ADDRBITS+CACHE_WORDBITS))-1)

#define	CACHE_OFFMASK	((1<<CACHE_OFFBITS)-1)
#define	CACHE_IDXMASK	((1<<CACHE_IDXBITS)-1)
#define	CACHE_DATAMASK	((1<<CACHE_DATABITS)-1)

#define	CACHE_TOFF(a)	((a) & CACHE_OFFMASK)
#define	CACHE_TIDX(a)	(((a)>>CACHE_OFFBITS) & CACHE_IDXMASK)
#define	CACHE_TDATA(a)	(((a)>>(CACHE_OFFBITS+CACHE_IDXBITS)) & CACHE_DATAMASK)

#define	CACHE_ADDR(a,b)		(((a)<<CACHE_OFFBITS) | (b))
#define	CACHE_MEMADDR(a, b)	((((a)<<(CACHE_IDXBITS+CACHE_OFFBITS)) | (b))<<1)
#define	CACHE_ENTRY(a)		((a) & ((CACHE_IDXMASK<<CACHE_OFFBITS) | CACHE_OFFMASK))


#if CACHE_ASSOC != 2
#error	ERROR: Currently, the cache must have a set-assoicativity of 2!
#endif


void	dump_defines	(void);


class Tag {
public:
			Tag	(void)			{ dirty = false; valid = false; data = 0; }
			~Tag	(void)			{}

	inline bool	hit	(const uint32_t a)	{ return ((a == data) && valid); }
	inline void	set	(const uint32_t t)	{ dirty = false; valid = true; data = t; }
	inline void	mark	(void)			{ dirty = true; }
	inline uint32_t	tag	(void)			{ return data; }
	inline void	invld	(void)			{ valid = false; }
	inline bool	wrback	(void)			{ return dirty && valid; }

private:
	bool		dirty;
	bool		valid;
	uint32_t	data;
};


class WBCache {
public:
			WBCache	(WBMem*);
			~WBCache(void);

	uint16_t	read	(int);
	void		write	(int, uint16_t);
	void		stats	(void);
private:
	void		evict	(uint16_t* b, Tag* t, int idx);
	uint16_t	fetch	(uint16_t* b, Tag* t, int adr);

	uint32_t	p_tag0, p_tag1;
	uint32_t	p_idx0, p_idx1;
	bool		p_vld0, p_vld1;

	// Stats gathering variables.
	uint64_t	accesses, misses, slow, evicts, wrtc, hits;

	WBMem*		m;
	Tag*		t0;
	Tag*		t1;
	uint16_t*	b0;
	uint16_t*	b1;
	bool*		lru;
};


class WBCachedMem {
public:
	WBCachedMem	(int s)	{ m	= new WBMem(s); c = new WBCache(m);	sp = CACHE_ADDRMAX-1; }
	~WBCachedMem	(void)	{ delete m; delete c; }

	uint32_t	getl	(int p);
	inline uint16_t	getw	(int p)	{ return	c->read(p>>1); }
	uint8_t		getb	(int p);

	uint32_t	putl	(int p, uint32_t v);
	inline uint16_t	putw	(int p, uint16_t v)	{ c->write(p>>1, v); return v; }
	uint8_t		putb	(int p, uint8_t v);

	// Just used for stats gathering.
	void		push	(int n);
	void		pop	(int n);

	void		stats	(void);

private:
	WBCache*	c;
	WBMem*		m;
	int		sp;
};


#endif /* CACHE_H_ */
