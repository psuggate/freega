#!/usr/bin/env python
############################################################################
#    Copyright (C) 2005 by Patrick Suggate                                 #
#    patrick@physics.otago.ac.nz                                           #
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
import os
from wxPython.wx import *


# Global Defines
CYCLE_WIDTH		= 40
CYCLE_HEIGHT	= 20
CYCLE_DELTA		= 0
DATA_DELTA		= 2

wxDARK_GREEN	= wxColour(0, 64, 0)

# A frame where the timing diagrams are plotted
class TimingDiagramFrame(wxFrame) :
	
	def __init__(self, parent, id, title, plotLabels, plotData) :
		"""
		Re-inventing the wheel
		"""
		
		wxFrame.__init__(self, parent, id, title, style=wxDEFAULT_FRAME_STYLE)
		
		self.labels = plotLabels
		self.data = plotData
		self.period = calcClockPeriod(self.data)
		self.maxTime = int(plotData[0][len(plotData[0])-1])
		
		self.pageWidth = int((self.maxTime / self.period + 4) * CYCLE_WIDTH)
		self.pageHeight = int((len(plotLabels) - 1) * CYCLE_HEIGHT * 2) + CYCLE_HEIGHT
		
		# self.topPanel = wxPanel(self, -1, style=wxSIMPLE_BORDER)
		self.drawPanel = wxScrolledWindow(self, -1, style=wxSUNKEN_BORDER)
		self.drawPanel.SetBackgroundColour(wxBLACK)
		self.drawPanel.EnableScrolling(True, True)
		self.drawPanel.SetScrollbars(20, 20, int(self.pageWidth / 20), int(self.pageHeight / 20))
		
		EVT_PAINT(self.drawPanel, self.onPaintEvent)
		
		self.penColour  = wxGREEN
		self.lineSize   = 1
		
		self.signals = []
		for count in range(1, len(self.data)) :
			if isData(self.data[count]) :
				self.signals.append(DataSignal(self.labels[count], self.data[count], self.data[0], self.period))
			else :
				self.signals.append(Signal(self.labels[count], self.data[count], self.data[0], self.period))
			# endif
		# endfor
		
		self.SetSizeHints(minW=200, minH=60)
		self.SetSize(wxSize(self.pageWidth + 40, self.pageHeight + 40))
		
	# end __init__
	
	# Paint the graph
	def onPaintEvent(self, event):
		""" Respond to a request to redraw the contents of our drawing panel.
		"""
		
		dc = wxPaintDC(self.drawPanel)
		self.drawPanel.PrepareDC(dc)
		dc.BeginDrawing()
		
		# Draw dark vertical lines
		dc.SetPen(wxPen(wxDARK_GREEN, 1, wxSOLID))
		dc.SetBrush(wxBrush(wxDARK_GREEN, wxSOLID))
		
		for col in range(int(CYCLE_WIDTH * 4), self.pageWidth, CYCLE_WIDTH) :
			dc.DrawLine(col, 0, col, self.pageHeight)
		# endfor
		
		#Some horizontal ones too
		for row in range(int(CYCLE_HEIGHT*2), self.pageHeight, int(CYCLE_HEIGHT*2)) :
			dc.DrawLine(int(CYCLE_WIDTH*3), row, self.pageWidth, row)
		# endfor
		
		atPos = wxPoint(CYCLE_WIDTH * 3, CYCLE_HEIGHT)
		for signal in self.signals :
			signal.draw(dc, atPos)
			atPos.y += int(CYCLE_HEIGHT * 2)
		# endfor
		
		# Line to seperate signals from labels
		dc.DrawLine(int(3 * CYCLE_WIDTH), 0, int(3 * CYCLE_WIDTH), self.pageHeight)
		
		# Draw markers showing signal level
		atPos.x -= 1
		for count in range(len(self.signals)) :
			atPos.y = int(CYCLE_HEIGHT * (1.5 + 2.0 * count))
			dc.DrawLine(atPos.x - 4, atPos.y, atPos.x, atPos.y)
		# endfor
		
		dc.EndDrawing()
		
	# end onPaintEvent
	
