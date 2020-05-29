#!/bin/bash

# Sanity check.
if [ ! -f ./floppix/disk1.img ]; then
    printf "./floppix/disk1.img does not exist. Exiting.\n"
    exit 1
fi

# Tell Bochs where needed files reside.
#BXSHARE=/usr/share/bochs
#export BXSHARE

# Start Bochs.
./bochs-2.6.11/bochs -f bochsrc.txt -q
