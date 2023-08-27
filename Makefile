all: cksum SKEL.SYS READDEV.COM COMDSK.SYS COMDSKI.SYS OPTROM.BIN


cksum: cksum.c
	gcc $< -o $@

SKEL.SYS: skel.s
	yasm -p nasm $< -o $@ 
	mcopy -o -i dos.img $@ ::/

COMDSK.SYS: comdsk.s
	yasm -p nasm $< -o $@ 
	mcopy -o -i dos.img $@ ::/

COMDSKI.SYS: comdsk.s
	yasm -p nasm -DCOMSERINIT $< -o $@ 
	mcopy -o -i dos.img $@ ::/

READDEV.COM: readdev.s
	yasm -p nasm $< -o $@ 
	mcopy -o -i dos.img $@ ::/

OPTROM.BIN: optrom.s
	yasm -p nasm $< -o $@ -l optrom.lst
	./cksum $@

