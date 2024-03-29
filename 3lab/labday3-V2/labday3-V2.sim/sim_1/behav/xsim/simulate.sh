#!/bin/bash -f
# ****************************************************************************
# Vivado (TM) v2020.2 (64-bit)
#
# Filename    : simulate.sh
# Simulator   : Xilinx Vivado Simulator
# Description : Script for simulating the design by launching the simulator
#
# Generated by Vivado on Wed Apr 14 16:17:32 EDT 2021
# SW Build 3064766 on Wed Nov 18 09:12:47 MST 2020
#
# Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
#
# usage: simulate.sh
#
# ****************************************************************************
set -Eeuo pipefail
# simulate design
echo "xsim tb_project3_behav -key {Behavioral:sim_1:Functional:tb_project3} -tclbatch tb_project3.tcl -view /home/cx872/Documents/vivado_projects/labday3-V2/labday3-1.wcfg -log simulate.log"
xsim tb_project3_behav -key {Behavioral:sim_1:Functional:tb_project3} -tclbatch tb_project3.tcl -view /home/cx872/Documents/vivado_projects/labday3-V2/labday3-1.wcfg -log simulate.log

