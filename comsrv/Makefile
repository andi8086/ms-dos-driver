all: comsrv cfh read_bpb

read_bpb: read_bpb.c
	gcc $^ -o $@

cfh: create_floppy_header.c
	gcc $^ -o $@

comsrv: comsrv.c
	gcc $^ -o $@
