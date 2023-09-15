/*
 * cache.h
 *
 *  Created on: 4/12/2008
 *      Author: patrick
 */

#include "cache.h"
#include <stdio.h>
#include <stdlib.h>


// TODO: Parameterise write-thru behaviour.


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

	accesses= 0;
	misses	= 0;
	hits	= 0;
	slow	= 0;
	evicts	= 0;
}


WBCache::~WBCache(void)
{
	delete[] t0;
	delete[] b0;
	delete[] t1;
	delete[] b1;
}


// Costing:
// - A fast-hit only costs two CPU cycles, a slow-hit takes three.
// - Due to refreshing and congestion, a single word fetch costs about 40
//   cycles on average. A whole cache-line is fetched though, at 1/3 of the
//   CPU clock rate, but at 32-bits/per transfer. An evict requires the
//   contents of the cache to be written back first. If this is buffered,
//   then there is probably no penalty in most situations.
void WBCache::stats(void)
{
	float	rate	= (float)misses / (float)accesses * 1000.0f;
	float	fast	= (float)(hits-slow) / (float)(hits) * 100.f;
	printf("Cache Statistics:\n");
	printf("Accesses:\t%lu\n", accesses+wrtc);
#ifdef __use_write_thru
	printf("Write Thrus:\t%lu\n", wrtc);
	printf("Read Hits:\t%lu (%2.1f%%)\n", hits, (float)hits/(float)accesses*100.0f);
#else
	printf("Hits:\t\t%lu (%2.1f%%)\n", hits, (float)hits/(float)accesses*100.0f);
#endif
	printf("Fast Hits:\t%lu (%2.1f%%)\n", hits-slow, fast);
	printf("Misses:\t\t%lu\t(evicts = %lu)\n", misses, evicts);
	printf("Miss rate(per 1000):\t%3.1f\n\n", rate);
#ifdef __use_write_buffer
	uint64_t	wrthru_cost	= FAST_COST;
#else
	uint64_t	wrthru_cost	= AV_LATENCY*CPU_MULT;
#endif
	uint64_t cost	= (hits-slow)*FAST_COST +
			  slow*SLOW_COST +
			  wrthru_cost*wrtc +
			  (misses + __evict_cost*evicts)*(SLOW_COST+AV_LATENCY-1+CACHE_LINESIZE/4*CPU_MULT);
	printf("Total CPU memory access cycles:\t%lu (Av: %1.1f/op)\n\n\n", cost, (float)cost / (float)(accesses+wrtc));
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
	
	hits++;
	accesses++;

#ifdef __use_rand_evict
	bool	new_lru	= (rand()&0x1) ? true : false ;
#else
	bool	new_lru	= !lru[idx];
#endif

#ifdef __use_fast_path
	if (p_tag0 == tag && p_idx0 == idx && p_vld0) {
#ifndef __use_fifo_evict
		lru[idx]	= true;
#endif
		return	b0[CACHE_ADDR(idx, off)];
	}
	if (p_tag1 == tag && p_idx1 == idx && p_vld1) {
#ifndef __use_fifo_evict
		lru[idx]	= false;
#endif
		return	b1[CACHE_ADDR(idx, off)];
	}
#endif	// __use_fast_path

	slow++;

	// Slower hit path.
	if (t0[idx].hit(tag)) {
		p_tag0	= tag;
		p_idx0	= idx;
		p_vld0	= true;
#ifndef __use_fifo_evict
		lru[idx]	= true;
#endif
		return	b0[CACHE_ADDR(idx, off)];
	}

	if (t1[idx].hit(tag)) {
		p_tag1	= tag;
		p_idx1	= idx;
		p_vld1	= true;
#ifndef __use_fifo_evict
		lru[idx]	= false;
#endif
		return	b1[CACHE_ADDR(idx, off)];
	}

	hits--;
	slow--;
	misses++;

	// Miss and fetch path.
	// Is the old data dirty? If so evict.
	if (lru[idx] && t1[idx].wrback())
		evict(b1, &t1[idx], idx);
	else if (!lru[idx] && t0[idx].wrback())
		evict(b0, &t0[idx], idx);

	uint16_t	rv;
	if (lru[idx])	{
		rv	= fetch(b1, &t1[idx], a);
		p_tag1	= tag;
		p_idx1	= idx;
		p_vld1	= true;
		lru[idx]= new_lru;
	} else {
		rv	= fetch(b0, &t0[idx], a);
		p_tag0	= tag;
		p_idx0	= idx;
		p_vld0	= true;
		lru[idx]= new_lru;
	}

	return	rv;
}


