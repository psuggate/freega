#!/usr/bin/env python
# -*- coding: utf-8 -*-

import	sys, os, random
from	subprocess import call

advert	= '''
# Running MFSR and traditional PC tests.
# Copyright 2009 Patrick Suggate
#	patrick@physics.otago.ac.nz
#
'''

COUNTER_BITS	= range(8, 33)
# Spartan-3
CARRYMUX_DELAY	= 0.064
HYBRID_DELAY	= 3.65
PCMFSR_DELAY	= 2.9
PCTRAD_DELAY	= 3.7
STR_FPGA	= 'xc3s200-pq208-4'

## Virtex-5
#CARRYMUX_DELAY	= 0.021
#HYBRID_DELAY	= 1.45
#PCMFSR_DELAY	= 1.15
#PCTRAD_DELAY	= 1.45
#STR_FPGA	= 'xc5vlx30-ff324-3'

INPUTFILES	= ['Makefile.skel', 'pctop_skel.v', 'null.ucf', 'pctest.v', 'pchybrid.v']
OUTPUTFILES	= ['Makefile', 'top.v', 'null.ucf', 'pctest.v', 'pchybrid.v']

# TODO: Write some friggin' documentation.
def calcChanges(d):
	modules	= d['pc']+'.v'	# 'pctest.v pchybrid.v'
	if d['mfsr'] == '':
		use_mfsr	= '0'
		mfsr_define	= ''
	else:
		use_mfsr	= '1'
		mfsr_define	= '`define __use_mfsr'
		modules	+= ' '+'../mfsrs/'+d['mfsr']+'.v'
	
	return	[[	('FPGA_XX', d['fpga']),
			('TEST_MODULES_XX', modules),
			('CONSTRAINTS_XX', 'null.ucf')],
		[	('WIDTH_XX', d['bits']),
			('PCMODULE_XX', d['pc']),
			('USEMFSR_XX', use_mfsr)],
		[	('PERIOD_XX', d['period'])],
		[	('USEMFSR_XX', mfsr_define),
			('MFSR_XX', d['mfsr'])],
		[	('TRADBITS_XX', d['trad']),
			('MFSR_XX', d['mfsr'])]]

def makeChanges(ifiles, changes, opath, ofiles):
	for ii in range(len(ifiles)):
		changeFile(ifiles[ii], changes[ii], opath+ofiles[ii])

def changeFile(ifile, changes, ofile):
	fi	= open(ifile, 'r')
	skel	= fi.readlines()
	fi.close()
	
	for change in changes:
		skel	= map(lambda x: x.replace(change[0], change[1]), skel)
	
	fo	= open(ofile, 'w')
	fo.writelines(skel)
	fo.close()

def getSlices(name):
	fi	= open(name+'/_xilinx_int.par', 'r')
	par	= fi.read()
	fi.close()
	i	= par.find('Number of Slices')
	if i == -1:
		i	= par.find('of Slice Registers')
	return	par[i:i+60].split()[3]

def getLatency(name):
	fi	= open(name+'/_xilinx_int.twr', 'r')
	par	= fi.read()
	fi.close()
	i	= par.find('Minimum period:')
	return	par[i:i+60].split()[2]

def writeResults(prfx, results):
	fo	= open('results_'+prfx+'.csv', 'w')
	for b in COUNTER_BITS:
		r	= results.pop(0)
		fo.write(str(r[0])+','+r[1][0:-2]+','+r[2]+'\n')
	fo.close()

def runTest(name, d):
	changes	= calcChanges(d)
	opath	= name+'/'
	try:
		os.mkdir(name)
	except:
		call('rm -rf '+name, shell=True)
		os.mkdir(name)
	
	makeChanges(INPUTFILES, changes, opath, OUTPUTFILES)
	cmd	= 'cd '+name+' && make > build.txt'
	call(cmd, shell=True)
	return	getLatency(name), getSlices(name)

def cleanTests(prfx):
	dirs	= [prfx+str(n) for n in COUNTER_BITS]
	print	dirs
	map(lambda x: call('rm -rf '+x, shell=True), dirs)


#----------------------------------------------------------------------------
#  Code specific to running the tests.
#
def runTests(clean=False):
	if clean==True:
		return	map(lambda x: cleanTests(x),	\
				['hybrid', 'pcmfsr', 'pctrad'])
	
	#--------------------------------------------------------------------
	# Hybrid PCs 1st
	prfx	= 'hybrid'
	pctest	= {'mfsr':'', 'pc':'pchybrid', 'bits':'', 'trad':'3',	\
		'period':str(HYBRID_DELAY), 'fpga':STR_FPGA}
	results	= []
	for c in COUNTER_BITS:
		pctest['mfsr']	= 'mfsr'+str(c-3)
		pctest['bits']	= str(c)
		r	= runTest(prfx+str(c), pctest)
		results.append([c, r[0], r[1]])
	writeResults(prfx+'-'+pctest['fpga'], results)
	
	#--------------------------------------------------------------------
	# MFSR PCs
	prfx	= 'pcmfsr'
	pctest	= {'mfsr':'', 'pc':'pctest', 'bits':'', 'trad':'0',	\
		'period':str(PCMFSR_DELAY), 'fpga':STR_FPGA}
	results	= []
	for c in COUNTER_BITS:
		pctest['mfsr']	= 'mfsr'+str(c-3)
		pctest['bits']	= str(c)
		r	= runTest(prfx+str(c), pctest)
		results.append([c, r[0], r[1]])
	writeResults(prfx+'-'+pctest['fpga'], results)
	
	#--------------------------------------------------------------------
	# Trad. PCs
	prfx	= 'pctrad'
	pctest	= {'mfsr':'', 'pc':'pctest', 'bits':'', 'trad':'0',	\
		'period':'', 'fpga':STR_FPGA}
	results	= []
	for c in COUNTER_BITS:
		pctest['bits']	= str(c)
		pctest['period']= str(PCTRAD_DELAY+float(c)*CARRYMUX_DELAY)
		r	= runTest(prfx+str(c), pctest)
		results.append([c, r[0], r[1]])
	writeResults(prfx+'-'+pctest['fpga'], results)
	
	print	'Done'


if __name__ == '__main__':
	print	advert
	if len(sys.argv) == 1:
		print	runTests()
	elif sys.argv[1] == '--clean':
		runTests(True)
	else:
		print	'ERROR: Unrecognised option.'
		sys.exit(1)
	sys.exit(0)
