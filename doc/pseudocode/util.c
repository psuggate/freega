void* memcpy (void* dst, void* src, int words)
{
	int	i	= words;
	do {
		words--;
		*src	= *dst;
		src++;
		dst++;
	} while (words != 0) ;
}


// @167 MHz, assuming 3-latency on reads, this'll take 9 cycles, or 54 ns.
// Assembly:
//	r2	- Read address
//	r3	- Write address
//	r4	- Counter
	{p]	,		r2->rad,	r2->com		}
	{p]	r3->wad,	,				}
	{u]	r3->sub,	com->inc,	-1->com		}
.align	4
loop:
	// This first write to the read-address, `rad', register prefetches
	// the next word from memory, saving latency over a RISC.
	// NOTE: To prevent a cache miss from messing with state flags,
	// code alignment is VERY IMPORTANT! The entire critical loop will
	// fit within a single cacheline (4x32-bit).
	{p]	r4->sub,	inc->rad,			}
	{p]	memh->memh,	meml, meml,			}
	{p]	,		,				}
	{p]	r3->sub,	inc->inc,			}
	{u]	diff->r4,	bno->loop,			}
	{p]	diff->r3,	,				}
	{p]	diff->wad,	,				}
	
	
	// Minimum memory copy and pointer increment?
	{p:	memh->memh,	meml->meml,			}
	{p:	diff->wad,	inc->rad,			}
	{p:	diff->sub,	inc->inc,			}
	
	
// 18-bit RISC doing a 32-bit memory move:
// @90 MHz, assuming 2-latency on reads, this'll take 10 cycles, or 110 ns.
loop:	load	$0, 0($2)
	load	$1, 2($2)
	store	0($3), $0
	store	2($3), $0
	add	$2, $2, 4
	add	$3, $3, 4
	sub	$4, $4, 1
	bnz	loop
	

// PUSH/POP?
//   Problem is to store an 18-bit value in 32-bit memory. For memory
// operations, the upper two bits of an 18-bit word are byte enables (which
// are active low).
//  r0	- Reg to push
//  r14	- SP

a	:= r0 >> 9;
b	:= r0 & 0x1FF;
[r14]	:= {a, b};
r14	:= r14 + 1;

.align	4
push:
	{u]	,		512->mul,	r0->com		}
	{u]	511->and,	r14->inc,			}
	{p]	r14->wad,	,		plo->com	}
	{p]	com->sub,	,		0->com		}
	{p]	,		,		bits->com	}
	{p]	diff->memh,	com->meml,	inc->com	}
	{p]	com->r14,	,				}
	

a	:= r0 >> 9;
b	:= r0 & 0x1FF;
[r14]	:= {a, b};
r14	:= r14 + 1;
a	:= r1 >> 9;
b	:= r1 & 0x1FF;
[r14]	:= {a, b};
r14	:= r14 + 1;

.align4
push2:
	{u]	,		r0->mul,	512->com	}
	{u]	511->r1,	com->mul,	r1->com		}
	
	//	r1->$1				r0*512->com
	{p]	com->r1,		,	phi->com	}
	//	r0*512->$0			511->com
	{p]	com->r0,	,		r1->com		}
	
	{p]	r0->and,	,				}
	{p]	r1->and,	,				}
	
	//					r0&511
	{p]	r14->wad,	r14->inc,	bits->com	}
	//	r0>>9->memh	r0&0x1ff	(r1>>9)->com
	{p]	r0->memh,	com->meml,	phi->com	}	// FIXME
	
	{p]	com->sub,	inc->inc,	0->com		}
	//					(r1&0x1FF)->com
	{p]	inc->wad,	,		bits->com	}	// FIXME
	
	//	{(r1>>9),	(r1&0x1FF)}
	{p]	diff->memh,	com->meml,	inc->com	}
	{p]	com->r14,	,				}
	


`define	D0S_COM		3'b000
`define	D0S_RF		3'b001
`define	D0S_MEMH	3'b010
`define	D0S_DIFF	3'b011

`define	D0S_IMM		3'b100
`define	D0S_BITN	3'b101
`define	D0S_PCN		3'b111

`define	D0D_NOP		3'b000
`define	D0D_WAD		3'b001
`define	D0D_MEMH	3'b010
`define	D0D_SUB		3'b011
`define	D0D_RF		3'b100
`define	D0D_AND		3'b101
`define	D0D_OR		3'b110
`define	D0D_XOR		3'b111


`define	D1S_COM		3'b000
`define	D1S_RF		3'b001
`define	D1S_MEML	3'b010
`define	D1S_INC		3'b011

`define	D1S_IMM		3'b100

`define	D1D_NOP		3'b000
`define	D1D_RAD		3'b001
`define	D1D_MEMH	3'b010
`define	D1D_INC		3'b011

`define	D1D_PC		4'b1000


`define	COM_NOP		3'b000
`define	COM_RF		3'b001
`define	COM_IMM		3'b010
`define	COM_PLO		3'b011
`define	COM_MEML	3'b100
`define	COM_INC		3'b101
`define	COM_DIFF	3'b110
`define	COM_BITS	3'b111



// C:
// memcpy(void* dst, void* src, int n)
// {
//	for (i=n-1; i>=0; i--)
//		dst[i]	= src[i];
// }
//
// TTA:
// Conventions:
//	r7	- LR
//	r6	- SP
//	-1(sp)	- ret. addr.
//	-2(sp)	- `n'
//	-3(sp)	- `src*'
//	-4(sp)	- `dst*'
//	
// .proc memcpy
// memcpy:
//	{r6->sub, #2}
//	{r6->sub, #3}
//	{dif->rad,}
//	{#0->sub, mem}
//	{dif->rad}
//	
//	
//	
//	
//	
//	
//	{r14->sub, #4}		; calc index of `n' in the stack
//	{r14->sub, #8}		; calc index of `src*'
//	{dif->rad,}		; read `n'
//	{#0->sub, mem}		; negate `n'
//	{dif->rad,}		; read `src*' from stack
//	{mem->r1,}		; store `src*'
//	{mem->sub, dif}		; calc `src*' - (-`n')
//	{r14->sub, #6}		; calc index of `dst*'
//	{dif->r3,}		; store ptr to block limit+1
//	{dif->rad,}		; read `dst*' from stack
//	{mem->r2,}		; store `dst*'
// loop:
//	{r1->sub, #-1}		; calc next `src*' value
//	{r1->rad,}		; read `*src'
//	{r3->xor, dif}		; compare `src*' to block limit+1
//	{r2->wad, mem}		; copy `*src' to `*dst'
//	{bz [r15],}		; return (via LR)
//	{dif->r1,}		; store next `*src'	(branch delay slot 1)
//	{r2->sub, #-1}		; calc next `dst*' val	(branch delay slot 2)
//	{bra loop,}
//	{dif->r2,}		; store next `*dst'	(branch delay slot 1)
//	{,}			;			(branch delay slot 2)
// .endproc
//
// RISC16:
// .proc memcpy
// memcpy:
//	lw	r1, -8(r14)	; base-pointer - 8
//	lw	r2, -6(r14)
//	lw	r3, -4(r14)
//	add	r3, r1
// loop:
//	lw	r0, [r1]	; 1 reg read, 1 reg write
//	inc	r1		; 1 reg read, 1 reg write	(ALU sub)
//	sw	[r2+], r0	; 2 reg reads, 1 reg write	(ALU sub)
//	cmp	r1, r3		; 2 reg reads			(ALU xor, sub)
//	jnz	loop
//	ret			; 2 reg reads, 1 reg write	(ALU sub)
// .endproc
//
