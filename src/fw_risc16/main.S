architecture:risc16
;dnl	# Use the m4 macro preprocessor on this file.
;define(`CRTC_SEG',`0x0100')dnl
;define(`SPROM_SEG',`0x0108')dnl
;define(`LEDS_SEG',`0x0110')dnl
;define(`FLUSH_SEG',`0x01C0')dnl
;define(`DMA_SEG',`0x0180')dnl
;define(`u12',`eval($1/16)')dnl
;define(`l4',`eval($1&0x0f)')dnl
;define(`nu12',`eval(-$1/16)')dnl
;define(`nl4',`eval(-$1&0x0f)')dnl
define(`SETDS',`	{i12	u12($1)}dnl
	{msr	r13,l4($1),r13}')dnl
define(`SETSS',`	{i12	u12($1)}dnl
	{msrs	r13,l4($1),r13}')dnl

	{}
__reset_address:
	; Initialise FreeGA
	{}
	
poll_and_redraw:
;	{i12	u12(init)}
	{brl	r15,init,r13}
	{test	r13, 0}
	{jz	poll_and_redraw}
	{}
	
; Flush the cache and DMA and then set the CRTC and framebuffer address to
; defaults.
flush_cache:
	SETDS(FLUSH_SEG)	; Issue 16 writes to the cache flush device
	{i12	nu12(0x0200)}	; Addresses 0x0000-0x01e0 need to be written
	{sub	r0,r13,nl4(0x0200)}	; to.
flush_loop0:
	{i12	u12(0x0020)}
	{sub	r0,r0,l4(0x0020)}
	{sw	[r0,0],r13}	; Can write anything really
	{jnz	flush_loop0}
	
	{br	r15}		; Return
