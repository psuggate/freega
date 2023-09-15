#!/usr/bin/env python
# -*- coding: utf-8 -*-

import matplotlib
#matplotlib.use('PS')   # generate postscript output by default
import matplotlib.pyplot as plt
plt.matplotlib.rc('text', usetex = True)
plt.matplotlib.rc('ps', usedistiller="xpdf") 
#plt.matplotlib.rc('ps', usedistiller="xpdf")
#from pylab import unwrap, angle, rand, linspace, pi, sin, cos, fft, log10, fftfreq, fftshift, arange, psd, zeros

import	sys
import	csv
import pylab
from pylab import *

pylab.rcParams.update({'font.size' : 24, 'legend.fontsize': 24, 'font.size' : 24, 'axes.labelsize' : 24, 'xtick.labelsize' : 24, 'ytick.labelsize' : 24,
					   'title.labelsize' : 24, 'font.family' : 'serif'
 })

def readCSV(fname):
	csvr	= csv.reader(open(fname, "r"))
	dat	= []
	for r in csvr:
		dat.append(map(float, r))
	return	dat

def getRange(d, i):
	r	= []
	for l in d:
		r.append(l[i])
	return	r


#############################################################################
#  Plot Counter Performance
#
datt	= readCSV('../syn/mfsr_tests/results_trad.csv')
datm	= readCSV('../syn/mfsr_tests/results_mfsr.csv')
datt=transpose(datt);
datm=transpose(datm);

# Plot data
fig = plt.figure()
ax = fig.add_subplot(111)
ax.plot(datt[0],datt[1],'rs');
ax.plot(datm[0],datm[1],'go');
ax.set_title("Counter Latency vs. Size", {'fontsize'   : 24 })
ax.set_ylim(0,5)
#ax.set_xlim(0,33)
ax.set_xlabel(r'Counter Size (bits)')
ax.set_ylabel(r'Latency (ns)')
ax.legend((r'Radix-2', r'FSR'), shadow = False, numpoints=1, loc = (0.1, 0.1))

# Save graph
plt.savefig('counter_performance.eps')
#plt.show()
plt.close()


#############################################################################
#  Plot PC Performance
#
#datt	= readCSV('../syn/mfsr_tests/results_pctrad-xc5vlx30-ff324-3.csv')
#datm	= readCSV('../syn/mfsr_tests/results_pcmfsr-xc5vlx30-ff324-3.csv')
#dom	= []
#for r in datt:
	#dom.append(r[0])

## Plot data
#fig = plt.figure()
#ax = fig.add_subplot(111)
#ax.plot(dom, getRange(datt, 1), '-',
	#dom, getRange(datm, 1), '-')
#ax.set_title("Program Counter Latency vs. Size", {'fontsize'   : 24 })
#ax.set_ylim(0,6)
#ax.set_xlabel(r'Program Counter Size (bits)', {'fontsize'   : 24 })
#ax.set_ylabel(r'Combinatorial Latency (ns)', {'fontsize'   : 24 })
#ax.legend((r'Traditional', r'FSR'), shadow = False, loc = (0.1, 0.1))

## Save graph
#plt.savefig('pc_performance.eps')
##plt.show()
#plt.close()


############################################################################
# Plot Hybrid Performance
#
#dattv	= readCSV('../syn/mfsr_tests/results_pctrad-xc5vlx30-ff324-3.csv')
#datmv	= readCSV('../syn/mfsr_tests/results_pcmfsr-xc5vlx30-ff324-3.csv')
#dathv	= readCSV('../syn/mfsr_tests/results_hybrid-xc5vlx30-ff324-3.csv')
datts	= readCSV('../syn/mfsr_tests/results_pctrad-xc3s200-pq208-4.csv')
datms	= readCSV('../syn/mfsr_tests/results_pcmfsr-xc3s200-pq208-4.csv')
daths	= readCSV('../syn/mfsr_tests/results_hybrid-xc3s200-pq208-4.csv')
datts=transpose(datts)
datms=transpose(datms)
daths=transpose(daths)


# Plot data
fig = plt.figure()
ax = fig.add_subplot(111)
ax.plot(datts[0],datts[1],'rs')
ax.plot(datms[0],datms[1],'go')
ax.plot(daths[0],daths[1],'bd')
ax.set_title("Program Counter Latency vs. Size - Spartan-3", {'fontsize'   : 24 })
ax.set_ylim(0.0,6.0)
#ax.set_xlim(0,33)
ax.set_xlabel(r'Program Counter Size (bits)')
ax.set_ylabel(r'Latency (ns)')
ax.legend((r'Radix-2', r'FSR', r'Hybrid'), shadow = False,  numpoints=1, loc = (0.1, 0.1))

# Save graph
plt.savefig('hybrid_pc.eps')
#plt.show()
plt.close()

############################################################################
# Plot Hybrid Performance - Virtex
#
dattv	= readCSV('../syn/mfsr_tests/results_pctrad-xc5vlx30-ff324-3.csv')
datmv	= readCSV('../syn/mfsr_tests/results_pcmfsr-xc5vlx30-ff324-3.csv')
dathv	= readCSV('../syn/mfsr_tests/results_hybrid-xc5vlx30-ff324-3.csv')
dattv=transpose(dattv)
datmv=transpose(datmv)
dathv=transpose(dathv)


# Plot data
fig = plt.figure()
ax = fig.add_subplot(111)
ax.plot(dattv[0],dattv[1],'rs')
ax.plot(datmv[0],datmv[1],'go')
ax.plot(dathv[0],dathv[1],'bd')
ax.set_title("Program Counter Latency vs. Size - Virtex-5", {'fontsize'   : 24 })
ax.set_ylim(0.0,2.2)
#ax.set_xlim(0,33)
ax.set_xlabel(r'Program Counter Size (bits)')
ax.set_ylabel(r'Latency (ns)')
ax.legend((r'Radix-2', r'FSR', r'Hybrid'), shadow = False,  numpoints=1, loc = (0.1, 0.1))

# Save graph
plt.savefig('hybrid_pc_virtex.eps')
#plt.show()
plt.close()
