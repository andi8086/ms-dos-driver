all: comsrv cfh read_bpb

CFLAGS=$(shell pkgconf --cflags sdl2 SDL2_mixer)
LDFLAGS=$(shell pkgconf --libs sdl2 SDL2_mixer)

read_bpb: read_bpb.c
	gcc $^ -o $@

cfh: create_floppy_header.c
	gcc $^ -o $@

comsrv: comsrv.c ui_floppy.c
	gcc $^ -o $@ $(CFLAGS) $(LDFLAGS)
