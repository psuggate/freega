/*
 * mytypes.h
 *
 *  Created on: 5/12/2008
 *      Author: patrick
 */

#ifndef MYTYPES_H_
#define MYTYPES_H_


// Settings to test
#define	REDRAW_NUM	50
#define	FAST_COST	5
#define	SLOW_COST	6
#define	CPU_MULT	2
// Prob-to-wait(0.2) * Av-wait-length(68)
#define	CONGESTION	14
#define	SYNCHRONISE	4
#define	TRANSACTION	5
#define	AV_LATENCY	(CPU_MULT*(TRANSACTION+CONGESTION)+SYNCHRONISE)


// NOTE: Order here is important!
// #define __use_32_bit_colour
#define __use_cache
#define __use_write_buffer
#define __use_fast_path
#define __use_write_thru
#define __use_rand_evict
// #define __use_fifo_evict
#define	MEM_SIZE	8388608


#ifdef	__use_write_buffer
#define	__evict_cost	0
#else
#define	__evict_cost	1
#endif


// TODO: This works both on 32-bit and 64-bit CPUs?
typedef long long unsigned int	uint64_t;
typedef unsigned int		uint32_t;
typedef unsigned short		uint16_t;
typedef unsigned char		uint8_t;



#endif /* MYTYPES_H_ */
