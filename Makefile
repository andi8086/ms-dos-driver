all: SKEL.SYS READDEV.COM COMDSK.SYS

SKEL.SYS: skel.s
	yasm -p nasm $< -o $@ 
	mcopy -o -i dos.img $@ ::/

COMDSK.SYS: comdsk.s
	yasm -p nasm $< -o $@ 
	mcopy -o -i dos.img $@ ::/

READDEV.COM: readdev.s
	yasm -p nasm $< -o $@ 
	mcopy -o -i dos.img $@ ::/

