# optional rom for IBM-PC, BIOS >= V3

org 0h

boot_sig: DW 0AA55h
rom_size: DB 2          ; multiple of 512 sectors

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
        retf 2 

custom_int13:
        push si
        pushf
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
        popf
        clc
        jmp .return
.invalid_cmd:
        popf
        stc
.return:
        pop si
        retf 2 

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

;******************************************************
        ; dx = port address
write_s:
        push ax
        push dx

        add dx, 5
wait_transmitter_empty:
        in al, dx
        test al, 20h
        jz wait_transmitter_empty
        pop dx
        pop ax
        out dx, al
        ret

;******************************************************
        ; dx = port address
read_s:
        push dx
        add dx, 5 
wait_for_data:
        in al, dx
        test al, 1
        jz wait_for_data
        pop dx
        in al, dx
        ret

;******************************************************
init_com1:
        ; initialize serial port COM1
        push ds
        push si

        mov ax, 40h
        mov ds, ax
        mov si, 0h      ; point ds:si to BIOS data area

        lodsw           ; ax is COM1 port base
                        ; remove COM1 port base from BDA,
                        ; so that DOS does not detect it anymore

        mov word [ds:si], 0 
        
        mov si, 0xF0    ; user reserved in BDA, should be usable,
                        ;       if not, we have a problem
        mov word [ds:si], ax
                        ; now we stored COM1 port address at 40:F0,
                        ;       comdrv.sys will get it from there
        pop si
        pop ds
        inc ax
        cli             ; we assume we have 3F8 in ax, will work
                        ;       for other COM port addresses also
        mov dx, ax      ; 3F9
        mov al, 0
        out dx, al      ; disable COM1 interrupts
        inc dx
        inc dx
                        ; set baudrate to 19200
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
        mov al, 3       ; 8 data bits, 1 stop bit, no parity
        out dx, al
        inc dx          ; = 0x3FC
        xor al, al
        out dx, al      ; clear DTR, RTS, out1, out2, loop
        sti             ; reenable ints

        ret

; ----------------------------------
reset:

        jmp custom_int13.exit

get_status:
        jmp custom_int13.exit

load_com_base:
        push ds
        push ax
        mov ax, 0x40
        mov ds, ax
        push si 
        mov si, 0xF0
        mov dx, word [ds:si]    ; dx = COM port base
        pop si
        pop ax
        pop ds
        ret


read_sectors:
;        sti
        push bp
        push ax
        push cx
        push dx

        mov bp, ax
        and bp, 0xFF    ; sectors to read

        call load_com_base
        mov al, 'r'
        call write_s
        
        mov ax, bp
        call write_s
        mov al, ch      ; cylinder
        call write_s

        ; we need saved dx here, which got overwritten by load_com_base
        pop dx
        push dx

        mov al, dh      ; head
      
        call load_com_base

        call write_s
        mov al, cl      ; sector
        call write_s

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
;        sti
        push bp
        push ax
        push cx
        push dx

        mov bp, ax
        and bp, 0xFF    ; sectors to write

        call load_com_base

        mov al, 'w'
        call write_s
       
        mov ax, bp
        call write_s
        mov al, ch      ; cylinder
        call write_s

        ; we need stored dx here which got overwritten by load_com_base

        pop dx
        push dx

        mov al, dh      ; head

        call load_com_base

        call write_s
        mov al, cl      ; sector
        call write_s

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
        ;mov al, 'V'
        ;call write_s
        mov ah, 0
        jmp custom_int13.exit

format_track:
        call load_com_base
        mov al, 'F'
        call write_s
        jmp custom_int13.exit
        
format_track_bad:
        call load_com_base
        mov al, 'E'
        call write_s
        jmp custom_int13.exit

format_drive_from_track:
        call load_com_base
        mov al, 'f'
        call write_s
        jmp custom_int13.exit
        
read_drive_params:
        call load_com_base
        mov al, 'P'
        call write_s
        jmp custom_int13.exit
        
init_drive_pair_props:
        call load_com_base
        mov al, '2'
        call write_s
        jmp custom_int13.exit

read_long_sectors:
        call load_com_base
        mov al, 'L'
        call write_s
        jmp custom_int13.exit


section _cksum start=0x3FF align=1
cksum: DB 0

