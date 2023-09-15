#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define __use_cache

// TODO: This works both on 32-bit and 64-bit CPUs?
typedef long unsigned int	uint64_t;
typedef unsigned int		uint32_t;
typedef unsigned short		uint16_t;
typedef unsigned char		uint8_t;


#define	FB_SEG		0x00400000
#define	TB_SEG		0x00008000
#define	FONT_SEG	0x0000C000
#define	PAL_SEG		0x0000E000


// Gather procedure call statistics.
int	sp_count	= 0;
int	gfr_count	= 0;
int	dcr_count	= 0;
int	dr_count	= 0;


// So we can collect statistics, cache hit/miss, total accesses, etc.
#define	MEM_SIZE	8388608
class WBMem {
public:
	WBMem	(int s)	{ m	= new uint8_t[s]; r = 0; w = 0; }
	~WBMem	(void)	{ delete[] m; }

	inline uint32_t	getl(int p) { r+=2; return ((uint32_t*)m)[p>>2]; }
	inline uint16_t	getw(int p) { r++; return ((uint16_t*)m)[p>>1]; }
	inline uint8_t	getb(int p) { r++; return ((uint8_t*)m)[p]; }

	inline uint32_t	putl(int p, uint32_t v) { w+=2; return ((uint32_t*)m)[p>>2]	= v; }
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

class Tag {
public:
			Tag	(void)	{ dirty = false; valid = false; data = 0; }
			~Tag	(void)	{}

	bool		hit	(uint32_t);

	bool		dirty;
	bool		valid;
	uint32_t	data;
};


bool Tag::hit(uint32_t a)
{
	return	((a == data) && valid);
}


class WBCache {
public:
			WBCache	(WBMem*);
			~WBCache(void);

	uint16_t	read	(int);
	void		write	(int, uint16_t);
private:
	void		evict	(uint16_t* b, Tag* t, int idx);
	uint16_t	fetch	(uint16_t* b, Tag* t, int adr);

	uint32_t	p_tag0;
	uint32_t	p_idx0;
	bool		p_vld0;
	uint32_t	p_tag1;
	uint32_t	p_idx1;
	bool		p_vld1;

