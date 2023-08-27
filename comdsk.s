;*****************************************************************
; COMDSK        - Com Port Disk
;                 Serialize DOS Block Device Calls
; (C) 2023/08/26        Andreas J. Reichel
;                       MIT License
;
; Assemble with         yasm -p nasm -o COMDSK.SYS
; ----------------------------------------------------------------
; v0.1 Alpha    - Use COM1, 19200 Baud, 8n1
;              
; Read protocol:  out 'R', Sec-Lo, Sec-Hi, SCount-Lo, SCount-Hi
;                 in  ACK (must be 'K')
;                 in  SCount * 512 bytes
;
; Write protocol: out 'W', Sec-Lo, Sec-Hi, SCount-Lo, SCount-Hi
;                 in  ACK (must be 'K')
;                 out SCount * 512 bytes
;
; ----------------------------------------------------------------
; Syntax:       config.sys: DEVICE=COMDSK.SYS
;               - will install the next usable drive letter
; ----------------------------------------------------------------
; See BPB for exptected image geometry and format with mtools
;
; mformat -i disk.img -r 32 -L 32 -c 16
; ----------------------------------------------------------------

org 0

; DOS 2.0 driver header
struc header
        next:     resd 1        ; links to next driver
        attr:     resw 1        ; driver attributes
        strat:    resw 1        ; pointer to strategy routine
        intr:     resw 1        ; pointer to interrupt routine
        nunits:   resb 1        ; number of supported units
        reserved: resb 7        ; unused for block drivers
endstruc

; DOS 2.0 request header
struc drivereq
        .len:    resb 1         ; len of request packet
        .unit:   resb 1         ; for which unit
        .cmd:    resb 1         ; driver command
        .status: resw 1         ; driver status
        .dosq:   resd 1         ; dos queue (unused)
        .devq:   resd 1         ; device queue (unused)
endstruc

; Init command request packet
struc initreq
        .hdr:       resb drivereq_size  ; request header
        .nunits:    resb 1              ; number of units
        .brkaddr:   resd 1              ; break address
        .bpb_array: resd 1              ; BPB pointer array
endstruc

; Media Check request packet
struc mckreq
        .hdr:       resb drivereq_size  ; request header
        .mediadesc: resb 1              ; media descriptor byte
        .return:    resb 1              ; return value
endstruc

; Build BPB request packet
struc bpbreq
        .hdr:       resb drivereq_size  ; request header
        .mediadesc: resb 1              ; media descriptor byte
        .dta:       resd 1              ; Data Transfer Area
        .bpb:       resd 1              ; Pointer to BPB
endstruc

; Read request packet
struc readreq
        .hdr:       resb drivereq_size  ; request header
        .mediadesc: resb 1              ; media descriptor byte
        .dta:       resd 1              ; Data Transfer Area
        .count:     resw 1              ; Sector Count
        .startsec:  resw 1              ; Start Sector
endstruc

; Write request packet
struc writereq
        .hdr:       resb drivereq_size  ; request header
        .mediadesc: resb 1              ; media descriptor byte
        .dta:       resd 1              ; Data Transfer Area
        .count:     resw 1              ; Sector Count
        .startsec:  resw 1              ; Start Sector
endstruc

%define ATTR_BLKDEV  (0 << 15)
%define ATTR_CHARDEV (1 << 15)
%define ATTR_IOCTL   (1 << 14)

%define STATUS_ERROR (1 << 15)
%define STATUS_BUSY  (1 << 9)
%define STATUS_DONE  (1 << 8)

%define ERR_WRITE_PROTECT    0
%define ERR_UNKNOWN_UNIT     1
%define ERR_DRIVE_NOT_ERADY  2
%define ERR_UNKNOWN_CMD      3
%define ERR_CRC_ERROR        4
%define ERR_BAD_DRIVE_REQ    5
%define ERR_SEEK_ERROR       6
%define ERR_UNKNOWN_MEDIA    7
%define ERR_SECTOR_NOT_FOUND 8
%define ERR_OUT_OF_PAPER     9
%define ERR_WRITE_FAULT     10
%define ERR_READ_FAULT      11
%define ERR_GENERAL         12

%define SERDRIVE_ACK        'K'

; This is the actual driver header (struct instance)
hdr:
istruc header
        at next,     dd -1              ; must be -1, initialized by DOS
        at attr,     dw ATTR_BLKDEV     ; BLOCK device, without IOCTL
        at strat,    dw strategy        ; pointer to driver's strat routine
        at intr,     dw interrupt       ; pointer to driver's int routine
        at nunits,   db 1               ; support 1 unit (= 1 drive letter)
        at reserved, times 7 db 0       ; unused, set to 0
