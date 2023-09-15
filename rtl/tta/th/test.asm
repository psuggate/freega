; Architecture can be preceded by comments.
architecture:th

; 	{,,}
; 	{,,10->com}
; 	{20->mul,,}
; 	{,,}
; 	{plo->mul,,}
; 	{,,}
; loop:	{,bra loop,}
; 	{,,}
; 	{,,}
; 


/*	{u,,,}
	{u,30->wad,,}
	{u,,,}
	{u,20->memh,20->meml,}
	{u,,,}
	{u,,,}
	{u,,,}
	{u,,30->rad,}
	{u,,,}
	{u,,,}
	{u,memh->xor,,meml->com}
;	{u,memh->xor,,meml->com}*/
	{u,,,}
loop:	{u,,bra loop,}
	{u,,,}
	{u,,,}

/*
	{,,}
loop:	{,583->r1,}
	{,,}
	{,,}
	{r1->xor,,341->com}
	{,,}
	{,,}
	{bits->mul,,16->com}
	{,,1->com}
	{,,2->com}
	{,bra loop2,}
	{,,3->com}
	{,,4->com}
	{bits->mul,,32->com}
	{,,5->com}
	{,,6->com}
	{bits->mul,,64->com}
	{,,7->com}
	{,,8->com}
loop2:	{bits->mul,,128->com}
	{,,9->com}
	{,,10->com}
	{,bra loop,}
	{,,11->com}
	{,,12->com}
*/
