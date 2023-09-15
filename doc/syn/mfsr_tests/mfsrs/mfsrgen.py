#!/usr/bin/env python
# -*- coding: utf-8 -*-

import	sys

def genMFSR (bits, taps):
	'''Inputs
		taps - a list of tuples. First in tuple is  destination bit,
			second is the the other input to the XOR gate (first
			input being the (destination-1) bit. The bits range
			from 1...n, vs. 0...(n-1).
	'''
	mfsr	= range(bits-1, 0, -1)
	mfsr.append(bits)
	for tap in taps:
		mfsr[bits-tap[0]]	= (mfsr[bits-tap[0]], tap[1])
	return	mfsr

def MFSR2str (mfsr, prfx):
	# Convert to txt
	
	if prfx.endswith('_i'):
		o_prfx	= prfx[0:-1]+'o'
	else:
		o_prfx	= prfx+'_w'
	
	# TODO: Gather and terminate string properly.
	mlen	= len(mfsr)
	m_str	= 'assign	#1 '+o_prfx+'	= {'
	
	# Three possibilities:
	#  - Consecutive list of numbers, counting down
	#  - A tuple
	#  - The terminating number (the number of bits)
	gather	= []
	for bit in mfsr:
		if type(bit) == tuple:
			gstr, gather	= bit_range(gather, prfx)
			m_str	+= gstr+prfx+'['+str(bit[0]-1)+']^'+prfx+'['+str(bit[1]-1)+'], '
		elif bit==mlen:
			gstr, gather	= bit_range(gather, prfx)
			m_str	+= gstr+prfx+'['+str(bit-1)+']};\n'
		else:
			gather.append(bit-1)
	
	return	m_str
#end MFSR2str	

license	= '''/***************************************************************************
 *                                                                         *
 *   MFSRXX.v - One of Roy Ward's ultra tricky Multiple Feed-back Shift    *
 *     Registers (MFSR). This one is XX-bits wide.                         *
 *                                                                         *
 *   Copyright (C) 2009 by Patrick Suggate and Roy Ward                    *
 *   patrick@physics.otago.ac.nz                                           *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/
'''

vmodule	= '''
`timescale 1ns/100ps
module	MFSRXX (
	input	[MSB:0]	PRFX_i,
	output	[MSB:0]	PRFX_o
);

MFSR_STRING
	
endmodule	// MFSRXX
'''

def gen_module(bits, mfsr, prfx):
	mfsr_name	= 'mfsr'+str(bits)
	msb_str		= str(bits-1)
	
	outstr	= license.replace('MFSRXX', mfsr_name) + vmodule.replace('MFSRXX', mfsr_name)
	outstr	= outstr.replace('MSB', msb_str)
	outstr	= outstr.replace('PRFX', prfx)
	outstr	= outstr.replace('MFSR_STRING', mfsr)
	return	outstr
# end write_module


def bit_range(gather, prfx):
	if not len(gather):
		gstr	= ''
	elif len(gather)==1:
		gstr	= prfx+'['+str(gather[0])+'], '
	else:
		gstr	= prfx+'['+str(gather[0])+':'+str(gather[-1])+'], '
	return	gstr, []
# end bit_range


if __name__ == "__main__":
	print "MFSR generator, Copyright 2009 Patrick Suggate (C)"
	
	args	= open(sys.argv[1], 'r').readlines()
	prfx	= 'count'
	for a in args:
		bits	= int(a.split()[0])
		taps	= eval(a.split()[1])
		mfsr	= genMFSR(bits, taps)
		mfsr	= MFSR2str(mfsr, prfx+'_i')
		fh	= open('mfsr'+str(bits)+'.v', 'w')
		fh.write(gen_module(bits, mfsr, prfx))
		fh.close()
