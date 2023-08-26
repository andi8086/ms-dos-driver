all: SKEL.SYS READDEV.COM SERDRIVE.SYS

SKEL.SYS: skel.s
	yasm -p nasm $< -o $@ 
	mcopy -o -i dos.img $@ ::/

SERDRIVE.SYS: serdrive.s
	yasm -p nasm $< -o $@ 
	mcopy -o -i dos.img $@ ::/

READDEV.COM: readdev.s
	yasm -p nasm $< -o $@ 
	mcopy -o -i dos.img $@ ::/

