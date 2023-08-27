#!/bin/bash
# qemu-system-i386 -boot a -fda dos.img -serial pty
qemu-system-i386 -option-rom OPTROM.BIN -serial /dev/pts/$1
