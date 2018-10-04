                                                                                                                                                                        ;以下常量定义部分。内核的大部分内容都应当固定 
         core_code_seg_sel     equ  0x38    ;内核代码段选择子
         core_data_seg_sel     equ  0x30    ;内核数据段选择子 
         sys_routine_seg_sel   equ  0x28    ;系统公共例程代码段的选择子 
         video_ram_seg_sel     equ  0x20    ;视频显示缓冲区的段选择子
         core_stack_seg_sel    equ  0x18    ;内核堆栈段选择子
         mem_0_4_gb_seg_sel    equ  0x08    ;整个0-4GB内存的段的选择子
;-------------------------------------------------------------------------------
         ;以下是系统核心的头部，用于加载核心程序 
         core_length      dd core_end       ;核心程序总长度#00

         sys_routine_seg  dd section.sys_routine.start
                                            ;系统公用例程段位置#04

         core_data_seg    dd section.core_data.start
                                            ;核心数据段位置#08

         core_code_seg    dd section.core_code.start
                                            ;核心代码段位置#0c
        ;32位系统， jmp far 先弹出4字节偏移地址， 2字节选择子地址
         core_entry       dd start          ;核心代码段入口点#10
                          dw core_code_seg_sel
        [bits 32]
;系统调用api
SECTION sys_routine vstart=0
;1、显示字符串
put_string:
        ;功能在于：显示以\0 为终止的字符串，同时移动光标
        ;输入DS:EBX = 串地址
        push ecx
    .getc:
        mov cl,[ebx]
        or  cl,cl;判断是否是字符串末尾\0
        jz  .exit
        call put_char
        inc ebx
        jmp .getc
    .exit:
        pop ecx
        retf ;段间返回
;--------------------------------------
put_char:
        ;push all register through use dword type
        pushad
        ;get the cursor position
        mov dx,0x3d4
        mov al,0x0e
        out dx,al
        inc dx
        in al,dx    ;get the high byte of cursor position
        mov ah,al

        dec dx
        mov al,0x0f
        out dx,al
        inc dx
        in al,dx
        mov bx,ax

        ;ax, bx store the cursor's position
        
        cmp cl, 0x0d ;is carriage return 
        jnz .put_0a
        mov ax,bx
        mov bl,80
        div bl
        ;al store the line index, the ah store the column index
        mul bl
        mov bx,ax
        ;set the cursor new position
        jmp .set_cursor
    .put_0a:
        cmp cl,0x0a ;is new line
        jnz .put_other
        add bx,80
        jmp .roll_screen
    .put_other:
        push es
        mov eax,video_ram_seg_sel
        mov es,eax
        shl bx, 1
        mov [es:bx],cl
        mov byte [es:bx+1],0x07
        pop es
        ;get the new cursor's position
        shr bx,1
        inc bx
    .roll_screen:
        cmp bx,2000
        jl .set_cursor
        
        push ds
        push es
        mov eax,video_ram_seg_sel
        mov ds,eax
        mov es,eax
        cld
        ;pay attention to the 32bit movsb/w/d
        mov esi,0xa0
        mov edi,0x00
        mov ecx,1920
        rep movsd
        ;clear the last line of the screen
        mov bx,3840
        mov ecx,80
    .cls:
        mov word[es:bx],0x0720
        add bx,2
        loop .cls

        pop es
        pop ds
        mov bx,1920

    .set_cursor:
        mov dx,0x3d4
        mov al,0x0e
        out dx,al

        inc dx
        mov al,bh
        out dx,al

        dec dx
        mov al,0x0f
        out dx,al

        inc dx
        mov al,bl
        out dx,al

        popad
        ret
