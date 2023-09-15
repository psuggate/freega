#!/usr/bin/env python
import	sys

#def dump(dat):
	#for 

def main(argv):
	if len(argv) < 2:
		print "USAGE:  dump.py <device> [range]"
		sys.exit(1)
	
	try:
		fh	= open(argv[1], "r")
	except:
		print "ERROR: Invalid device or permissions! ("+argv[1]+")"
		sys.exit(2)
	
	dat	= fh.read(256)
	#dump(dat)
	fh.close()

if __name__ == "__main__":
	main(sys.argv)