	WBMem*		m;
	Tag*		t0;
	Tag*		t1;
	uint16_t*	b0;
	uint16_t*	b1;
	bool*		lru;
};


WBCache::WBCache(WBMem* mem)
{
	m	= mem;
	// Two banks of tags and memory.
	t0	= new Tag[CACHE_TAGNUM];
	b0	= new uint16_t[CACHE_BANKSIZE];

	t1	= new Tag[CACHE_TAGNUM];
	b1	= new uint16_t[CACHE_BANKSIZE];

	lru	= new bool[CACHE_TAGNUM];
	for (int i=0; i<CACHE_TAGNUM; i++)
		lru[i]	= false;

	p_tag0	= 0;
	p_idx0	= 0;
	p_vld0	= false;

	p_tag1	= 0;
	p_idx1	= 0;
	p_vld1	= false;
}


WBCache::~WBCache(void)
{
	delete[] t0;
	delete[] b0;
	delete[] t1;
	delete[] b1;
}


// 1/ Check cache
// 2/ If hit:	return data
//    Else:	Fetch cacheline
//		return data
//
uint16_t WBCache::read(int a)
{
	uint32_t	tag	= CACHE_TDATA(a);
	uint32_t	idx	= CACHE_TIDX(a);
	uint32_t	off	= CACHE_TOFF(a);

//	printf("tag = %x\n", tag);
//	printf("idx = %x\n", idx);
//	printf("off = %x\n", off);
//	printf("p_tag0 = %x\n", p_tag0);
//	printf("p_idx0 = %x\n", p_idx0);
//	printf("p_vld0 = %x\n", p_vld0);
//	printf("p_tag1 = %x\n", p_tag1);
//	printf("p_idx1 = %x\n", p_idx1);
//	printf("p_vld1 = %x\n\n", p_vld1);

	// Fast hit path.
	if (p_tag0 == tag && p_idx0 == idx && p_vld0)
		return	b0[CACHE_ADDR(idx, off)];

	if (p_tag1 == tag && p_idx1 == idx && p_vld1)
		return	b1[CACHE_ADDR(idx, off)];

	// Slower hit path.
//	printf("idx = %x  t0[idx].data = %x  tag = %x  valid = %d\n", idx, t0[idx].data, tag, t0[idx].valid);
	if (t0[idx].hit(tag)) {
//		printf("Hi\n");
		p_tag0	= tag;
		p_idx0	= idx;
		p_vld0	= true;
		return	b0[CACHE_ADDR(idx, off)];
	}

	if (t1[idx].hit(tag)) {
		p_tag1	= tag;
		p_idx1	= idx;
		p_vld1	= true;
		return	b1[CACHE_ADDR(idx, off)];
	}

	// Miss and fetch path.
	// Is the old data dirty? If so evict.
	if (lru[idx] && t1[idx].dirty && t1[idx].valid)
		evict(b1, &t1[idx], idx);
	else if (!lru[idx] && t0[idx].dirty && t0[idx].valid)
		evict(b0, &t0[idx], idx);

	uint16_t	rv;
	if (lru[idx])	{
//		printf("Fetching to Bank1\n");
		rv	= fetch(b1, &t1[idx], a);
		p_tag1	= tag;
		p_idx1	= idx;
		p_vld1	= true;
		lru[idx]= false;
	} else {
//		printf("Fetching to Bank0\n");
		rv	= fetch(b0, &t0[idx], a);
		p_tag0	= tag;
		p_idx0	= idx;
		p_vld0	= true;
		lru[idx]= true;
	}
//	printf("\n\n\n");

	return	rv;
}


void WBCache::write(int a, uint16_t dat)
{
	uint32_t	tag	= CACHE_TDATA(a);
	uint32_t	idx	= CACHE_TIDX(a);
	uint32_t	off	= CACHE_TOFF(a);

//	printf("tag = %x\n", tag);
//	printf("idx = %x\n", idx);
//	printf("off = %x\n", off);
//	printf("p_tag0 = %x\n", p_tag0);
//	printf("p_idx0 = %x\n", p_idx0);
//	printf("p_vld0 = %x\n", p_vld0);
//	printf("p_tag1 = %x\n", p_tag1);
//	printf("p_idx1 = %x\n", p_idx1);
//	printf("p_vld1 = %x\n\n", p_vld1);

	// Fast hit path.
	if (this->p_tag0 == tag && this->p_idx0 == idx && this->p_vld0) {
		this->t0[idx].dirty	= true;
		this->b0[CACHE_ADDR(idx, off)]	= dat;
		return;
	}

	if (this->p_tag1 == tag && this->p_idx1 == idx && this->p_vld1) {
		this->t1[idx].dirty	= true;
		this->b1[CACHE_ADDR(idx, off)]	= dat;
		return;
	}

	// Slower hit path.
	if (this->t0[idx].hit(tag)) {
		this->p_tag0	= tag;
		this->p_idx0	= idx;
		this->p_vld0	= true;
		this->t0[idx].dirty	= true;
		this->b0[CACHE_ADDR(idx, off)]	= dat;
		return;
	}

	if (this->t1[idx].hit(tag)) {
		this->p_tag1	= tag;
		this->p_idx1	= idx;
		this->p_vld1	= true;
		this->t1[idx].dirty	= true;
		this->b1[CACHE_ADDR(idx, off)]	= dat;
		return;
	}

	// Miss and fetch path.
	// Is the old data dirty? If so evict.
	if (this->lru[idx] && this->t1[idx].dirty && this->t1[idx].valid)
		this->evict(this->b1, &this->t1[idx], idx);
	else if (!this->lru[idx] && this->t0[idx].dirty && this->t0[idx].valid)
		this->evict(this->b0, &this->t0[idx], idx);

	if (lru[idx])	{
		fetch(b1, &t1[idx], a);
		t1[idx].dirty	= true;
		b1[CACHE_ADDR(idx, off)]	= dat;
		p_tag1	= tag;
		p_idx1	= idx;
		p_vld1	= true;
		lru[idx]= false;
//		printf("Fetching to Bank1(%d)\n", t1[idx].valid);
	} else {
		fetch(b0, &t0[idx], a);
		t0[idx].dirty	= true;
		b0[CACHE_ADDR(idx, off)]	= dat;
		p_tag0	= tag;
		p_idx0	= idx;
		p_vld0	= true;
		lru[idx]= true;
//		printf("Fetching to Bank0(%d)\n", t0[idx].valid);
	}
}


void WBCache::evict(uint16_t* b, Tag* t, int idx)
{
	int	a	= CACHE_ADDR(idx, 0);
	uint32_t	d;

//	printf("evict@%8x\n", a);

	for (int i=0; i<CACHE_LINESIZE/4; i++) {
		d	= (uint32_t)b[a++];
		d	|= ((uint32_t)b[a++])<<16;
		this->m->putl(CACHE_MEMADDR(t->data, a), d);
	}
	t->valid	= false;
}


uint16_t WBCache::fetch(uint16_t* b, Tag* t, int adr)
{
	uint32_t	d;
	int		p	= CACHE_ADDR(CACHE_TIDX(adr), 0);

	adr	&= ~CACHE_OFFMASK;
	adr	<<= 1;

//	printf("fetch@%8x\n", adr);

	// Fetch new data.
	for (int i=0; i<CACHE_LINESIZE/4; i++) {
		d	= this->m->getl(adr);	// Convert word address to byte address
		b[p++]	= (uint16_t)d;
		b[p++]	= (uint16_t)(d>>16);
		adr	+= 4;
	}
	t->valid	= true;
	t->dirty	= false;
	t->data		= CACHE_TDATA(adr>>1);
	return	b0[CACHE_ENTRY(adr)];
}


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

