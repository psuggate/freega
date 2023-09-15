;----------------------------------------------------------------------------
; set_leds - The two LSBs of `r0' determines the LED outputs.
set_leds:	{		,		,		,1	} ; 1
		; Set segment to the memory-mapped LEDs.
		{		,		,com	->msr	,0x48	} ; 2
		{\r0	->wad	,		,\r0	->mem	,1	} ; 3
		 ; Restore SS and return.
		{\r15	->bra	,		,com	->msr	,\r12	} ; 4
		{		,		,		,	} ; 5