# endclass plot


# Scans a signal stream to determine whether it is a data or a signal
def isData(stream) :
	for item in stream :
		if item == '1' or item == '0' or item == 'z' or item == 'x' : pass
		else :
			return True
		# endif
	# endfor
	return False
# end isData


# Scans a string to see if it is a number (including hex)
def isNumber(dataString) :
	for char in dataString :
		if char < '0' :
			return False
		elif char > 'f' :
			return False
		elif char > '9' and char < 'A' :
			return False
		elif char > 'F' and char < 'a' :
			return False
	# endif
	return True
# end isNumber


class Signal :
	"""
	Timing diagram is made from multiple signals.
	Each signal can have the values:
		1	- Signal is HI
		0	- Signal is LO
		z	- Signal is HI-Z state
		x	- Signal is undefined
		X	- Signal is being driven by more than 1 device (BAD!)
	"""
	
	def __init__(self, dataLabel, dataStream, timeStream, period, signalColour=wxGREEN, signalWidth=1) :
		self.penColour = signalColour
		self.penWidth = signalWidth
		self.label = dataLabel
		
		self.stream = []
		prevValue = dataStream[0]
		adjFactor = float(CYCLE_WIDTH) / float(period)
		for count in range(len(dataStream)) :
			value = dataStream[count]
			atTime = float(timeStream[count])
			xPos = int(atTime * adjFactor)
			if value == 'z' :
				if prevValue == '1' :
					self.stream.append(wxPoint(xPos - CYCLE_DELTA, 0))
				elif prevValue == '0' :
					self.stream.append(wxPoint(xPos - CYCLE_DELTA, CYCLE_HEIGHT))
				# endif
				self.stream.append(wxPoint(xPos, CYCLE_HEIGHT/2))
			elif value == '0' :
				if prevValue == '1' :
					self.stream.append(wxPoint(xPos - CYCLE_DELTA, 0))
					self.stream.append(wxPoint(xPos + CYCLE_DELTA, CYCLE_HEIGHT))
				elif prevValue == '0' :
					self.stream.append(wxPoint(xPos, CYCLE_HEIGHT))
				else :
					self.stream.append(wxPoint(xPos, CYCLE_HEIGHT/2))
					self.stream.append(wxPoint(xPos + CYCLE_DELTA, CYCLE_HEIGHT))
				# endif
			elif value == '1' :
				if prevValue == '0' :
					self.stream.append(wxPoint(xPos - CYCLE_DELTA, CYCLE_HEIGHT))
					self.stream.append(wxPoint(xPos + CYCLE_DELTA, 0))
				elif prevValue == '1' :
					self.stream.append(wxPoint(xPos, 0))
				else : # prevValue == 'z' :
					self.stream.append(wxPoint(xPos, CYCLE_HEIGHT/2))
					self.stream.append(wxPoint(xPos + CYCLE_DELTA, 0))
				# endif
			else :
				if prevValue == '0' :
					self.stream.append(wxPoint(xPos - CYCLE_DELTA, CYCLE_HEIGHT))
				elif prevValue == '1' :
					self.stream.append(wxPoint(xPos - CYCLE_DELTA, 0))
				# endif
				offset = 2
				for count in range(1, 11) :
					self.stream.append(wxPoint(xPos + CYCLE_DELTA * count, CYCLE_HEIGHT/2 + offset))
					offset = ~offset + 1
				# endfor
			# endif
			prevValue = value
		# endfor
		
	# end __init__
	
	def draw(self, dc, atPos) :
		""" Draw 'Signal' to the diagram
			'dc' is the device context to use for drawing.
		"""
		
		dc.SetPen(wxPen(self.penColour, self.penWidth, wxSOLID))
		dc.SetBrush(wxBrush(self.penColour, wxSOLID))
		dc.SetTextBackground(wxBLACK)
		dc.SetTextForeground(self.penColour)
		
		lastPos = self.stream[0]
		for curPos in self.stream[1:] :
			dc.DrawLine(atPos.x + lastPos.x,
						atPos.y + lastPos.y,
						atPos.x + curPos.x,
						atPos.y + curPos.y)
			lastPos = curPos
		# endfor
		dc.DrawText(self.label, 20, atPos.y + 2)
	# end draw
	
