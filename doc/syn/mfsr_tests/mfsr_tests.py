#!/usr/bin/env python
# -*- coding: utf-8 -*-

import	sys, os, random
from	subprocess import call

advert	= '''
# Running MFSR and traditional counters tests.
# Copyright 2009 Patrick Suggate
#	patrick@physics.otago.ac.nz
#
'''

RESULTS_FILE	= 'results_mfsr.csv'

COUNTER_BITS	= range(5, 33)
COUNTER_PREFIX	= 'mfsr'
#COUNTER_BITS	= [5]

def runTest(bits):
	name	= COUNTER_PREFIX+str(bits)
	try:
		os.mkdir(name)
	except:
		call('rm -rf '+name, shell=True)
		os.mkdir(name)
	
	makeMakefile(name)
	makeTopfile(bits, name)
	print	'Running test #'+str(bits)+' in dir: '+name
	cmd	= 'cd '+name+' && make'
	print	cmd
	call(cmd, shell=True)
	
	return	getLatency(name), getSlices(name)

def getResults(bits):
	name	= COUNTER_PREFIX+str(bits)
	return	getLatency(name), getSlices(name)

def makeMakefile(name):
	fi	= open('Makefile.skel', 'r')
	skel	= fi.readlines()
	fi.close()
	
	skel	= map(lambda x: x.replace('TEST_MODULE_XX', name), skel)
	skel	= map(lambda x: x.replace('CONSTRAINTS_XX', '../null.ucf'), skel)
	
	fo	= open(name+'/Makefile', 'w')
	fo.writelines(skel)
	fo.close()

def makeTopfile(bits, name):
	fi	= open('mfsr_top_skel.v', 'r')
	skel	= fi.readlines()
	fi.close()
	
	bits	= str(bits)
	skel	= map(lambda x: x.replace('WIDTH_XX', bits), skel)
	skel	= map(lambda x: x.replace('TEST_MODULE_XX', name), skel)
	
	fo	= open(name+'/top.v', 'w')
	fo.writelines(skel)
	fo.close()

def getSlices(name):
	fi	= open(name+'/_xilinx_int.par', 'r')
	par	= fi.read()
	fi.close()
	i	= par.find('Number of Slices')
	return	par[i:i+60].split()[3]

def getLatency(name):
	fi	= open(name+'/_xilinx_int.twr', 'r')
	par	= fi.read()
	fi.close()
	i	= par.find('Minimum period:')
	return	par[i:i+60].split()[2]

if __name__ == "__main__":
	r	= random.Random()
	print	advert
	if len(sys.argv) == 1:
		results	= [runTest(n) for n in COUNTER_BITS]
	elif sys.argv[1] == '--get-results':
		results	= [getResults(n) for n in COUNTER_BITS]
	elif sys.argv[1] == '--clean':
		[call('rm -rf '+COUNTER_PREFIX+str(n), shell=True) for n in COUNTER_BITS]
		sys.exit(0)
	else:
		print	'# ERROR: Unrecognised option.'
		sys.exit(1)
	
	fo	= open(RESULTS_FILE, 'w')
	for b in COUNTER_BITS:
		r	= results.pop(0)
		fo.write(str(b)+','+r[0][0:-2]+','+r[1]+'\n')
	fo.close()
	print	'# Done.'
