#!/usr/bin/env python
import sys

def	main () :
	in_string = sys.stdin.readline ()
	while (in_string != "") :
		if (in_string.find ("!") == -1) :
			sys.stdout.write (in_string)
		in_string = sys.stdin.readline ()
	#endwhile
#end main

if __name__ == "__main__" :
	main ()
