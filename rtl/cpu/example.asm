; This is some example assembly for processing an I/O request.

; The VGA I/O processor needs to respond to port reads, and needs to change
; the VGA's state on port writes.

; Pseudocode:
;	while (1)
;		if (idx = port_read ())
;			port_read_handlers (idx)
;		elif (idx = port_write ())
;			port_write_handlers (idx)
;	
;	port_read_handlers (i)
;		goto	handler (i)
;	read_done:
;		return
;	
;	port_write_handlers (i)
;		goto	handler (i)
;	read_done:
;		return
;	
;	port0:
;		

; IRQ or Poll?
io_irq:
	{ io -> a0,	taboffset -> a1,	,			}
	{	,	sum -> mema,		,			}
	{	,		,	memd -> pc,			}
	
	
port_3c0:
	{

; RISC equiv.
	add	r1, taboffset, r0
	load	r2, [r1]
	mov	pc, r2
	