	inline uint64_t	num_reads	(void)	{ return m->num_reads(); }
	inline uint64_t	num_writes	(void)	{ return m->num_writes(); }

private:
	WBCache*	c;
	WBMem*		m;
	int		sp;
};


// Assume DWord alignment of `p'.
uint32_t WBCachedMem::getl(int p)
{
	uint32_t	d;
	d	= c->read(p>>1);
	d	|= ((uint32_t)c->read((p>>1)+1))<<16;

	return	d;
}


uint8_t WBCachedMem::getb(int p)
{
	uint16_t	d;
	d	= c->read(p>>1);
	if (p&0x1)	return	(uint8_t)(d >> 8);
	else		return	(uint8_t)d;
}


// Assume DWord alignment of `p'.
uint32_t WBCachedMem::putl(int p, uint32_t v)
{
	c->write(p>>1, (uint16_t)v);
	c->write((p>>1)+1, (uint16_t)(v>>16));
	return	v;
}


// No byte access, so read before write.
uint8_t WBCachedMem::putb(int p, uint8_t v)
{
	uint16_t	t	= c->read(p>>1);
	if (p&0x1)	c->write(p>>1, (t&0x00ff) | ((uint16_t)v<<8));
	else		c->write(p>>1, (t&0xff00) | (uint16_t)v);
	return	v;
}


void WBCachedMem::push(int n)
{
	for (; n>0; n--)
		this->c->write(sp-->>1, rand());
}


void WBCachedMem::pop(int n)
{
	for (; n>0; n--)
		this->c->read(sp++>>1);
}


#ifdef __use_cache
WBCachedMem	mem(MEM_SIZE);
#else
WBMem		mem(MEM_SIZE);
#endif

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
	uint32_t	ptr	= ((uint32_t)y*PCOLS + (uint32_t)x)*4;
	mem.push(1);
	mem.putl(FB_SEG+ptr, c);
// 	fb[ptr]	= c;
	sp_count++;	// Stats gathering
	mem.pop(1);
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
	uint32_t	f	= mem.getl(PAL_SEG+(int)((at&0x0f)*4));
	uint32_t	b	= mem.getl(PAL_SEG+(int)((at>>4)*4));
// 	uint32_t	f	= pal[at&0x0f];
// 	uint32_t	b	= pal[at>>4];

	mem.push(10);
	do {
		set_pixel(x++, y, r & (uint8_t) 0x80 ? b : f);
		r	<<= 1;
	} while (x&7);
	mem.pop(10);
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
// 		p	= tb[idx++];
		p	= mem.getw(TB_SEG+(idx++)*2);
		ch	= p & 0xff;
		at	= p >> 8;
		draw_char_row(i, r, ch, at);
	}
	dr_count++;	// Stats gathering
	mem.pop(4);
}


void update_fb()
{
	uint16_t	i;
	mem.push(2);
	for (i=0; i<PROWS; i++) {
		draw_row(i);
	}
	mem.pop(2);
}


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
			if (mem.getl(FB_SEG+(i*PCOLS+j)*4) != 0) printf("0 ");
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


void dump_defines(void)
{
	printf("OFFMASK\t = %x\n", CACHE_OFFMASK);
	printf("IDXMASK\t = %x\n", CACHE_IDXMASK);
	printf("DATAMASK\t = %x\n", CACHE_DATAMASK);

	printf("LINESIZE\t = %d\n", CACHE_LINESIZE);
	printf("TAGNUM\t = %d\n", CACHE_TAGNUM);
}


void init()
{
	mem.putl(PAL_SEG+0, 0x00000000);	// Transparent + black
	mem.putl(PAL_SEG+28, 0xFF808080);	// Opaque + grey

//	fill_tb("../../data/splash.txt");
//	read_font("../../data/font.hex");
	fill_tb("splash.txt");
//	read_font("font.hex");
}


int main()
{
//	printf("Writing block\n");
//	for (int i=0; i<256; i+=4)
//		mem.putl(i, i | (i<<16));
//	printf("Reading block\n");
//	for (int i=0; i<256; i+=4)
//		printf("%x\n", mem.getl(i));
	dump_defines();
	init();
 	dump_tb();
	update_fb();
// 	dump_fb();
#define __display_stats
#ifdef	__display_stats
	printf("Statistics:\n");
	printf("set_pixel\t = %8d\n", sp_count);
	printf("get_font_row\t = %8d\n", gfr_count);
	printf("draw_char_row\t = %8d\n", dcr_count);
	printf("draw_row\t = %8d\n", dr_count);
	printf("Memory reads:\t = %8lu\n", mem.num_reads());
	printf("Memory writes:\t = %8lu\n", mem.num_writes());
#endif

//	dump_font();
// 	dump_letter('A');
	return	0;
}
