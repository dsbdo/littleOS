;打印大量的信息
SECTION header vstart=0
    program_length: dd program_end
    code_entry:     dw start ;偏移地址
                    ;段基址
                    dd section.main_code.start
    realloc_item:   dw (header_end - main_code_seg) / 4
    
    ;程序重定位表
    ;nothing
    main_code_seg: dd section.main_code.start
    help_code_seg: dd section.help_code.start
    main_data_seg: dd section.main_data.start
    help_data_seg: dd section.help_data.start
    stack_seg:     dd section.stack.start
    header_end:
SECTION main_code align=16 vstart=0
    ;需要设置堆栈段
    ;设置数据段
    ;user program is to realize print info
    ;if the screen is full, this can scroll the screen info
 start:
    ;mov cs, [main_code_seg]
    mov es,[help_code_seg]
    mov ds, [main_data_seg]
    mov ss, [stack_seg]
    ;have problem?
    mov sp, ss
    

    ;初始化屏幕内容
    call clear
    mov ax, 0
    call set_cursor_position
    ;print string that store in main_data
    mov ax, message_end - message
    mov bx, message
    mov cx,ax

  put_string:
    ;bx 指的是第几个字符
    call put_char
    inc bx
    loop put_string
  exit:
    ;换个段执行,我需要跳到其他段去执行
  
    ;jmp far [help_code_seg]:0x0000
    ;先压入段地址
    push word es
    ;再压入偏移地址
    push word help_start
    retf
    jmp $
  put_char:
    ;cx, the char remind 
    ;ax string length
    ;should to determine that cursor
        push ax
        push bx
        push cx
        push dx
        ;extend segment register
        push es
        ;ax is store the cursor position
        ;call .get_cursor_position
    ;is carry return  
    .is_cr:
        mov al,[bx]
        cmp al,0x0d
        jnz .is_lf
        ;计算当前是第几行
        call get_cursor_position

        mov bl,80
        div bl
       
        ;余数存储在ah, al储存商
        xor ah,ah
        mov dl, 0x50
        mul dl
        call set_cursor_position
        jmp .over
    ;is new line
    .is_lf:
        ;一共是25*80=1999个字符
        cmp al, 0x0a
        jnz .put_other_char
        ;is new line, prepare to have a new line
        call get_cursor_position
        mov bl,80
        div bl
        mov dx,ax
        cmp al,24
        ;向上滚动一行
        jz .need_roll
        ;刚好满了，需要换行
        .next_row:
            ;换行
            inc al
            xor ah,ah
            mov dl,80
            mul dl
            add al,dh
            call set_cursor_position
            jmp .over
        .need_roll: 
            call roll_screen
    .put_other_char:
        ;ax store the char
        mov dl,al
        mov ax,0xb800
        mov es,ax

        call get_cursor_position

        ;ax store the 
        ;es:ax == es*16+ax
    
        mov bx,ax
        shl bx,1
        mov byte [es:bx],dl
        mov byte [es:bx+1],0x07
        inc ax
        call set_cursor_position
        call get_cursor_position
        
    .over:
        pop es
        pop dx
        pop cx
        pop bx
        pop ax
        ret
    ;ax store the cursor content
   get_cursor_position:
        ;push ax
        push bx
        push dx
        mov dx,0x3d4
        ;0x0e high 8 bit
        ;0x0f low 8 bit
        mov al,0x0e
        out dx,al
        mov dx,0x3d5
        in al,dx
        mov ah,al

        mov dx,0x3d4
        mov al,0x0f
        out dx,al
        mov dx,0x3d5
        in al,dx
        pop dx
        pop bx
        ;pop ax
        ret
   set_cursor_position:
   ;ax have store the position data
        push ax
        push bx
        push cx
        push dx
        mov bx,ax


        mov dx,0x3d4
        mov al,0x0e
        out dx,al
        mov dx,0x3d5
        mov al,bh
        out dx,al

        mov dx,0x3d4
        mov al,0x0f
        out dx,al
        mov dx, 0x3d5
        mov al,bl
        out dx,al

        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
   roll_screen:
        ;直接向上滚动一行
        push ax
        push bx
        push cx
        push dx
        push ds
        push es
        push si
        push di

        mov ax,0xb800
        mov ds,ax
        mov es,ax
        ;movsw ds:si --> es:di reference df to add si.di
        cld;set df = 0
        ;80 个字符，直接覆盖，每一个字符，后面跟随着一个格式控制字符
        mov si,0xa0
        mov di,0x00
        mov cx,1920
        rep movsw
        mov bx,3840
        mov cx,80
     .cls:
        mov word[es:bx], 0x0720
        add bx,2
        loop .cls

        mov ax,1920
        call set_cursor_position;

        pop di
        pop si
        pop es
        pop ds
        pop dx
        pop cx
        pop bx
        pop ax
        ret
  clear:
    ;将整个屏幕清空,25*80 = 2000
    push ax
    push cx
    push es
    mov cx,2000
    mov ax,0xb800
    mov es,ax
    @sub_clear:
        mov ax,cx
        sub al,1
        shl ax,1
        ;没有关系的，因为最大只是4000
        mov bx,ax
        mov byte [es:bx],0x00
        mov byte [es:bx+1],0x00
        loop @sub_clear
    pop es
    pop cx
    pop ax
    ret
