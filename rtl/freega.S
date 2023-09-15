; Architecture can be preceded by comments.
architecture:vgatta

/***** This comment is legal. *****/
; TODO .org	0x10

; 16 NOPs since the PC starts at 0x0010
.space	16
.align	16
loop:	{,4->cri,,}	; Set the memory address register
;loop:	{,2->cri,,}	; Set the page address register
	{,11->crd,,}	; Write a memory address
arch:
	{3->dmux,,,}	; Prepare for a shift left by 3
	{,,,}
	{7->mul,,dmux->com,}	/* Perform a shift */
	{,,,}
	{,,plo->com,}
_h1py:
;	{,,,}
	{,,,com->r2}
/*	{,,,com->r2}
	*/
	{,bz end,,}	; Do it all again
;	{,bnz loop,,pc->r15}
	{,bz loop,,pc->r15}
	{,7->mov,,pc->r15}
	{,9->mov,,}
end:
	{,,,}

loop2:	{,4->cri,,}	; Set the memory address register
	{,11->crd,,}	; Write a memory address
	
	{3->dmux,,,}	; Prepare for a shift left by 3
	{,,,}
	{7->mul,,dmux->com,}
	{,,,}
	{,,plo->com,}
;	{,,,}
	{,,,com->r2}
	
	{,bz end,,}	; Do it all again
	{,bnz loop,,pc->r15}
	{,7->mov,,pc->r15}
	{,9->mov,,}
end2:
	{,,,}
;	{ 11 -> crd , , , }
;	{ com -> crd , , , alu0 -> r1 }
;	{ com -> crd , , , }
;	{ r1 -> crd , 4 -> cri , r1 -> com , com -> r0 }
;	{ com -> and , 0 -> cri , , com -> r0 }
;	{ com -> and , bra loop, , }
;	{ ,,, }


/*
; Since the VGA's TTA is primarily an I/O processor, the task is to take I/O
; port addresses and data and use it to alter FreeGA's state.
;
; The first step is to poll the I/O address FIFOs (one for read and one for
; writes). If a I/O read request occurs, branch to the appropriate handler.
; If an I/O write occurs, read the data from the I/O write data FIFO and then
; branch to the appropriate handler.
;
; This is pseudo-code.
start:		{0x04	-> r3}	; Memory flag mask
		{0x01	-> cri}	; Flags index
		
poll_loop:	{0x00	-> addr}
		{mem	-> r0}	; Try to read the I/O read address FIFO
		{r3	-> com, crd	-> and}
		{nop}		; Wait for the zero flag
		{jnz	read_handler}
		{nop}
		{nop}
		{0x01	->addr}
		{mem	-> com} ; Then try the I/O write address FIFO
		{jnm	poll_loop}
		{nop}
		{nop}
		
; This is the I/O write handler.
		{0x02	->addr}
		{mem	->r1}	; Read the data sent
		{0x3f	->and}	; Calculate the a branch address based on the
		{-addr_3c0->sub, bits->com}	; I/O address (base+off).
		{diff	->pc}	; Branch
		{nop}
		{nop}
		
; All the VGA data is stored in a RAM block except for the VGA status
; register since it has constantly changing data.
read_handler:	
		{bra	poll_loop}	; TODO
		{nop}
		{nop}

; EGA/VGA I/O ports.
addr_3c0:	{bra attr}
addr_3c1:	{bra attr_other}
addr_3c2:	{bra vga_status}
addr_3c3:	{bra vga_en}
addr_3c4:	{bra seq_index}
addr_3c5:	{bra seq_data}
addr_3c6:	{bra dac_mask}
addr_3c7:	{bra dac_state}
addr_3c8:	{bra dac_index}
addr_3c9:	{bra dac_data}
addr_3ca:	{bra vga_pos0}
addr_3cb:	{bra undefined}
addr_3cc:	{bra vga_pos1}
addr_3cd:	{bra vga_feat}
addr_3ce:	{bra gfx_index}
addr_3cf:	{bra vga_other}

addr_3d0:	{bra crtc_index}	; CRTC index
addr_3d1:	{bra crtc_data}		; CRTC data
addr_3d2:	{bra crtc_index}
addr_3d3:	{bra crtc_data}
addr_3d4:	{bra crtc_index}
addr_3d5:	{bra crtc_data}
addr_3d6:	{bra crtc_index}
addr_3d7:	{bra crtc_data}		; These are the same as above
addr_3d8:	{bra crtc_mode}
addr_3d9:	{bra crtc_palsel}
addr_3da:	{bra crtc_status}
addr_3db:	{bra lightpen_clr}
addr_3dc:	{bra lightpen_pre}
addr_3cd:	{bra undefined}
addr_3ce:	{bra undefined}
addr_3cf:	{bra undefined}

addr_3a0:	{bra undefined}		; These should never get called
addr_3a1:	{bra undefined}
addr_3a2:	{bra undefined}
addr_3a3:	{bra undefined}
addr_3a4:	{bra undefined}
addr_3a5:	{bra undefined}
addr_3a6:	{bra undefined}
addr_3a7:	{bra undefined}
addr_3a8:	{bra undefined}
addr_3a9:	{bra undefined}
addr_3aa:	{bra undefined}
addr_3ab:	{bra undefined}
addr_3ac:	{bra undefined}
addr_3ad:	{bra undefined}
addr_3ae:	{bra undefined}
addr_3af:	{bra undefined}

; Monochrome ports (MDA, Hercules)
addr_3b0:	{bra crtc_index}	; CRTC index
addr_3b1:	{bra crtc_data}		; CRTC data
addr_3b2:	{bra crtc_index}
addr_3b3:	{bra crtc_data}
addr_3b4:	{bra crtc_index}
addr_3b5:	{bra crtc_data}
addr_3b6:	{bra crtc_index}
addr_3b7:	{bra crtc_data}		; These are the same as above
addr_3b8:	{bra crtc_mode}
addr_3b9:	{bra crtc_clrsel}
addr_3ba:	{bra crtc_status}
addr_3bb:	{bra crtc_strb}
addr_3bc:	{bra undefined}
addr_3bd:	{bra undefined}
addr_3be:	{bra undefined}
addr_3bf:	{bra undefined}

undefined:	{bra start}

*/
