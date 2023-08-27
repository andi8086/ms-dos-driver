# optional rom for IBM-PC, BIOS >= V3

org 0h

boot_sig: DW 0AA55h
rom_size: DB 1          ; multiple of 512 sectors

start:
        push ax
        push bx
        push cx
        push dx
        push ds
        push es
        push si
        push di

        mov ax, cs
        mov ds, ax

        mov si, bios_msg
        call print

        xor ax, ax
        mov ds, ax
        mov es, ax
        mov ax, 13h
        shl ax, 1
        shl ax, 1
        mov si, ax

        mov ax, 78h
        shl ax, 1
        shl ax, 1
        mov di, ax

        cld
        movsw           ; backup old int 0x13 to int 0x78
        movsw
        sub si, 4
        mov word [ds:si], modint13
        mov word [ds:si + 2], cs        ; install new int 13

        call init_com1  ; init COM1 to 19200 baud

        pop di
        pop si
        pop es
        pop ds
        pop dx
        pop cx
        pop bx
        pop ax

        retf                            ; return to ROM BIOS


print:  mov ah, 0Eh
        mov bh, 0
.next
        lodsb
        test al, al
        jz exit_print
        int 10h
        jmp .next
exit_print:
        ret

bios_msg: db "COMDSK Boot Rom, v0.1 - (C) 2023/08/27 Andreas J. Reichel",
          db 0Ah, 0Dh, 00h

modint13:
        cmp dl, 0               ; check for drive A access
        je custom_int13         ; call our BIOS
        int 78h                 ; call old int13
        iret

custom_int13:
        push si
        push ax
        xchg al, ah
        mov si, ax
        and si, 0xFF
        shl si, 1               ; word index for function
        pop ax 

        cmp si, 0x0A
        ja .invalid_cmd
        jmp [cs:.fntable + si]
.exit:
        clc
        jmp .return
.invalid_cmd:
        stc
.return:
        pop si
        iret

.fntable:
        dw reset                ; 00
        dw get_status           ; 01
        dw read_sectors         ; 02    - implemented
        dw write_sectors        ; 03    - implemented
        dw verify_sectors       ; 04
        dw format_track         ; 05
        dw format_track_bad     ; 06
        dw format_drive_from_track ; 07
        dw read_drive_params    ; 08
        dw init_drive_pair_props ; 09
        dw read_long_sectors    ; 0A

write_s:
        push ax
        push dx
        mov ah, 1
        mov dx, 0
        int 14h
        pop dx
        pop ax
        ret

read_s:
        push dx
        mov ah, 2
        mov dx, 0
        int 14h
        pop dx
        ret

init_com1:
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
        ; set baudrate to 19200 (which is impossible with BIOS)
        cli             ; no ints while fiddling with baud rate
        mov dx, ax 
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
        ret

; ----------------------------------
reset:

        jmp custom_int13.exit

get_status:
        jmp custom_int13.exit

read_sectors:
        sti
        push bp
        push ax
        push cx
        push dx
        push bx
        push ax
        mov al, 'r'
        call write_s
        pop ax          ; sectors to read
        mov bp, ax
        and bp, 0xFF
        call write_s
        mov al, ch      ; cylinder
        call write_s
        mov al, dh      ; head
        call write_s
        mov al, cl      ; sector
        call write_s
        pop bx

        push di
        cld
        mov di, bx
.next_sec:
        mov cx, 512
.next_byte:
        push cx
        call read_s
        pop cx
        stosb
        loop .next_byte
        dec bp
        cmp bp, 0
        jne .next_sec
        pop di

        pop dx
        pop cx
        pop ax
        pop bp
        clc
        mov ah, 0       ; return code
        jmp custom_int13.exit
        
write_sectors:
        sti
        push bp
        push ax
        push cx
        push dx
        push bx
        push ax
        mov al, 'w'
        call write_s
        pop ax          ; sectors to read
        mov bp, ax
        and bp, 0xFF
        call write_s
        mov al, ch      ; cylinder
        call write_s
        mov al, dh      ; head
        call write_s
        mov al, cl      ; sector
        call write_s
        pop bx
        push ds
        mov ax, es
        mov ds, ax
        push si
        cld
        mov si, bx
.next_sec:
        mov cx, 512
.next_byte:
        lodsb
        push cx
        call write_s
        pop cx
        loop .next_byte
        dec bp
        cmp bp, 0
        jne .next_sec
        pop si
        pop ds

        pop dx
        pop cx
        pop ax
        pop bp
        clc
        mov ah, 0       ; return code
        jmp custom_int13.exit

verify_sectors:
        mov al, 'V'
        call write_s
        jmp custom_int13.exit

format_track:
        mov al, 'F'
        call write_s
        jmp custom_int13.exit
        
format_track_bad:
        mov al, 'E'
        call write_s
        jmp custom_int13.exit

format_drive_from_track:
        mov al, 'f'
        call write_s
        jmp custom_int13.exit
        
read_drive_params:
        mov al, 'P'
        call write_s
        jmp custom_int13.exit
        
init_drive_pair_props:
        mov al, '2'
        call write_s
        jmp custom_int13.exit

read_long_sectors:
        mov al, 'L'
        call write_s
        jmp custom_int13.exit


section _cksum start=0x1FF align=1
cksum: DB 0

