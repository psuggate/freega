;----------------------------------------------------------------------------
; memcpy_dma - Optimised `memcpy' using the DMA to burst write data to the
;  SDRAM controller. There are five arguments, read seg+pointer, write seg+
; pointer, and number of words. The fifth value is TOS.
;	r0	- src_ptr*
;	r1	- src_seg
;	r2	- dst_ptr*
;	r3	- dst_seg
;	[TOS]	- n
; Return value:	none
DMA_start:	equ	0x0080
memcpy_dma:	; Setup the DMA controller.
		sw.s	[r14], r4		; PUSH r4, reg needed
		i12	-DMA_SEG>>4
		subi	r4, r13, -DMA_SEG
		nop				; No bypassing on
		nop				; MSR (the `dat' path)
		msr.d	r4			; Set output seg to DMA
		sw.d	[r13+1], r2		; Setup DMA, lo-word of addr
		sw.d	[r13+2], r3		; hi-word of addr
		sw.d	[r13+3], r13		; clear bit-masks
		lw.s	[r14-1], r2		; Get `n' from stack
		msr.s	r1			; Set src seg
mcpy_l0:	lw.s	[r0], r3
		decc	r2
		inc	r0			; Don't modify flags
		sw.d	[r13+0], r3		; Write to DMA
		jnz	mcpy_l0
		
		i12	-DMA_start>>4
		subi	r3, r13, -DMA_start
		msr.s	r12			; Restore SS and POP r4
		lw.s	[r14], r4		; While `r3' writes back
		sw.d	[r13+3], r3		; Start DMA xfer
		
		ret
