#! python3

# CONTROL SCRIPT FOR SILETZ CALIBRATION IN PYTHON
# Ryan Shojinaga, Water Quality Analyst, NRS3, Oregon DEQ
# shojinaga.ryan@deq.state.or.us, 503-229-5777

# Lampert, David. (2015). PyHSPF: Data integration software for hydrologic and
#   water quality modeling. 

import pandas as pd
import numpy as np
import csv, os, datetime, numpy, pickle, time
from pyhspf import HSPFModel, WDMUtil

prjPth = 'D:/siletz/'

# READ COUNTER FROM count.csv -- Model run number for calibration
countFil = open('D:/siletz/count.txt', 'r')

n = int(countFil.readline())

countFil.close()

# OR SET MANUALLY
n = 999

# SET MODEL NAMES
modelNames = ['siletz', 'siletz' + str(n)]

# Source the functions modify_parameters, run_model, and proc_results
pyPath = 'D:/siletz/scripts/python/'

exec(open(pyPath + 'modify_parameters.py').read())

exec(open(pyPath + 'run_siletz_model.py').read())

exec(open(pyPath + 'proc_hspf_results.py').read())

# modelInName = modelNames[0]
# modelOutName = modelNames[1]

# Run the functions (model)
modify_parameters(modelNames[0], modelNames[1], prjPth)

run_siletz_model(modelNames[1]) 

proc_hspf_results(n)
