org 0

struc header
        next: resd 1
        attr: resw 1
        strat: resw 1
        intr: resw 1
        nunits: resb 1
        reserved: resb 7
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
        .nunits: resb 1
        .brkaddr: resd 1
        .bpb_array: resd 1
endstruc

struc mckreq
        .hdr: resb drivereq_size
        .medadesc: resb 1
        .return: resb 1
endstruc

struc bpbreq
        .hdr: resb drivereq_size
        .mediadesc: resb 1
        .dta: resd 1
        .bpb: resd 1
endstruc

struc readreq
        .hdr: resb drivereq_size
        .mediadesc: resb 1
        .dta: resd 1
        .count: resw 1
        .startsec: resw 1
endstruc

struc writereq
        .hdr: resb drivereq_size
        .mediadesc: resb 1
        .dta: resd 1
        .count: resw 1
        .startsec: resw 1
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

%define SERDRIVE_ACK       'K'

hdr:
istruc header
        at next, dd -1
        at attr, dw ATTR_BLKDEV
        at strat, dw strategy
        at intr, dw interrupt
        at nunits, db 1           
        at reserved, times 7 db 0
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
        dw media_check  ;1      Media Check
        dw build_bpb    ;2      build BPB
        dw .exit        ;3      ioctl input
        dw read         ;4      input (read)
        dw .exit        ;5      non destructive input, no wait
        dw .exit        ;6      input status
        dw .exit        ;7      input flush
        dw write        ;8      output (write)
        dw write        ;9      output (write) verify
        dw .exit        ;10     output status
        dw .exit        ;11     output flush
        dw .exit        ;12     ioctl output

%define MEDIA_NOCHANGE 1
%define MEDIA_CHANGE   -1
%define MEDIA_MAYBECHANGED 0

media_check:
        mov byte [es:di + mckreq.return], MEDIA_NOCHANGE 
        jmp interrupt.exit

build_bpb:
        ; we ignore the FAT sector we got... don't read
        ; the media descriptor out of it, instead,
        ; report hard disk F8
        mov byte [es:di + bpbreq.mediadesc], 0xF8

        mov word [es:di + bpbreq.bpb], bpb
        mov word [es:di + bpbreq.bpb + 2], cs
        jmp interrupt.exit

write_s:
        mov ah, 1
        int 14h
        test ah, 80h
        ret

read_s:
        mov ah, 2
        int 14h
        test ah, 80h
        ret

send_rw_params:
        ; send required sector number
        mov al, byte [es:di + readreq.startsec]
        call write_s
        jnz .error

        mov al, byte [es:di + readreq.startsec + 1]
        call write_s
        jnz .error

        mov ax, bp
        call write_s
        jnz .error

        mov ax, bp
        xchg al, ah
        call write_s
.error:
        ret


read:
        mov bp, [es:di + readreq.count]

        cld

        mov dx, 0       ; COM 1
        mov al, 'R'     ; tell host we want to read
        call write_s
        jnz read.error

        call send_rw_params
        jnz read.error

        ; wait for ACK
        call read_s
        jnz read.error
        cmp al, SERDRIVE_ACK
        jne read.error

        push es
        push di

        les di, [es:di + readreq.dta]
        mov si, bp
.next_sector:
        mov cx, 512
.serial:
        call read_s
        jnz .error

        stosb
        loop .serial 

        dec si
        cmp si, 0
        jnz .next_sector

        pop di
        pop es

        jmp interrupt.exit
.error:
        pop di
        pop es

        mov al, ERR_READ_FAULT
        mov word [es:di + readreq.count], 0
        jmp interrupt.err


write:
        mov bp, [es:di + writereq.count]

        cld

        mov dx, 0       ; COM 1

        mov al, 'W'     ; tell host we want to write
        call write_s
        jnz .error

        call send_rw_params
        jnz .error

        ; wait for ACK
        call read_s
        jnz .error
        cmp al, SERDRIVE_ACK
        jne .error

        push ds
        push si
        push di

        lds si, [es:di + writereq.dta]
        mov di, bp
.next_sector:
        mov cx, 512
.serial:

        lodsb   ; load one byte from DTA

        call write_s
        jnz .error

        loop .serial

        dec di
        cmp di, 0
        jnz .next_sector

        pop di
        pop si
        pop ds

        jmp interrupt.exit
.error:
        pop di
        pop si
        pop ds

        mov al, ERR_WRITE_FAULT
        mov word [es:di + writereq.count], 0
        jmp interrupt.err


bpb:
.bytes_per_sector:      dw 512
.sectors_per_cluster:   db 16      ; 8K blocks
.reserved_sectors:      dw 80 
.number_of_fats:        db 2
.root_dir_entries:      dw 512    ; this makes 32 sectors
.num_sectors            dw 65535
.media_desc             db 0xF8   ; hard disk
.fat_sectors            dw 32     ; gives 16 Kbyte per FAT,
                                  ; or 8192 entries for 32 MB

; this is a 1-element array
bpb_array:              dw bpb
                        dw 0 

; *********************** SUICIDE FENCE *************************
; code below here will be destroyed after init
; ***************************************************************
res_end:
init:
        push cs
        pop ds
        mov dx, install_msg
        mov ah, 0x09
        int 0x21

        ; fix bpb array pointer #0
        mov word [cs:bpb_array + 2], cs

        ; tell DOS we support one unit
        mov byte [es:di + initreq.nunits], 1

        ; tell DOS the break address
        mov word [es:di + initreq.brkaddr], res_end
        mov word [es:di + initreq.brkaddr + 2], cs

        ; tell DOS the BPB array
        mov word [es:di + initreq.bpb_array], bpb_array
        mov word [es:di + initreq.bpb_array + 2], cs

        ; initialize serial port COM1
        mov ah, 0
        mov al, 11100011b       ;9600 baud  111
                                ;no parity  00
                                ;one stop bit 0
                                ;8bits      11
        mov dx, 0
        int 14h

        ; set baudrate to 19200 (which is impossible with BIOS)
        cli
        mov dx, 0x3FB
        in al, dx
        or al, 0x80    ; set baud rate, 8 bits
        out dx, al
        mov dx, 0x3F8
        mov al, 6       ; 115200 / 19200 = 6
        out dx, al
        inc dx
        xor al, al
        out dx, al

        mov dx, 0x3FB
        in al, dx
        and al, 0x7F
        out dx, al
        sti
        jmp interrupt.exit

install_msg db "SerDrive 0.1 Alpha, (C)2023 A.J.Reichel", 0x0D, 0x0A, '$'



