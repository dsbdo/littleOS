;this code is to reliaze a system load to load user program
;it's correct to call is mbr
app_start_block equ 100
SECTION main align=16 vstart=0x7c00
        ;set the segment register
        mov ax, 0x0000
        mov ds,ax
        mov cs,ax
        ;init the stack register
        mov ss, ax
        mov sp, ax
        ;address is 32 bit,need ax, dx to record the address
        mov ax, [app_physical_addr]
        mov dx, [app_physical_addr+0x02]
        mov bx, 16
        div bx
        mov bx, app_start_block
        call .read_block_from_disk
        ;analysis the block read
        


        ;load the user program and jmp to the user program
        ;para is address
    .read_block_from_disk:


;record the user program address
app_physical_addr: dd  0x10000