iend

; Storage place for current pointer to request packet
packet_ptr dd 0

; DOS enters first strategy which stores the current es:bx pointer
; into the packet_ptr variable
strategy:
        mov [cs:packet_ptr], bx
        mov [cs:packet_ptr + 2], es
        retf

; Immediately after strategy, DOS enters the interrupt routine, which
; recovers the pointer from the packet_ptr variabe
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
        cmp si, 9                       ; we don't accept a command > 9 
        ja .bad_cmd

        shl si, 1                       ; convert to word offset
        jmp [.fntab + si]               ; jmp into function table

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
        dw media_check ;1      Media Check
        dw build_bpb   ;2      build BPB
        dw .exit       ;3      ioctl input
        dw read        ;4      input (read)
        dw .exit       ;5      non destructive input, no wait
        dw .exit       ;6      input status
        dw .exit       ;7      input flush
        dw write       ;8      output (write)
        dw write       ;9      output (write) verify

; ***************************************************************
; Media Check Command
; ***************************************************************
; Tells DOS if media has changed, currently always
; returning NOCHANGE, so that DOS doesn't reread FAT all the time

%define MEDIA_NOCHANGE     1
%define MEDIA_CHANGE      -1
%define MEDIA_MAYBECHANGED 0

media_check:
        mov byte [es:di + mckreq.return], MEDIA_NOCHANGE 
        jmp interrupt.exit

; ***************************************************************
; Build BPB command, returns a pointer to the current BPB
; ***************************************************************
; and the media descriptor byte
build_bpb:
        ; we ignore the FAT sector we got... don't read
        ; the media descriptor out of it, instead,
        ; report hard disk F8
        mov byte [es:di + bpbreq.mediadesc], 0xF8

        mov word [es:di + bpbreq.bpb], bpb
        mov word [es:di + bpbreq.bpb + 2], cs
        jmp interrupt.exit

; ***************************************************************
; Serial helper routines 
; ***************************************************************
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

; ***************************************************************
; Read Command, reads N sectors into DTA
; ***************************************************************
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

; ***************************************************************
; Write Command, writes N sectors from DTA
; ***************************************************************
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

; ***************************************************************
; Initial BPB (BIOS Parameter Block) 
; ***************************************************************
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
; ***************************************************************
; Init Command, setup break address, BPB array  and serial port
; ***************************************************************
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

        ; dos 3: read drive letter
        mov al, byte [es:di + initreq.bpb_array + 4]
        add byte [cs: drive_letter], al

        mov dx, which_drive_msg
        mov ah, 0x09
        int 0x21

        ; tell DOS the break address
        mov word [es:di + initreq.brkaddr], res_end
        mov word [es:di + initreq.brkaddr + 2], cs

        ; tell DOS the BPB array
        mov word [es:di + initreq.bpb_array], bpb_array
        mov word [es:di + initreq.bpb_array + 2], cs

%ifdef COMSERINIT

        ; initialize serial port COM1
        mov ah, 0
        mov al, 11100011b       ;9600 baud  111
                                ;no parity  00
                                ;one stop bit 0
                                ;8bits      11
        mov dx, 0
        int 14h

        push ds
        push si

        mov ax, 40h
        mov ds, ax
        mov si, 0h      ; point ds:si to BIOS data area

        lodsw           ; ax is COM1 port base
        pop si
        pop ds

        add ax, 3
        mov word [cs:serial_port], ax 
        ; set baudrate to 19200 (which is impossible with BIOS)
        cli             ; no ints while fiddling with baud rate
        mov dx, word [cs:serial_port] 
        in al, dx       ; read from 0x3FB
        or al, 0x80     ; enable divisor latch
        out dx, al
        sub dx, 3       ; = 0x3F8
        mov al, 6       ; 115200 / 19200 = 6
        out dx, al
        inc dx          ; = 0x3F9
        xor al, al
        out dx, al
        inc dx
        inc dx          ; = 0x3FB
        in al, dx
        and al, 0x7F    ; disable divisor latch
        out dx, al
        sti             ; reenable ints
%endif
        jmp interrupt.exit

install_msg db 0Ah, 0Dh
            db "SerDrive v0.1 Alpha, (C)2023 A.J.Reichel", 0x0D, 0x0A
            db "MIT License", 0x0D, 0x0A, 0x0D, 0x0A, '$'
which_drive_msg db "Installed for drive "
drive_letter db "A:", 0x0D, 0x0A, '$'


serial_port dw 0