SECTION help_code align=16 vstart=0
    help_start:
        ;call clear
        ;mov ax,[stack_segment]
        ;设置堆栈段
        ;这里处理0x70号中断
        mov al,0x70
        mov bl,4
        mul bl
        ;计算中断向量表地址
        mov bx,ax

        cli ;屏蔽中断

        push es
        mov ax,0x0000
        mov es,ax
        mov word[es:bx], new_int_0x70;偏移地址
        mov word[es:bx+2],cs           ;段地址
        pop es


        ;处理RTC寄存器B
        mov al,0x0b
        or al,0x80 ;屏蔽NMI中断
        out 0x70,al
        mov al,0x12 ;设置0x0b寄存器，禁止周期性中断，开放更新后中断，BCD码，24小时制
        out 0x71,al

        ;设置RTC寄存器C，复位未决的中断状态
        mov al,0x0c
        out 0x70,al
        in al,0x71

        ;读取8259芯片的IMR寄存器, 清除bit 0 位
        in al,0xa1
        and al,0xfe
        out 0xa1,al ;写回寄存器

        ;开中断
        sti

        push es
        mov ax,0xb800
        mov es,ax
        mov byte [es:12*160 + 33*2],'@'       ;屏幕第12行，35列
        pop es
    idle:
        hlt
        mov ax,0xb800
        mov es,ax
        not byte [es:12*160 + 33*2+1]         ;反转显示属性 
        jmp idle



        jmp $
    disp_time:
        push ax
        push bx
        push cx
        push dx
        push es
        
            ;阻断NMI
        .waits:
            mov al,0x0a ;表示准备读取0x0a寄存器
            or al,0x80 ;用以阻断NMI，为1时阻断
            out 0x70,al
            in al,0x71
            test al,0x80 ;对二者进行与操作，如果第七位是1的话，证明时间在更新，需要等待
            jnz .waits

            xor al,al
            or al,0x80 ;读取秒，之所以0x80,是为了关闭NMI
            out 0x70,al
            in al,0x71
            push ax

            ;读取分钟
            mov al,0x02
            or al,0x80
            out 0x70,al
            in al,0x71
            push ax

            ;读取小时
            mov al,0x04
            or al,0x80
            out 0x70,al
            in al,0x71
            push ax

            ;读取寄存器0x0c,开放NMI
            mov al,0x0c
            out 0x70,al
            in al,0x71

            mov ax,0xb800
            mov es,ax

            pop ax
            call bcd_2_ascii
            ;12行36列开始显示
            mov bx,12*160 + 36*2

            mov [es:bx],ah
            mov byte [es:bx+1], 0x07
            mov [es:bx+2],al
            mov byte [es:bx+3],0x07
            mov al,':'
            mov [es:bx+4],al
            mov byte [es:bx+5],0x07
            not byte [es:bx+5]                 ;反转显示属性 

            pop ax
            call bcd_2_ascii
            mov [es:bx+6],ah
            mov byte [es:bx+7],0x07
            mov [es:bx+8],al
            mov byte [es:bx+9],0x07

            mov al,':'
            mov [es:bx+10],al                  ;显示分隔符':'
            mov byte [es:bx+11],0x07
            not byte [es:bx+11]                ;反转显示属性

            pop ax
            call bcd_2_ascii
            mov [es:bx+12],ah
            mov [es:bx+14],al    

            ;中断结束命令EOI
            mov al,0x20
            out 0xa0,al ;向slave片发送
            out 0x20,al ;向master片发送


        pop es
        pop dx
        pop cx
        pop bx
        pop ax
        iret
    disp_keyboard_input:
        ret
    bcd_2_ascii:
        ;使用四位表示一个十进制
        mov ah,al
        and al,0x0f ;仅保留低四位
        add al,0x30 ;转换为ascii码

        shr ah,4
        and ah,0x0f
        add ah,0x30
        ret
        
        ;显示当前时间，每一秒跳动一次
        ;接收键盘输入，在屏幕上打印当前键盘输入内容
SECTION main_data align=16 vstart=0
;0x0d \r 0x0d \n 0x0a
    message: db 'a',0x0a
             db 'b'
             db 0x0d, 0x0a
             db 'c'
             db 0x0a
             db '[0DD E'
             db 0x0d, 0x0a
             db 'e'
             db 0x0d
             db 'f'
    message_end:
SECTION help_data align=16 vstart=0

SECTION stack align=16 vstart=0
    resb 256
    stack_end:
    db 'helloWorld'
SECTION trail align=16
    program_end: