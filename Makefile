all: SKEL.SYS READDEV.COM

SKEL.SYS: skel.s
	yasm -p nasm $< -o $@ 
	mcopy -o -i dos.img $@ ::/

READDEV.COM: readdev.s
	yasm -p nasm $< -o $@ 
	mcopy -o -i dos.img $@ ::/

