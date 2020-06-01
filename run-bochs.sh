#!/bin/bash

# Tell Bochs where needed files reside.
#BXSHARE=/usr/share/bochs
#export BXSHARE

# Start Bochs.
./bochs-2.6.11/bochs -f bochsrc.txt -q
