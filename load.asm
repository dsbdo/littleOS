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
        ;segment address is store in the ax register
        mov si, app_start_block
        xor di,di
        ;di if need
        ;read one block store in the address
        call read_block_from_disk
        ;analysis the block read
        ;user program exec file format
        ;1, program length  4byte
        ;2, program entry address   2byte segment address 4 byte is segment address
        ;3，realloc address entry item num 
        ;4, segment realloc table
        ;read and determine that the program size
        mov ax, [app_physical_addr]
        mov dx, [app_physical_addr + 2]
        mov bx,16
        div bx

        mov dx, [ax + 2]
        mov ax, [ax]

        mov bx 512
        div bx
        ;determine that if the dx:ax is been divide ok
        cmp dx, 0
        jnz @1;
        ;if divide ok, that we have read one block in, so dec
        dec ax
    @1:
        cmp ax, 0
        jz direct

        push ds
        mov cx,ax ; loop time
    @2:
        ;那就继续读用户程序就好了嘛，读完之后一直完一个地方填就好了
        ;not finish......
        loop @2
        ;ax store the address of the user program address
    direct:
        ;only one block, so we can handle the user program now
        ;修改数据段基址
        mov ax, [app_physical_addr]
        mov dx,[app_physical_addr + 2]
        mov bx,16
        div bx
        ;init the data segment address
        mov ds,ax
        ;now is to change the entry address
        mov ax,[0x06]
        mov dx,[0x08]
        call calc_segment_base
        ;change the address over
        mov [0x06], ax
        mov cx,[0x0a]
        ;重定位表地址
        mov bx,0x0c
    realloc:
        mov dx,[bx + 0x02]
        mov ax, [bx]
        call calc_segment_base
        mov [bx], ax
        add bx,4
        loop realloc
        ;这里按理还是需要修改代码段地址
        jmp far [0x04]
        ;load the user program and jmp to the user program
        ;para is two ax is segment address, bx is the program block address
    read_block_from_disk:
        push ax
        push bx
        push cx
        push dx
        ;read the disk, have serveral register
        ;data   err     blockNum    0~7     8~15   16~23   1110|24~27   0x20 read mode
        ;0x1f0  0x1f1  0x1f2        0x1f3  0x1f4  0x1f5   0x1f6        0x1f7
        ; in or out op source just ax,al is ok 
        mov dx, 0x1f2;
        ;read one block
        mov ax, 0x01
        out dx, ax
        ;read block address
        inc dx
        mov ax, si
        out dx, al

        inc dx
        mov al, ah
        out dx, al

        inc dx
        mov ax, di
        out dx, al

        ;also have 4 bit 1110,0000
        inc dx
        mov al, ah
        add al, 0xe0
        out dx, al
        
        ;read op
        inc dx
        mov al,0x20
        out dx,al
     ;now need to dertimne that if the read block is over is busy wait
      .waits:
        ;0x1f7 bsy | ? | ? | ? | RED | ? | ? | ERR
        in al,dx
        and al, 0x88
        cmp al, 0x08
        jnz .waits


        ;ready read the block to memory
        mov cx, 256;
        mov dx, 0x1f0
     .readBlock:
        in ax, dx
        mov [bx], ax
        add bx, 2
        loop .readBlock

        pop dx
        pop cx
        pop bx
        pop ax
        ret
    calc_segment_base:
        ;one para that is the segment address dx:ax
        push dx
        add ax,[cs:app_physical_addr]
        adc dx,[cs:app_physical_addr+0x02]
        
        ;move the dx low 4 bit to ax high 4 bit
        shr ax, 4
        ror dx,4
        and dx,0xf000
        or ax,dx
        pop dx
        ret
    

;record the user program address
app_physical_addr: dd  0x10000
times 510-($-$$) db 0 
                db 0x55, 0xaa