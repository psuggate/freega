;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                          ;
;    vgabios.s - Minimal VGA Bios implementation. Contains the bare        ;
;      minimum to boot FreeDOS. Assemble with NASM.                        ;
;                                                                          ;
;    Copyright (C) 2005 by Patrick Suggate                                 ;
;    patrick@physics.otago.ac.nz                                           ;
;                                                                          ;
;    This program is free software; you can redistribute it and/or modify  ;
;    it under the terms of the GNU General Public License as published by  ;
;    the Free Software Foundation; either version 2 of the License, or     ;
;    (at your option) any later version.                                   ;
;                                                                          ;
;    This program is distributed in the hope that it will be useful,       ;
;    but WITHOUT ANY WARRANTY; without even the implied warranty of        ;
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         ;
;    GNU General Public License for more details.                          ;
;                                                                          ;
;    You should have received a copy of the GNU General Public License     ;
;    along with this program; if not, write to the                         ;
;    Free Software Foundation, Inc.,                                       ;
;    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%define	TEXT_MODE	0x03

%define	BDA_SEG		0x40

%define	BDA_EQUIP		0x10	; 1 word
%define	BDA_EQUIP_MASK	0xFFCF

%define	BDA_VID_MODE	0x49	; 1 byte
%define	BDA_NUM_COLS	0x4A	; 1 word
%define	BDA_PAGE_SIZE	0x4C	; 1 word
%define	BDA_PAGE_START	0x4E	; 1 word
%define	BDA_CURSOR_POS	0x50	; 8 words
%define	BDA_CURS_START	0x60	; 1 byte
%define	BDA_CURS_END	0x61	; 1 byte
%define	BDA_PAGE_NUM	0x62	; 1 byte
%define	BDA_PORT_ADDR	0x63	; 1 word
%define	BDA_CURRENT_MSR	0x65	; 1 byte

%define	BDA_NUM_ROWS	0x84	; 1 byte (less 1, ie 24)
%define	BDA_CHAR_HEIGHT	0x85	; 1 byte?
%define	BDA_VIDEO_CTL	0x87	; 1 byte
%define	BDA_SWITCHES	0x88	; 1 byte
%define	BDA_MODESET_CTL	0x89	; 1 byte

segment .text

org 0

bits 16

%macro SET_INT_VECTOR 3
  push ds
  xor ax, ax
  mov ds, ax
  mov ax, %3
  mov [%1*4], ax
  mov ax, %2
  mov [%1*4+2], ax
  pop ds
%endmacro

vgabios_start:
db	0x55, 0xaa	; BIOS signature, required for BIOS extensions
db	0x40		; BIOS extension length in units of 512 bytes

vgabios_entry_point:
  jmp vgabios_init_func
  
init_text:	db	"Spartacus VGA Bios", 0x0a, 0x0d, 0x00

vgabios_init_func:
  push	ax
  push	cx
  push	si
  push	di
  push	ds
  push	es
  
  push	cs	; Display loading message
  pop	ds
  mov	ax, 0xB800	; Text mode area
  mov	es, ax
  mov	si, init_text
  xor	di, di
  mov	cx, 9
  rep	movsw
  
  call	init_bios_area
  
  ; Deliberately crash, so hopefully, the boot message displays
infinite_loop:
  jmp	infinite_loop
  
  cli
  SET_INT_VECTOR 0x10, 0xC000, vgabios_int10_handler
  sti
  
  pop	es
  pop	ds
  pop	di
  pop	si
  pop	cx
  pop	ax
  retf
  
  
; The BIOS Data Area (BDA) stores information about the curent
; video mode, like number of columns, cursor locations, etc.
init_bios_area:
  push	es
  push	di
  
  ; Setup the BIOS Data Area
  mov	ax, BDA_SEG
  mov	es, ax
  
  ; Set the equipment flags
  mov	di, BDA_EQUIP
  mov	ax, [es:di]
  and	ax, BDA_EQUIP_MASK
  stosw
  
  ; Store current mode (text)
  mov	di, BDA_VID_MODE
  mov	al, 0x03
  stosb			; 40:49
  
  ; Store number of columns, 80
  mov	ax, 0x50
  stosw			; 40:4A
  
  ; Store page size
  mov	ax, 4000
  stosw			; 40:4C
  
  ; Store page position + 8x cursor positions
  xor	ax, ax
  mov	cx, 9
  rep	stosw	; 40:4E & 40:50
  
  ; Store cursor start scan line
  mov	al, 0x14
  stosb			; 40:60
  
  ; Store cursor stop scan line
  mov	al, 0x15
  stosb			; 40:61
  
  ; Store current page number
  xor	al, al
  stosb			; 40:62
  
  ; Store VGA CRTC port address
  mov	ax, 0x3d4
  stosw			; 40:63
  
  ; Store CRTC mode control register
  mov	al, 0x09
  stosb			; 40:65
  
  ; Store number of row in current mode
  mov	di, BDA_NUM_ROWS
  mov	al, 0x18
  stosb			; 40:84
  
  ; Store text character height
  mov	ax, 0x10
  stosb			; 40:85
  
  ; Store VGA options (256kB memory)
  mov	di, BDA_VIDEO_CTL
  mov	al, 0x60
  stosb			; 40:87
  
  ; Store VGA feature switches
  mov	al, 0xF9
  stosb			; 40:88
  
  pop	di
  pop	es
  ret
  
  
; This is how user applications are supposed to talk to the video
; adapter, by calling INT 010h with AL set to the command.
vgabios_int10_handler:
  iret
  
video_bios_end:
db	"Video BIOS ends here.", 0x0a, 0x0d, 0x00
db	0xCB	; Copied from another VGA, is it needed?
