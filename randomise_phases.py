#!/usr/bin/env python

import optparse
from sys import *
import os,sys,re
from optparse import OptionParser
import glob
import subprocess
from os import system
import linecache
import time
#=========================
def setupParserOptions():
        parser = optparse.OptionParser()
        parser.set_usage("%prog -i <stack.img> --lim=[limit] --apix=[pixelsize] --mag=[magnification]")
        parser.add_option("-i",dest="stack",type="string",metavar="FILE",
                help="Particle stack in .img format. BLACK particle on WHITE background")
        parser.add_option("--lim",dest="lim",type="int", metavar="INT",
                help="Resolution below which phases will be randomised")
	parser.add_option("--apix",dest="apix",type="float", metavar="FLOAT",
                help="Pixel size")
	parser.add_option("--mag",dest="mag",type="float", metavar="FLOAT",
                help="Magnification")
        parser.add_option("-d", action="store_true",dest="debug",default=False,
                help="debug")
        options,args = parser.parse_args()

        if len(args) > 0:
                parser.error("Unknown commandline options: " +str(args))

        if len(sys.argv) < 2:
                parser.print_help()
                sys.exit()
        params={}
        for i in parser.option_list:
                if isinstance(i.dest,str):
                        params[i.dest] = getattr(options,i.dest)
        return params

#=============================
def checkConflicts(params):
        if not params['stack']:
                print "\nWarning: no untilted stack specified\n"
        elif not os.path.exists(params['stack']):
                print "\nError: stack file '%s' does not exist\n" % params['stack']
                sys.exit()
	if not params['lim']:
		print "\nWarning: no resolution limit specified\n"
		sys.exit()
	if not params['apix']:
		print "\nWarning: no pixel size specified\n"
		sys.exit()

#==============================
def getEMANPath():
        emanpath = subprocess.Popen("env | grep EMAN2DIR", shell=True, stdout=subprocess.PIPE).stdout.read().strip() 
        if emanpath:
                emanpath = emanpath.replace("EMAN2DIR=","")
        if os.path.exists(emanpath):
                return emanpath
        print "EMAN2 was not found, make sure eman2/2.06 is in your path"
        sys.exit()

#==============================
def convertIMGtoMRC(params):

	#convert imagic stack to 3D mrc image stack using e2proc2d	

	cmd = 'e2proc2d.py --twod2threed %s %s.mrc' %(params['stack'],params['stack'][:-4]) 
        if params['debug'] is True:
	        print cmd
        subprocess.Popen(cmd,shell=True).wait()

#==============================
def wait(testFile):

        testExists = False

	while testExists is False: 

                test = os.path.isfile(testFile)

                if test is False:
			print '%s does not exist yet' %(testFile)
                        testExists = False

                if test is True:
			print '%s exists' %(testFile)
                        testExists = True

#==============================
def randomise_phases(params,phase_lib):

	#Copy executable to cwd
	cmd = 'cp %s/makestack_HRnoise.exe .'%(phase_lib)
        subprocess.Popen(cmd,shell=True).wait()
       
	#######File input format#########
 
	#setenv  IN_PART     ${filmno}_p.stk
	#setenv  OUT         ${filmno}_p_random_${resol}A.stk
	#makestack_HRnoise.exe <<EOF
	#81600.0,14.0,15,F    !XMAG, DSTEP, RESOLUTION, LBACK (T/F)
	#EOF

	#calculate DSETP:
	dstep = (params['mag']*params['apix'])/10000

	p1 = 'setenv IN_PART	%s.mrc\n' %(params['stack'][:-4])
        p2 = 'setenv OUT	%s_randomPhase.mrc\n' %(params['stack'][:-4])
	p3 = './makestack_HRnoise.exe << EOF\n' 
	p4 = '%s,%s,%s,F\n'%(params['mag'],dstep,params['lim'])
	p5 = 'EOF\n' 
        p6 = 'touch randomPhase_done\n'
        
       	ff_cmd ='#!/bin/csh\n'
        ff_cmd +=p1
        ff_cmd +=p2
        ff_cmd +=p3
        ff_cmd +=p4
        ff_cmd +=p5
	ff_cmd +=p6
	
	if params['debug'] is True:
		print ff_cmd
	
	tmp = open('tmp.csh','w')
        tmp.write(ff_cmd)
        tmp.close()

        cmd = 'chmod +x tmp.csh'
        subprocess.Popen(cmd,shell=True).wait()

        cmd = './tmp.csh' 
        subprocess.Popen(cmd,shell=True).wait()

	wait('randomPhase_done')

	#Convert 3D mrc stack to 2D imagic stack
	cmd = 'e2proc2d.py --threed2twod %s_randomPhase.mrc %s_randomPhase.img' %(params['stack'][:-4],params['stack'][:-4])
	if params['debug'] is True:
		print cmd
	subprocess.Popen(cmd,shell=True).wait()

	#Cleanup

	cmd = 'rm randomPhase_done tmp.csh makestack_HRnoise.exe %s_randomPhase.mrc %s.mrc' %(params['stack'][:-4],params['stack'][:-4])
	if params['debug'] is True:
		print cmd
	subprocess.Popen(cmd,shell=True)
	
#==============================
if __name__ == "__main__":

	#Library: 
	phase_lib = '/labdata/allab/michaelc/Scripts/Phase_randomisation/'
	
	getEMANPath()
	params=setupParserOptions()
	checkConflicts(params)
	convertIMGtoMRC(params)
	randomise_phases(params,phase_lib)
	