# endclass signal


class DataSignal(Signal) :
	"""
		A data signal shows a transition when the data changes
	"""
	def __init__(self, dataLabel, dataStream, timeStream, period, signalColour=wxGREEN, fontColour=wxBLUE, signalWidth=1) :
		# does __init__ need to be redeclared?
		#Signal.__init__(self, dataLabel, dataStream, timeStream, period, signalColour, signalWidth)
		
		self.penColour = signalColour
		self.fontColour = fontColour
		self.penWidth = signalWidth
		self.label = dataLabel
		self.values = []
		
		self.stream = []
		prevValue = dataStream[0]
		if isNumber(prevValue) :
			prevHeight = 0
		else :
			prevHeight = int(CYCLE_HEIGHT * 0.5)
		# endif
		adjFactor = float(CYCLE_WIDTH) / float(period)
		
		self.values.append([dataStream[0], 2])
		
		# Data signal plot changes when the data changes only.
		for count in range(len(dataStream)) :
			value = dataStream[count]
			atTime = float(timeStream[count])
			xPos = int(atTime * adjFactor)
			
			if isNumber(dataStream[count]) :	# 89089
				if dataStream[count] != prevValue :
					# Transition detected
					
					# Store the values of the data stream so they can be plotted later
					self.values.append([value, xPos])
					
					if prevHeight == CYCLE_HEIGHT :
						self.stream.append(wxPoint(xPos - DATA_DELTA, CYCLE_HEIGHT))
						self.stream.append(wxPoint(xPos + DATA_DELTA, 0))
						prevHeight = 0
					elif prevHeight == 0 :
						self.stream.append(wxPoint(xPos - DATA_DELTA, 0))
						self.stream.append(wxPoint(xPos + DATA_DELTA, CYCLE_HEIGHT))
						prevHeight = CYCLE_HEIGHT
					else :
						self.stream.append(wxPoint(xPos, int(CYCLE_HEIGHT/2)))
						self.stream.append(wxPoint(xPos + DATA_DELTA, 0))
						prevHeight = 0
					# endif
				else :
					self.stream.append(wxPoint(xPos, prevHeight))
				# endif
			elif dataStream[count][0] == 'z' :	# zzzzz
				if prevHeight == CYCLE_HEIGHT or prevHeight == 0 :
					self.stream.append(wxPoint(xPos - DATA_DELTA, prevHeight))
				# endif
				prevHeight = int(CYCLE_HEIGHT/2)
				self.stream.append(wxPoint(xPos, prevHeight)) 
			else :								# xxxxx
