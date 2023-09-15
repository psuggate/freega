;----------------------------------------------------------------------------
; memcpy_dma - Optimised `memcpy' using the DMA to burst write data to the
;  SDRAM controller. There are five arguments, read seg+pointer, write seg+
; pointer, and number of words. The fifth value is TOS.
; This procedure does not check `n' until after the DMA is setup, or whether
; the DMA is currently in use (since this CPU has no interupts), i.e. it
; assumes that the programmer is not a moron.
;	r0	- src_ptr*
;	r1	- src_seg
;	r2	- dst_ptr*
;	r3	- dst_seg
;	[TOS]	- n
; Return value:	none
memcpy_dma:	; Setup the DMA controller.
		{		,		,		,1	}
		{		,		,com	->msr	,0x50	} ; DMA addy
		{		,-1	->sub	,		,\r14	} ; Start POP
		{3	->wad	,		,\r13	->mem	,	}
		{2	->wad	,		,\r3	->mem	,diff	}
		{com	->rad	,		,diff	->r14\	,	} ; Fetch for POP
		{1	->wad	,1	->sub	,\r2	->mem	,mem	} ; Clear masks
		{		,		,		,	}
		{		,		,diff	->r2\	,0	} ; Set read seg
		{		,		,com	->msr	,\r1	}
		{		,		,		,	}
		; Setup complete, now spam data at the DMA.
mcpy_l0:	{\r0	->rad	,-1	->sub	,		,\r0	} ; read+inc src*
		{		,1	->sub	,		,\r2	}
		{		,		,diff	->r0\	,mem	}
		{\r13	->wad	,		,com	->mem	,	}
		{mcpy_l0->jnb	,		,diff	->r2\	,	}
		{		,		,		,-128	}
		{3	->wad	,		,com	->mem	,	} ; start DMA write
		{		,		,		,	}
		{\r15	->bra	,		,		,	}
		{		,		,		,	} ; BDS
