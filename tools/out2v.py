#!/usr/bin/env python

# Takes in a `.out' file produced by Roy's assember and produces a `.v' file
# which contains assignments to a 32-bit memory called `mem'. The produced
# file is supposed to be "`include"d inside an initial block to set the
# contents of program memory upon startup.

import	sys

instr	= sys.stdin.readline()
while (instr) :
	strlist	= instr.strip("\n").split(":")
	linenum	= int (strlist[0], 16)
	
	outstr	= "\tmem["+str(linenum)+"]\t<= 'h"+strlist[1]+";\n"
	sys.stdout.write(outstr)
	
	instr	= sys.stdin.readline()
