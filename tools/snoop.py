#!/usr/bin/env python

import	sys
import	struct

def main(argv):
	try:
		fh	= open("/dev/freega", "r")
	except:
		print	"Cannot open FreeGA, opening /dev/zero"
		fh	= open("/dev/zero", "r")
	
	if len(argv) > 1:
		spos	= int(argv[1], 16)
		fh.seek(spos)
	
	epos	= 0
	if len(argv) > 2:
		epos	= int(argv[2], 16)
	
	if epos > 0:
		dlen	= epos - spos
	else:
		dlen	= 8
	
	for i in range(dlen):
		etime	= float(struct.unpack("<I", fh.read(4))[0])/50e6
		v	= struct.unpack("<I", fh.read(4))[0]
		port	= v & 1023
		if (v & (1<<20)):
			tdir	= 'w'
		else:
			tdir	= 'r'
		
		mask	= (v >> 16) & 15
		pdat	= struct.unpack("<I", fh.read(4))[0]
		print	"%8f: (%s)0%03xh\tData = (%01x:%08x)" % (etime, tdir, port, mask, pdat)
		#print "%08x" % struct.unpack("<i", fh.read(4))[0]
		#print	hex(struct.unpack("<i", fh.read(4))[0])
		struct.unpack("<I", fh.read(4))[0]

if __name__ == "__main__":
	main(sys.argv)