// Write through is simpler and avoids some coherency issues, but I suspect
// that it will be a lot slower.
void WBCache::write(int a, uint16_t dat)
{
	uint32_t	tag	= CACHE_TDATA(a);
	uint32_t	idx	= CACHE_TIDX(a);
	uint32_t	off	= CACHE_TOFF(a);

#ifdef __use_write_thru
	wrtc++;
	m->putw(a<<1, dat);
#else
	hits++;
	accesses++;
#endif
	
#ifdef __use_rand_evict
	bool	new_lru	= (rand()&0x1) ? true : false ;
#else
	bool	new_lru	= !lru[idx];
#endif

	// Fast hit path.
#ifdef __use_fast_path
	if (this->p_tag0 == tag && this->p_idx0 == idx && this->p_vld0) {
		this->b0[CACHE_ADDR(idx, off)]	= dat;
#ifndef __use_fifo_evict
		lru[idx]	= true;
#endif
#ifndef __use_write_thru
		this->t0[idx].mark();
#endif
		return;
	}

	if (this->p_tag1 == tag && this->p_idx1 == idx && this->p_vld1) {
		this->b1[CACHE_ADDR(idx, off)]	= dat;
#ifndef __use_fifo_evict
		lru[idx]	= false;
#endif
#ifndef __use_write_thru
		this->t1[idx].mark();
#endif
		return;
	}
#endif	// !__use_fast_path
	
#ifndef __use_write_thru
	slow++;
#endif
	// Slower hit path.
	if (this->t0[idx].hit(tag)) {
		this->p_tag0	= tag;
		this->p_idx0	= idx;
		this->p_vld0	= true;
#ifndef __use_fifo_evict
		lru[idx]	= true;
#endif
		this->b0[CACHE_ADDR(idx, off)]	= dat;
#ifndef __use_write_thru
		this->t0[idx].mark();
#endif
		return;
	}

	if (this->t1[idx].hit(tag)) {
		this->p_tag1	= tag;
		this->p_idx1	= idx;
		this->p_vld1	= true;
#ifndef __use_fifo_evict
		lru[idx]	= false;
#endif
		this->b1[CACHE_ADDR(idx, off)]	= dat;
#ifndef __use_write_thru
		this->t1[idx].mark();
#endif
		return;
	}

#ifndef __use_write_thru	// Stalls processor if no write buffer, so count as miss.
	hits--;
	slow--;
	misses++;	// Write-backs can miss too
	
	// Miss and fetch path.
	// Is the old data dirty? If so evict.
	if (lru[idx] && t1[idx].wrback())
		this->evict(this->b1, &this->t1[idx], idx);
	else if (!lru[idx] && t0[idx].wrback())
		this->evict(this->b0, &this->t0[idx], idx);

	if (lru[idx])	{
		fetch(b1, &t1[idx], a);
		this->t1[idx].mark();
		b1[CACHE_ADDR(idx, off)]	= dat;
		p_tag1	= tag;
		p_idx1	= idx;
		p_vld1	= true;
		lru[idx]= new_lru;
	} else {
		fetch(b0, &t0[idx], a);
		this->t0[idx].mark();
		b0[CACHE_ADDR(idx, off)]	= dat;
		p_tag0	= tag;
		p_idx0	= idx;
		p_vld0	= true;
		lru[idx]= new_lru;
	}
#endif
}	// write


void WBCache::evict(uint16_t* b, Tag* t, int idx)
{
	int	a	= CACHE_ADDR(idx, 0);
	uint32_t	d;
	evicts++;

	for (int i=0; i<CACHE_LINESIZE/4; i++) {
		d	= (uint32_t)b[a];
		d	|= ((uint32_t)b[a+1])<<16;
		uint32_t	adr	= CACHE_MEMADDR(t->tag(), a);
		this->m->putl(adr, d);
		a	+= 2;
	}
	t->invld();
}


uint16_t WBCache::fetch(uint16_t* b, Tag* t, int adr)
{
	uint32_t	d, a;
	int	p	= CACHE_ADDR(CACHE_TIDX(adr), 0);
	a	= (adr & ~CACHE_OFFMASK) << 1;

	for (int i=0; i<CACHE_LINESIZE/4; i++) {
		d	= this->m->getl(a);	// Convert word address to byte address
		b[p++]	= (uint16_t)d;
		b[p++]	= (uint16_t)(d>>16);
		a	+= 4;
	}
	t->set(CACHE_TDATA(adr));
	return	b[CACHE_ENTRY(adr)];
}


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


void dump_defines(void)
{
	printf("OFFMASK\t = %x\n", CACHE_OFFMASK);
	printf("IDXMASK\t = %x\n", CACHE_IDXMASK);
	printf("DATAMASK\t = %x\n", CACHE_DATAMASK);

	printf("LINESIZE\t = %d\n", CACHE_LINESIZE);
	printf("TAGNUM\t = %d\n", CACHE_TAGNUM);
}


void WBCachedMem::stats(void)
{
	uint64_t	r, w;
	
	printf("\nCache Properties:\n");
	printf("\tCache Size:\t\t%6d\n", CACHE_MEMSIZE);
	printf("\tTags per Bank:\t\t%6d\n", CACHE_TAGNUM);
	printf("\tSet associativity:\t 2-way\n");
	printf("\tLine (Block) Size:\t%6d\n", CACHE_LINESIZE);
#ifdef	__use_write_thru
	printf("\tWrite Policy:\t\t  thru\n\n");
#else
	printf("\tWrite Policy:\t\t  back\n\n");
#endif
	
	printf("Memory Statistics:\n");
	printf("Reads:\t\t%lu\n", r=m->num_reads());
	printf("Writes:\t\t%lu\n", w=m->num_writes());
	printf("Total:\t\t\t%lu\n\n", r+w);
	
	c->stats();
}