;--------------------------------------
read_hard_disk_0:                           ;从硬盘读取一个逻辑扇区
                                            ;EAX=逻辑扇区号
                                            ;DS:EBX=目标缓冲区地址
                                            ;返回：EBX=EBX+512
         push eax 
         push ecx
         push edx
      
         push eax
         
         mov dx,0x1f2
         mov al,1
         out dx,al                          ;读取的扇区数

         inc dx                             ;0x1f3
         pop eax
         out dx,al                          ;LBA地址7~0

         inc dx                             ;0x1f4
         mov cl,8
         shr eax,cl
         out dx,al                          ;LBA地址15~8

         inc dx                             ;0x1f5
         shr eax,cl
         out dx,al                          ;LBA地址23~16

         inc dx                             ;0x1f6
         shr eax,cl
         or al,0xe0                         ;第一硬盘  LBA地址27~24
         out dx,al

         inc dx                             ;0x1f7
         mov al,0x20                        ;读命令
         out dx,al

  .waits:
         in al,dx
         and al,0x88
         cmp al,0x08
         jnz .waits                         ;不忙，且硬盘已准备好数据传输 

         mov ecx,256                        ;总共要读取的字数
         mov dx,0x1f0
  .readw:
         in ax,dx
         mov [ebx],ax
         add ebx,2
         loop .readw

         pop edx
         pop ecx
         pop eax
      
         retf                               ;段间返回 
;--------------------------------------
put_hex_dword:
        ;辅助调试函数
        pushad
        push ds
        
        mov ax,core_data_seg_sel
        mov ds,ax

        ;point to the core data transform table
        mov ebx,bin_hex
        mov ecx,8 ;what is the effect of this opreand
    .xlt:
        rol edx,4
        mov eax,edx
        and eax,0x0000000f
        xlat;xlat transform look at table mean al,ds:ebx+al
        push ecx
        mov cl,al
        call put_char
        pop ecx

        loop .xlt
        pop ds
        popad
        retf
;------------------------------------
allocate_memory:
;allocate memory
;input: ECX  hope to allocate byte of memory
;output: ECX start address of the allocate memory
        push    ds
        push    eax
        push    ebx

        mov     eax,core_data_seg_sel
        mov     ds,eax
        mov     eax,[ram_alloc]
        
        ;there must check the memory is ok or not
        add     eax,ecx;next time to allocate start address
        mov     ecx,[ram_alloc]

        mov     ebx,eax
        and     ebx,0xfffffffc
        add     ebx,4
        test    eax,0x00000003 ;to asure that is memory is 4 byte
        ;if ZERO flag == 0, EAX=EBX; else nothing happen
        cmovnz  eax,ebx
        mov     [ram_alloc],eax

        pop     ebx
        pop     eax
        pop     ds
        retf        
;---------------------------------------------------------------
set_up_gdt_descriptor:
        ;install a new gdt descriptor in gdt
        ;input edx:eax=descriptor
        ;output cx=descriptor selector
        push    eax
        push    ebx
        push    edx
        push    ds
        push    es

        ;switch to data segment
        mov     ebx,core_data_seg_sel
        mov     ds,ebx
        ;store gdt info to [pgdt]
        sgdt    [pgdt]

        
        mov     ebx,mem_0_4_gb_seg_sel
        mov     es,ebx
        ;mov with zero extend
        movzx   ebx,word[pgdt]
        inc     bx;gdt sum bytes, next descriptor offset
        add     ebx,[pgdt+0x02]

        mov     [es:ebx],eax
        mov     [es:ebx+4],edx
        add     word [pgdt],8

        lgdt    [pgdt]

        mov     ax,[pgdt]
        xor     dx,dx
        mov     bx,8
        div     bx
        mov     cx,ax
        ;cx get the selector offset
        shl     cx,3

        pop     es
        pop     ds
        pop     edx
        pop     ebx
        pop     eax
        retf
;--------------------------------------------
make_seg_descriptor:
        ;EAX base address
        ;EBX offset 
        ;ECX addtribute
        mov     edx,eax
        shl     eax,16
        or      ax,bx

        and     ebx,0xffff0000
        rol     edx,8
        bswap   edx

        xor     bx,bx
        or      edx,ebx
        
        or      edx,ecx
        retf