# 				if dataStream[count] != prevValue :
# 					# Transition detected
# 					
# 					# Store the values of the data stream so they can be plotted later
# 					self.values.append([value, xPos])
# 					
# 					if prevHeight == CYCLE_HEIGHT :
# 						self.stream.append(wxPoint(xPos - DATA_DELTA, CYCLE_HEIGHT))
# 						self.stream.append(wxPoint(xPos + DATA_DELTA, 0))
# 						prevHeight = 0
# 					elif prevHeight == 0 :
# 						self.stream.append(wxPoint(xPos - DATA_DELTA, 0))
# 						self.stream.append(wxPoint(xPos + DATA_DELTA, CYCLE_HEIGHT))
# 						prevHeight = CYCLE_HEIGHT
# 					else :
# 						self.stream.append(wxPoint(xPos, int(CYCLE_HEIGHT/2)))
# 						self.stream.append(wxPoint(xPos + DATA_DELTA, 0))
# 						prevHeight = 0
# 					# endif
# 				else :
# 					self.stream.append(wxPoint(xPos, prevHeight))
# 					#self.stream.append(wxPoint(xPos, CYCLE_HEIGHT))
# 				# endif
				
				if dataStream[count] != prevValue :
					# Transition detected
					if prevHeight == CYCLE_HEIGHT :
						self.stream.append(wxPoint(xPos - DATA_DELTA, CYCLE_HEIGHT))
					elif prevHeight == 0 :
						self.stream.append(wxPoint(xPos - DATA_DELTA, 0))
					# endif
					self.stream.append(wxPoint(xPos, int(CYCLE_HEIGHT/2)))
					
					# Display values incase important data has some 'x's mixed in.
					self.values.append([value, xPos])
				# endif
				
				if count != len(dataStream) - 1 :
					offset = 2
					for idx in range(1, 11) :
						self.stream.append(wxPoint(int(xPos + DATA_DELTA * idx), int(CYCLE_HEIGHT/2 + offset)))
						offset = ~offset + 1
					# endfor
				# endif
				
				prevHeight = int(CYCLE_HEIGHT/2)
			# endif
			prevValue = dataStream[count]
		# endfor
		
		# Now reverse and invert the stream and append to the end
		invStream = []
		for point in self.stream :
			invStream.append(wxPoint(point.x, 20 - point.y))
		# endfor
		invStream.reverse()
		self.stream += invStream
		
	# end __init__
	
	def draw(self, dc, atPos) :
		""" Draw 'dataSignal' to the diagram
			'dc' is the device context to use for drawing.
		"""
		
		dc.SetPen(wxPen(self.penColour, self.penWidth, wxSOLID))
		dc.SetBrush(wxBrush(self.penColour, wxSOLID))
		dc.SetTextBackground(wxBLACK)
		dc.SetTextForeground(self.penColour)
		
		lastPos = self.stream[0]
		for curPos in self.stream[1:] :
			dc.DrawLine(atPos.x + lastPos.x,
						atPos.y + lastPos.y,
						atPos.x + curPos.x,
						atPos.y + curPos.y)
			lastPos = curPos
		# endfor
		dc.DrawText(self.label, 20, atPos.y + 2)
		
		self.font = dc.GetFont()
		pointSize = self.font.GetPointSize()
		self.font.SetPointSize(8)
		dc.SetFont(self.font)
		
		# Now draw in the values of the data stream
		# dc.SetTextForeground(self.fontColour)
		above = True
 		for ii in range(len(self.values)) :
			if above :
				dc.DrawText(self.values[ii][0], atPos.x + self.values[ii][1] + 2, atPos.y - 11)
				above = not above
			else :
				dc.DrawText(self.values[ii][0], atPos.x + self.values[ii][1] + 2, atPos.y + 20)
				above = not above
			
		self.font.SetPointSize(pointSize)
		dc.SetFont(self.font)
		
	# end draw
	
#endclass dataSignal


# Writes a small octave file that can then be run to produce a plot
def writeOctaveScript(labels, maxTime, matFile, octFile) :
	
	try :
		fh = open(octFile, 'w')
	
	except :
		print 'Cannot write file ' + outFile
		sys.exit(1)
	# endtry
	
	numSignals = len(labels)
	
	fh.write('load ' + matFile + '\n')
	
	xlim = str(round(float(maxTime) + 0.5))
	ylim = str((float(numSignals) - 1.0) * 1.5)
	fh.write('axis ([-0.5, ' + xlim + ', -0.5, ' + ylim + ']);\n')
	fh.write('plot(')
	
	for count in range(1, len(labels)) :
		fh.write('signal0, signal' + str(count) + ', ";' + labels[count] + ';"')
		if count != len(labels) -1 :
			fh.write(', ')
		else :
			fh.write(');\n')
		# endif
	# endfor
	
	fh.write('disp "Press any key."\n')
	fh.write('pause;\n')
	
