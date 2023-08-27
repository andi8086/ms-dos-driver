#!/bin/bash

[ -z "$1" ] && { echo "Syntax: create_hdd.sh imgname"; exit -1; }

dd if=/dev/zero of="$1" bs=512 count=65535
{ mformat -i "$1" -r 32 -L 32 -c 16; } || { echo "Error, mtools installed?"; exit -1; }
{ mdir -i "$1" ::/; } || { echo "Error, mtools installed?"; exit -1; }
