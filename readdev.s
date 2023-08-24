org 100h

start:
        ; open driver FCB
        mov dx, driver_fcb    ; first FCB in PSP (= 1st file parameter)
        mov ah, 0x0F    ; open with FCB
        int 0x21

        test al, al
        jnz err_openfile

        ; read sequentially from driver
        mov bx, driver_fcb 
        mov word [bx + 0x20], 0 ; set current record number
        mov dx, bx
        mov ah, 0x14    ; sequential read using FCB
        int 0x21

        ; close driver FCB
        mov dx, driver_fcb
        mov ah, 0x10
        int 0x21

        ; output data retrieved in DTA
        mov byte [0x89], '$' ; put end of string into DTA
        mov dx, 0x80    ; print what is in DTA
        mov ah, 9
        int 0x21

        

        jmp finish

err_openfile:
        mov dx, error_open_msg
        mov ah, 9
        int 0x21

finish:
        mov ah, 0x4C    ; return to DOS
        int 0x21

error_open_msg db "Could not open driver", 0Ah, 0Dh, "$"

driver_fcb:
        .drive db 0
        .fname db "SKELETON"
        .fext  db "   "
        .curblk dw 0
        .recln dw 0
        .fsize dd 0
        .fdate db 0,0
        .ftime db 0,0
        .res times 8 db 0
        .currec db 0
        .relrec dd 0