;-----------------------------------------------------
;===========================================================
SECTION core_data vstart=0                  ;系统核心的数据段
;-------------------------------------------------------------------------------
         pgdt             dw  0             ;用于设置和修改GDT 
                          dd  0

         ram_alloc        dd  0x00100000    ;下次分配内存时的起始地址

         ;符号地址检索表
         salt:
         salt_1           db  '@PrintString'
                     times 256-($-salt_1) db 0
                          dd  put_string
                          dw  sys_routine_seg_sel

         salt_2           db  '@ReadDiskData'
                     times 256-($-salt_2) db 0
                          dd  read_hard_disk_0
                          dw  sys_routine_seg_sel

         salt_3           db  '@PrintDwordAsHexString'
                     times 256-($-salt_3) db 0
                          dd  put_hex_dword
                          dw  sys_routine_seg_sel

         salt_4           db  '@TerminateProgram'
                     times 256-($-salt_4) db 0
                          dd  return_point
                          dw  core_code_seg_sel

         salt_item_len   equ $-salt_4
         salt_items      equ ($-salt)/salt_item_len

         message_1        db  '  If you seen this message,that means we '
                          db  'are now in protect mode,and the system '
                          db  'core is loaded,and the video display '
                          db  'routine works perfectly.',0x0d,0x0a,0

         message_5        db  '  Loading user program...',0
         
         do_status        db  'Done.',0x0d,0x0a,0
         
         message_6        db  0x0d,0x0a,0x0d,0x0a,0x0d,0x0a
                          db  '  User program terminated,control returned.',0

         bin_hex          db '0123456789ABCDEF'
                                            ;put_hex_dword子过程用的查找表 
         core_buf   times 2048 db 0         ;内核用的缓冲区

         esp_pointer      dd 0              ;内核用来临时保存自己的栈指针     

         cpu_brnd0        db 0x0d,0x0a,'  ',0
         cpu_brand  times 52 db 0
         cpu_brnd1        db 0x0d,0x0a,0x0d,0x0a,0
;=====================================================
SECTION core_code vstart=0
load_relocate_program:
            push    ebx
            push    ecx
            push    edx
            push    esi
            push    edi
            push    ds
            push    es
            ;switch to core data segment
            mov     eax,core_data_seg_sel
            mov     ds,eax
            
            ;get the program begin data
            mov     eax,esi
            mov     ebx,core_buf
            call    sys_routine_seg_sel:read_hard_disk_0

            ;determine the user program length
            mov     eax,[core_buf]
            ;512 byte order
            mov     ebx,eax
            and     ebx,0xfffffe00
            add     ebx,512

            test    eax,0x000001ff
            ;if ZF==0 eax=ebx
            cmovnz  eax,ebx

            ;applicate memory 
            mov     ecx,eax
            call    sys_routine_seg_sel:allocate_memory
            mov     ebx,ecx;ebx store the memory start address
            
            ;store the user program start address
            push    ebx
            xor     edx,edx
            mov     ecx,512
            div     ecx
            mov     ecx,eax;the sector sum
            mov     eax,mem_0_4_gb_seg_sel
            mov     ds,eax

            mov     eax,esi;start sector num
    .b1:
            call sys_routine_seg_sel:read_hard_disk_0
            inc eax
            loop .b1
            ;set the user program segment descriptor
            pop edi
            mov eax, edi
            mov ebx,[edi+0x04]
            dec ebx
            mov ecx,0x00409200;byte granularity data segment descriptor
            call sys_routine_seg_sel:make_seg_descriptor
            call sys_routine_seg_sel:set_up_gdt_descriptor
            ;cx is descriptor index
            mov [edi+0x04],cx
            
            ;create the user program code segment descriptor
            mov eax,edi
            add eax,[edi+0x14]
            mov ebx,[edi+0x18]
            dec ebx
            mov ecx,0x00409800;byte granularity code segment descriptor
            call sys_routine_seg_sel:make_seg_descriptor
            call sys_routine_seg_sel:set_up_gdt_descriptor
            mov [edi+0x14],cx

 ;建立程序数据段描述符
         mov eax,edi
         add eax,[edi+0x1c]                 ;数据段起始线性地址
         mov ebx,[edi+0x20]                 ;段长度
         dec ebx                            ;段界限
         mov ecx,0x00409200                 ;字节粒度的数据段描述符
         call sys_routine_seg_sel:make_seg_descriptor
         call sys_routine_seg_sel:set_up_gdt_descriptor
         mov [edi+0x1c],cx                  ;回填加载程序重定向之后的数据段地

         ;set up stack segment descriptor
         mov ecx,[edi+0x0c]
         mov ebx,0x000fffff
         sub ebx,ecx
         mov eax,4096
         mul dword[edi+0x0c]
         mov ecx,eax
         call sys_routine_seg_sel:allocate_memory
         add eax,ecx
         mov ecx,0x00c09600
         call sys_routine_seg_sel:make_seg_descriptor
         call sys_routine_seg_sel:set_up_gdt_descriptor
         mov [edi+0x08],cx

         ;reallocate SALT
         mov eax,[edi+0x04]
         mov es,eax
         mov eax,core_data_seg_sel
         mov ds,eax
         cld

         mov ecx,[es:0x24]
         mov edi,0x28
    .b2:
            push ecx
            push edi
            mov ecx,salt_items
            mov esi,salt
    .b3:
            push edi
            push esi
            push ecx
            ;cmpsb是字符串比较指令，把ESI指向的数据与EDI指向的数一个一个的进行比较。
            ;当repe cmpsb配合使用时就是字符串比较啦，当相同时继续比较，不同时不比较 
            mov ecx,64
            repe cmpsd
            jnz .b4
            mov eax,[esi]                      ;若匹配，esi恰好指向其后的地址数据
            mov [es:edi-256],eax               ;将字符串改写成偏移地址 
            mov ax,[esi+4]
            mov [es:edi-252],ax                ;以及段选择子 
  .b4:
      
         pop ecx
         pop esi
         add esi,salt_item_len
         pop edi                            ;从头比较 
         loop .b3
      
         pop edi
         add edi,256
         pop ecx
         loop .b2

         mov ax,[es:0x04]

         pop es                             ;恢复到调用此过程前的es段 
         pop ds                             ;恢复到调用此过程前的ds段
      
         pop edi
         pop esi
         pop edx
         pop ecx
         pop ebx
      
         ret            
