#!/bin/bash

iverilog -g2012 -o out.vvp *.sv
vvp out.vvp
gtkwave dump.vcd
