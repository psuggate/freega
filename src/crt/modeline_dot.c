/***************************************************************
*
* Modeline Tool 
*
* Andreas Bohne / 1998 / http://www.dkfz-heidelberg.de/spec/ 
*
* Use on your own risk.
*
* Input:  Resolution and DotClockFrequence
* Output: Modeline
*
* Example use:
* <modline> 640 480 35 
* (640x480 with a dotclock of 35 mhz)
*
* Distributed by GNU Public Licence (GPL) 
*/

#include<stdio.h>
#include<stdlib.h>

int
main( int argc, char** argv ){
	
	const	float	hfrontmin	= 0.50;
	const   float   hsyncmin	= 1.20;
	const   float   hbackmin	= 1.25;
	const   float   hblankmin	= 4.00;
	const   float   hsfmax		= 60.0;

	const   float   vfrontmin 	= 0.0;
	const   float   vsyncmin	= 45.0;
	const   float   vbackmin	= 500.0;
	const   float   vblankmin	= 600.0;
	const   float   vsfmax 		= 90.;

	float		hr,vr;
	float		dcf;
	float		rr,hsf,vtick;
	float		hfront,hsync,hblank,hfl,vfront,vsync,vback,vblank,vfl;
	

	sscanf(argv[1],"%f",&hr);
	sscanf(argv[2],"%f",&vr);
	sscanf(argv[3],"%f",&dcf);

	hfront = hfrontmin * dcf + hr;
	if( (int)(hfront) % 8 ) hfront = 8 * (1 + (float)((int)(hfront/8)));

	hsync = hsyncmin * dcf + hfront;
	if( (int)(hsync)%8) hsync = 8 * (1+ (float)((int)(hsync/8)));

	hblank = hblankmin * dcf;
	hfl = hr + hblank;
	if((int)(hfl)%8) hfl = 8 * (1+(float)((int)(hfl/8)));

	vtick = hfl / dcf;
	vfront = vr + vfrontmin / vtick;

	vsync = vfront + vsyncmin /vtick;
	vback = vbackmin /vtick;
	vblank = vblankmin / vtick;
	
	vfl = vsync + vback;
	if( vfl < vr+ vblank) vfl = vr + vblank;

	rr = 1000000.0 * dcf / (hfl * vfl);
	hsf = 1000.0 * dcf / hfl;

	printf("  Horizontal Resolution:  %4.0f \n",hr);
	printf("  Vertical Resolution:    %4.0f \n",vr);
	printf("  Dot Clock Frequence:    %4.2f MHz \n",dcf);
	printf("  Vertical Refresh Rate:  %4.2f Hz \n",rr);
	printf("  Horizontal Refresh Rate:%4.2f KHz \n",hsf);
	printf("\n");
	printf(" # V-freq: %4.2f Hz  // H-freq: %4.2f KHz\n Modeline \"%dx%d\" %4.2f  %4d %4d %4d %4d  %4d %4d %4d %4d \n",rr,hsf,(int)(hr),(int)(vr),(dcf),(int)(hr),(int)(hfront),(int)(hsync),(int)(hfl),(int)(vr),(int)(vfront),(int)(vsync),(int)(vfl));
	
	exit(0);
}
	
	 
	
	
	
		
