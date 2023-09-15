#!/usr/bin/env python
############################################################################
#    Copyright (C) 2005 by patrick                                         #
#    patrick@Slappy                                                        #
#                                                                          #
#    This program is free software; you can redistribute it and#or modify  #
#    it under the terms of the GNU General Public License as published by  #
#    the Free Software Foundation; either version 2 of the License, or     #
#    (at your option) any later version.                                   #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program; if not, write to the                         #
#    Free Software Foundation, Inc.,                                       #
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################

import sys

def main(argv) :
	
	var_prefix = 'char_ram'
	
	if len(argv) == 6 :
		if argv[1] == '-p' :
			var_prefix = argv[2]
			del argv[1:3]
		
	if len(argv) == 4 :
		if argv[2] == '-v' :
			in_file = open(argv[1], 'r')
			out_file = open(argv[3], 'w')
			mode = 'verilog'
		elif argv[2] == '-vs' :
			in_file = open(argv[1], 'r')
			out_file = open(argv[3], 'w')
			mode = 'verilog_split'
		
	elif len(argv) < 3 :
		print "USAGE:"
		print "    textload text_file.txt verilog_file.v"
		sys.exit(1)
	
	elif argv[1] == '-r' :
		in_file = open(argv[2], 'r')
		mode = 'readback'
	else :
		in_file = open(argv[1], 'r')
		out_file = open(argv[2], 'w')
		mode = 'hexdump'
	# endif
	
	
	# 'readback' mode reads in a file that has been hexed, and turns it back into
	# text, this is then directed to stdout.
	if mode == 'readback' :
		readback(in_file)
		sys.exit(0)
		
	# endif ('readback' mode)
	
	
	count = 0
	col = 0
	line = in_file.readline()
	
	if mode == 'verilog' :
		hex_string = ''
		
		# Read in lines of a text file until we have read 1 full page of text
		while line != '' and count < 128 :
			
			for char in line :
				
				# Found a newline character code before 80 characters read, so pad with spaces
				if char == '\n' :
					while col < 80 :
						hex_string = byte2ascii(' ') + hex_string
						
						if len(hex_string) == 64 :
							hex_string = writeString(hex_string, out_file, mode, var_prefix, count)
							count = count + 1
							
							if count == 128 :
								in_file.close()
								out_file.close()
								sys.exit(0)
							# endif
							
						
						col += 1
					# endwhile
					
					col = 0
					
				else :
					hex_string = byte2ascii(char) + hex_string
					
					if len(hex_string) == 64 :
						hex_string = writeString(hex_string, out_file, mode, var_prefix, count)
						count = count + 1
						
						if count == 128 :
							in_file.close()
							out_file.close()
							sys.exit(0)
						# endif
						
					
					col += 1
					if col == 80 :
						col = 0
				# endif
				
			# endfor
			
			line = in_file.readline()
			
		# endwhile
		
	elif mode == 'verilog_split' :
		hex_string0 = ''
		hex_string1 = ''
		
		# Read in lines of a text file until we have read 1 full page of text
		while line != '' and count < 128 :
			
			for char in line :
				
				# Found a newline character code before 80 characters read, so pad with spaces
				if char == '\n' :
					while col < 80 :
						if even(col) :
							hex_string0 = byte2ascii(' ') + hex_string0
						else :
							hex_string1 = byte2ascii(' ') + hex_string1
						# endif
						
						if len(hex_string0) == 64 :
							hex_string0 = writeString(hex_string0, out_file, mode, var_prefix, count)
							
						if len(hex_string1) == 64 :
							hex_string1 = writeString(hex_string1, out_file, mode, var_prefix, count | 64)
							count = count + 1
							
							if count == 64 :
								in_file.close()
								out_file.close()
								sys.exit(0)
							# endif
							
						
						col += 1
					# endwhile
					
					col = 0
					
				else :
					if even(col) :
						hex_string0 = byte2ascii(char) + hex_string0
					else :
						hex_string1 = byte2ascii(char) + hex_string1
					# endif
					
					if len(hex_string0) == 64 :
						hex_string0 = writeString(hex_string0, out_file, mode, var_prefix, count)
						
					if len(hex_string1) == 64 :
						hex_string1 = writeString(hex_string1, out_file, mode, var_prefix, count | 64)
						count = count + 1
						
						if count == 64 :
							in_file.close()
							out_file.close()
							sys.exit(0)
						# endif
						
					
					col += 1
					if col == 80 :
						col = 0
				# endif
				
			# endfor
			
			line = in_file.readline()
			
		# endwhile
		
	# endif (mode)
	 
	in_file.close()
	out_file.close()
	
# end main


# Takes in a byte (char) and turns it into a hexidecimal string of
# format HH, where H is any char from '0' to '9' and 'A' to 'F'.
def byte2ascii(char) :
	
	hex_word = hex(ord(char))
	hex_word = hex_word.lstrip('0x')
	hex_word = hex_word.rjust(2)
	hex_word = hex_word.replace(' ', '0')
	
	return hex_word
	
# end hex2ascii


# Returns True if num is even
def even(num) :
	return num == num & (-2)
	
# end even


# When a string has length of 64 characters (256-bits), write it to a file
def writeString(hex_string, out_file, mode, prefix, count) :
	
	init_num_string = '.INIT_' + hex(count & 0x03F).lstrip('0x').rjust(2).replace(' ', '0').upper()
	out_string = chr(9) + 'defparam ' + prefix + str(count >> 6) + init_num_string
	out_string += " = 256'h" + hex_string + ";\n"
	
	if mode == 'verilog' or mode == 'verilog_split' :
		out_file.write(out_string)
	else :
		hex_string = hex_string.upper()
		for ii in range(56,-1,-8) :
			out_file.write(hex_string[ii:ii+8] + ' ')
	
	hex_string = ''
	
	return hex_string
	
# end writeString


# Reads a hex file, display it as ascii
def readback(in_file) :
	
	line = in_file.read(180)
	while len(line) == 180 :
		count = 0
		out_string = ''
		for char in line :
			if char != ' ' :
				char = char.upper()
				if char > 'F' : pass
				elif char < '0' : pass
				elif char > '9' and char < 'A' : pass
				elif even(count) :
					# even
					if char >= 'A' :
						num = ord(char) - 55
					else :
						num = ord(char) - 48
					count += 1
				else :
					# odd
					num <<= 4
					if char >= 'A' :
						num += ord(char) - 55
					else :
						num += ord(char) - 48
						
					out_string += chr(num)
					count += 1
					# sys.exit(1)
				# end
			# endif
		# endfor
		
		# 'out_string' is scrambled at this point because of endian issues
		fixed_string = ''
		for a in range(len(out_string)/4) :
			fixed_string += out_string[4*a+3] + out_string[4*a+2] + out_string[4*a+1] + out_string[4*a]
			
		print fixed_string
		
		line = in_file.read(180)
	# endwhile
	
# end readback


if __name__ == "__main__" :
	main(sys.argv)