# end writeOctaveScript


# Writes the 'data' into a form that 'octave' can load (.mat file).
def writeMatData(labels, floatStreams, outFile) :
	
	try :
		fh = open(outFile, 'w')
	
	except :
		print 'Cannot write file ' + outFile
		sys.exit(1)
	# endtry
	
	fh.write('# Created by timing.py 0.0.1\n')	# Entries for the '.mat' (matrix) file
	
	numStreams = len(floatStreams)
	lenStreams = len(floatStreams[0])
	
	# Offset the data so the streams don't overlap on the plot
	posOffset = 0.0
	for stream in range(1, numStreams) :
		for item in range(lenStreams) :
			floatStreams[stream][item] += posOffset
		posOffset += 1.5
	# endfor
	
	for count in range(numStreams) :
		
		fh.write('# name: signal' + chr(count + 48)+ '\n')
		fh.write('# type: matrix\n')
		fh.write('# rows: 1\n')
		fh.write('# columns: ' + str(lenStreams) + '\n')
		for item in range(lenStreams) :
			fh.write(' ' + str(floatStreams[count][item]))
		# endfor
		fh.write('\n')
		
	# endfor
	
	# finished with this
	fh.close()
	
# end writeMatData


def runOctaveScript(octScript) :
	os.spawnl(os.P_WAIT, '/usr/bin/octave', '--silent', octScript)
# end runOctaveScript


# Takes in the string data, orders it into horizontal streams and offsets it
# for plotting
def processData(data) :
	
	# Change data from being column aligned to row aligned
	dataTrans = transpose(data)
	
	# Make pretty sloping waveforms
	clockPeriod =  calcClockPeriod(dataTrans)
	slopeDelta = float(clockPeriod) / 20.0
	
	numStreams = len(dataTrans)
	lenStreams = len(dataTrans[0])
	
	# First, modify the times in the '$time' stream so that a signal
	# should go from LO/HI to HI/LO in 'slopeDelta'*2 distance.
	modData = [[dataTrans[0][0]]]	# 'data[0][0]' should be 0
	for a in range(1,lenStreams) :
		modData[0].append(float(dataTrans[0][a]) - slopeDelta)
		modData[0].append(float(dataTrans[0][a]) + slopeDelta)
	# endfor
	print modData[0]
	
	# Convert data to floats, offset it from the x-axis so the plots
	# for each signal dont overlap, then make it slope on +ve & -ve
	# edge transitions.
	for a in range(1, numStreams) :
		modData.append([])
		for b in range(0, lenStreams) :
			dataItem = dataTrans[a][b]
			if dataItem == 'z' :
				dataItem = 0.5
			elif dataItem == 'x' :
				dataItem = -0.5
			elif dataItem == 'X' :
				dataItem = 2.0
			else :
				dataItem = float(dataItem)
			# endif
			
			modData[a].append(dataItem)
			modData[a].append(dataItem)
		# endfor
		# trim off the last item
		modData[a].pop()
	# endfor
	
	return modData
	
# end processData


