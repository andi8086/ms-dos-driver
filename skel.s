org 0

struc header
        next: resd 1
        attr: resw 1
        strat: resw 1
        intr: resw 1
        name: resb 8
endstruc

struc drivereq
        .len: resb 1
        .unit: resb 1
        .cmd: resb 1
        .status: resw 1
        .dosq: resd 1
        .devq: resd 1
endstruc


struc initreq
        .hdr: resb drivereq_size
        .numunits: resb 1
        .brkaddr: resd 1
        .bpbaddr: resd 1
endstruc

struc readreq
        .hdr: resb drivereq_size
        .mediadesc: resb 1      ; ignored on char devs
        .dta: resd 1
        .count: resw 1
        .startsec: resw 1       ; ignored on char devs
endstruc

%define ATTR_BLKDEV  (0 << 15)
%define ATTR_CHARDEV (1 << 15)
%define ATTR_IOCTL   (1 << 14)

%define STATUS_ERROR (1 << 15)
%define STATUS_BUSY  (1 << 9)
%define STATUS_DONE  (1 << 8)

%define ERR_WRITE_PROTECT   0
%define ERR_UNKNOWN_UNIT    1
%define ERR_DRIVE_NOT_ERADY 2
%define ERR_UNKNOWN_CMD     3
%define ERR_CRC_ERROR       4
%define ERR_BAD_DRIVE_REQ   5
%define ERR_SEEK_ERROR      6
%define ERR_UNKNOWN_MEDIA   7
%define ERR_SECTOR_NOT_FOUND 8
%define ERR_OUT_OF_PAPER    9
%define ERR_WRITE_FAULT    10
%define ERR_READ_FAULT     11
%define ERR_GENERAL        12

hdr:
istruc header
        at next, dd -1
        at attr, dw (ATTR_CHARDEV | ATTR_IOCTL)
        at strat, dw strategy
        at intr, dw interrupt
        at name, db "SKELETON"
iend

packet_ptr dd 0

strategy:
        mov [cs:packet_ptr], bx
        mov [cs:packet_ptr + 2], es
        retf

interrupt:
        push ax
        push cx
        push dx
        push bx
        push si
        push di
        push bp
        push ds
        push es

        les di, [cs:packet_ptr]
        mov si, [es:di + drivereq.cmd]
        cmp si, 12
        ja .bad_cmd

        shl si, 1
        jmp [.fntab + si]

.bad_cmd:
        mov al, ERR_UNKNOWN_CMD
.err:
        xor ah, ah
        or ah, (STATUS_ERROR | STATUS_DONE) >> 8
        mov [es:di + drivereq.status], ax
        jmp interrupt.end

.busy:
        mov word [es:di + drivereq.status], (STATUS_DONE | STATUS_BUSY)
        jmp interrupt.end

.exit:
        mov word [es:di + drivereq.status], STATUS_DONE
.end:
        pop es
        pop ds
        pop bp
        pop di
        pop si
        pop bx
        pop dx
        pop cx
        pop ax
        retf

.fntab:
        dw init        ;0      INIT
        dw .exit        ;1      Media Check
        dw .exit        ;2      build BPB
        dw ioctl_input  ;3      ioctl input
        dw ioctl_input  ;4      input (read)
        dw .exit        ;5      non destructive input, no wait
        dw .exit        ;6      input status
        dw .exit        ;7      input flush
        dw .exit        ;8      output (write)
        dw .exit        ;9      output (write) verify
        dw .exit        ;10     output status
        dw .exit        ;11     output flush
        dw .exit        ;12     ioctl output

ioctl_input:
        lea bp, [es:di + readreq.count]
        les di, [es:di + readreq.dta]


        ; ignore count and always transfer one byte
        mov bx, [cs:last_byte]  ; data offset
        mov al, [cs:bx]         ; read data
        stosb                   ; store into DTA

        mov word [bp], 1        ; set count to 1
        inc word [cs:last_byte]
        cmp word [cs:last_byte],last_byte
        jb interrupt.exit

        mov word [cs:last_byte], ioctl_str

        jmp interrupt.exit

ioctl_str: db "test-data", 0x1A
last_byte: dw ioctl_str

res_end:
init:
        push cs
        pop ds
        mov dx, install_msg
        mov ah, 0x09
        int 0x21

        mov word [es:di + initreq.brkaddr], res_end
        mov word [es:di + initreq.brkaddr + 2], cs

        jmp interrupt.exit

install_msg db "Driver skeleton installed.", 0x0D, 0x0A, '$'

