#!/usr/bin/env python
import	sys

# Parse flags.
in_comment	= 0
arch_read	= 0

# Read in an assembly file.
def parse_file (in_file) :
	aline	= sys.stdin.readline()
	while (aline) :
		aline	= sys.stdin.readline()
		
		# Extract a label/arch if present.
		if (aline.find(':') != -1) :
			[label, rest]	= aline.split(':')
		else :
			label	= ''
		
		if !arch_read and label != 'architecture' and label != '' :
			print "ERROR: Label before architecture."
			sys.exit(1)
	
#end parse_file

