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
	
	for ii in range(16) :
		for jj in range(16) :
			sys.stdout.write(str(ii*16+jj) + chr(ii*16+jj) + ' ')
		# endfor
		print
	# endfor
		
	
# end main


if __name__ == "__main__" :
	main(sys.argv)
