#!/usr/bin/env python
############################################################################
#                                                                          #
#    bin2v - Converts ROM images into verilog files that can be loaded     #
#      into Xilinx on-chip RAM blocks.                                     #
#                                                                          #
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
	
	# lookup table of hex nibbles
	hex_lut = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f']
	
	if len(argv) != 3 :
		print "USAGE:"
		print "    bin2v rom_file.bin rom_file.v"
		
	in_file = open(argv[1], 'r')
	out_file = open(argv[2], 'w')
	
	# upto 32 bytes (256 bits) per line
	bytes = in_file.read(32)
	count = 0
	while bytes != '' :
		
		hex_string = ''
		for byte in bytes :
			hi_nibble = ord(byte) >> 4
			lo_nibble = ord(byte) & 0x0F
			
			hex_string = hex_lut[hi_nibble] + hex_lut[lo_nibble] + hex_string
			
		hex_string = hex_string.rjust(64).replace(' ', '0')
		writeString(hex_string, out_file, 'verilog', 'vgabios', count)
		
		bytes = in_file.read(32)
		count += 1
	# endwhile
	
	in_file.close()
	out_file.close()
	
	sys.exit(0)
	
# end main


# When a string has length of 64 characters (256-bits), write it to a file
# Options:
#  - hex_string: a string of data 64 characters long
#  - out_file:   a file handle of the file to write to
#  - mode:       either 'verilog' or 'verilogsplit' if the file is to be in
#                verilog mode. 'verilogsplit' allows the data to span 2 ram
#                blocks. The default mode is a plain ascii if no verilog
#                mode is specified
#  - prefix:     the name of the instantiated verilog ram block
#  - count:      the line number
#
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


if __name__ == "__main__" :
	main(sys.argv)