# It is helpful to know the clock period because then we can make pretty sloping
# leading edges of the timing waveforms.
def calcClockPeriod(data) :
	
	# Allow the stream to start at non-zero time
	start = 0
	startTime	= int(data[0][start])
	#print startTime
	
	for count in range(0, len(data[0])) :
		data[0][count] = str(int(data[0][count]) - startTime)
		#print data[0][count]
	startTime = 0	#int(data[0][start])
	
	# Find the first one
	start = 0
	while (data[1][start] != '1') :
		start	+= 1
	
	# Second stream in 'data' is the clock. Scan stream to get period
	initialState, count = int(data[1][start]), start
	while count < len(data[1]) :
		currentState = int(data[1][count])
		if currentState != initialState :
			break	# Clock has made a transition
		# endif
		count += 1
	# endwhile
	
	clockPeriod = (int(data[0][count]) - startTime) * 2
	#print clockPeriod
	
	# To be safe, do it again incase first half-clock period was different
	initialState = int(data[1][count])
	while count < len(data[1]) :
		currentState = int(data[1][count])
		if currentState != initialState :
			break	# Clock has made another transition
		# endif
		count += 1
	# endwhile
	
	secondPeriod = ((int(data[0][count]) - startTime) * 2) - clockPeriod
	if clockPeriod != secondPeriod :
		print 'WARNING: Using period of', secondPeriod, 'nanoseconds.'
		print 'Asyncronous Clock or 2nd Stream is not the Clock?'
		#sys.exit(1)
	# endif
	
	#print secondPeriod
	
	return secondPeriod
	
# end calcClockPeriod


# Transpose or ' on a 2D list (matrix) will cause "an_item = a_list[x][y] = a_list'[y][x]"
def transpose(matrixIn) :
	
	matrixOut = []
	
	for a in range(len(matrixIn[0])) :
		matrixOut.append([])
		for b in range(len(matrixIn)) :
			matrixOut[a].append(matrixIn[b][a])
		# endfor
	# endfor
	
	return matrixOut
	
# end transpose


class VdiagramApp(wxApp) :
	""" The main 'timing' application object.
	"""
	
	def OnInit(self) :
		""" Initialise the application.
		"""
		wxInitAllImageHandlers()
	
		global _docList
		_docList = []
		
		print '\nTiming Diagram Generator for Verilog 0.0.1'
		
		# needs a comand line argument
		if(len(sys.argv) < 2) :
			print 'USAGE:'
			print '    timing.py file.out\n'
			sys.exit(1);
		#endif
		
		print
		
		# Try to load the input file using the argument given
		if os.access(sys.argv[1], os.F_OK | os.R_OK) :
			fh = open(sys.argv[1], 'r')
			octFile = sys.argv[1].split('.')[0] + '.oct'	# Files used for output
			matFile = sys.argv[1].split('.')[0] + '.mat'
		else :
			# That failed so try to load with extension '.out' appended
			if os.access(sys.argv[1] + '.out', os.F_OK | os.R_OK) :
				fh = open(sys.argv[1] + '.out', 'r')
				octFile = sys.argv[1] + '.oct'
				matFile = sys.argv[1] + '.mat'
		# endif
		
		# Read in the labels ignoring any comments
		labels = []
		while labels == [] :
			textLine = fh.readline()
			cleanedLine = textLine.split ('%')[0]	# Remove comments
			if cleanedLine != '' :
				labels = cleanedLine.split()
			else :
				sys.stdout.write (textLine)
		# endwhile
		
		textLine = fh.readline()	# Read in the data
		data = []
		while len(textLine) :
			cleanedLine = textLine.split ('%')[0]
			if len(cleanedLine.split()) > 0 :
				data.append(cleanedLine.split())
			else :
				sys.stdout.write (textLine)
			textLine = fh.readline()
		# endwhile
		
		fh.close()
		
		transData = transpose(data)
		if len(transData) <> len(labels) :
			print 'ERROR: Number of Labels/Signals mismatch'
		else :
			self.frame = TimingDiagramFrame(None, -1, "Timing Diagram", labels, transData)
			self.frame.Show(True)
			
			# modData = processData(data)
			# writeMatData(labels, modData, matFile)	# For use in Octave or Matlab(TM)
			# writeOctaveScript(labels, data[len(data)-1][0], matFile, octFile)
			# runOctaveScript(octFile)
		# endif
		
		print
		return True
		
# endclass vdiagram


#---------------------------------------------------------------------

def main() :
	
	global _app
	
	# Create and start the pySketch application.
	
	_app = VdiagramApp(0)
	_app.MainLoop()
	
# end main


if __name__ == "__main__" :
	main()