;----------------------------------------
start:
        mov ecx,core_data_seg_sel
        mov ds,ecx
        mov ebx,message_1
        call sys_routine_seg_sel:put_string
        ;显示处理器品牌信息
         mov eax,0x80000002
         cpuid
         mov [cpu_brand + 0x00],eax
         mov [cpu_brand + 0x04],ebx
         mov [cpu_brand + 0x08],ecx
         mov [cpu_brand + 0x0c],edx
      
         mov eax,0x80000003
         cpuid
         mov [cpu_brand + 0x10],eax
         mov [cpu_brand + 0x14],ebx
         mov [cpu_brand + 0x18],ecx
         mov [cpu_brand + 0x1c],edx

         mov eax,0x80000004
         cpuid
         mov [cpu_brand + 0x20],eax
         mov [cpu_brand + 0x24],ebx
         mov [cpu_brand + 0x28],ecx
         mov [cpu_brand + 0x2c],edx

        mov ebx,cpu_brnd0
         call sys_routine_seg_sel:put_string
         mov ebx,cpu_brand
         call sys_routine_seg_sel:put_string
         mov ebx,cpu_brnd1
         call sys_routine_seg_sel:put_string

         mov ebx,message_5
         call sys_routine_seg_sel:put_string
         mov esi,50                          ;用户程序位于逻辑50扇区 
         call load_relocate_program
      
         mov ebx,do_status
         call sys_routine_seg_sel:put_string
      
         mov [esp_pointer],esp               ;临时保存堆栈指针
       
         mov ds,ax
      
         jmp far [0x10]                      ;控制权交给用户程序（入口点）
                                             ;堆栈可能切换 

return_point:                                ;用户程序返回点
         mov eax,core_data_seg_sel           ;使ds指向核心数据段
         mov ds,eax

         mov eax,core_stack_seg_sel          ;切换回内核自己的堆栈
         mov ss,eax 
         mov esp,[esp_pointer]

         mov ebx,message_6
         call sys_routine_seg_sel:put_string

         ;这里可以放置清除用户程序各种描述符的指令
         ;也可以加载并启动其它程序
       
         hlt
            
;===============================================================================
SECTION core_trail
;-------------------------------------------------------------------------------
core_end:
   