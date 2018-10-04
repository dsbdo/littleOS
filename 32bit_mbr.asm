;32bit 引导扇区
;采用读硬盘模式
core_base_address equ 0x00040000
core_start_sector equ 0x00000001

mov ax, cs
mov ss, ax
mov sp,0x7c00
;计算gdt所在逻辑段地址
mov eax, [cs:pgdt+0x7c00+0x02]
xor edx, edx
mov ebx, 16
div ebx

;将eax右移四位
mov ds, eax
mov ebx, edx
;创建段描述符
         ;跳过0#号描述符的槽位 
         ;创建1#描述符，这是一个数据段，对应0~4GB的线性地址空间
         mov dword [ebx+0x08],0x0000ffff    ;基地址为0，段界限为0xFFFFF
         mov dword [ebx+0x0c],0x00cf9200    ;粒度为4KB，存储器段描述符 

         ;创建保护模式下初始代码段描述符
         mov dword [ebx+0x10],0x7c0001ff    ;基地址为0x00007c00，界限0x1FF 
         mov dword [ebx+0x14],0x00409800    ;粒度为1个字节，代码段描述符 

         ;建立保护模式下的堆栈段描述符      ;基地址为0x00007C00，界限0xFFFFE 
         mov dword [ebx+0x18],0x7c00fffe    ;粒度为4KB 
         mov dword [ebx+0x1c],0x00cf9600
         
         ;建立保护模式下的显示缓冲区描述符   
         mov dword [ebx+0x20],0x80007fff    ;基地址为0x000B8000，界限0x07FFF 
         mov dword [ebx+0x24],0x0040920b    ;粒度为字节
         
         ;初始化描述符表寄存器GDTR
         mov word [cs: pgdt+0x7c00],39      ;描述符表的界限  
         lgdt [cs:pgdt+0x7c00]

in al, 0x92
or al, 0x02
out 0x92, al
cli

mov eax, cr0
or eax, 0x01
mov cr0, eax
;进入保护模式
jmp dword 0x0010:flush


[bits 32]
flush:
        ;mov eax, 0x0008
        mov eax, 0x00000008
        mov ds, eax
        ;栈段选择子
        mov eax, 0x0018
        mov ss, eax
        xor esp, esp
        ;加载核心代码段
        push 0x80
        pop eax
        mov edi, core_base_address
        mov eax, core_start_sector
        mov ebx, edi
        call read_hard_disk

        ;判断程序大小
        mov eax,[edi]
        xor edx,edx
        mov ecx, 512
        div ecx

        or edx, edx
        jnz @1 ;有余数，证明，总共是除数加一，因为我们已经加载了一个扇区，所以不需要减一了
        dec eax
        @1:
            or eax, eax
            jz setup;如果eax为空，则已经加载完了，该核心程序就只有512字节大
            
            ;读取剩余的扇区
            mov ecx, eax
            mov eax, core_start_sector
            inc eax
        @2:
            add ebx, 512
            call read_hard_disk
            inc eax
            loop @2
    setup:
            ;指向内存gdt表地址
            mov esi,[0x7c00+pgdt+0x02]
            ;通过访问0~4G的代码段来增加gdt表, edi 指向内核代码段的开始地址
            mov edi, core_base_address
            ;建立公用例程的段描述符
            mov eax,[edi+0x04]
            mov ebx,[edi+0x08]
            
            sub ebx, eax;获取段界限
            dec ebx
            add eax, edi;段开始地址
            mov ecx,0x00409800 ;字节粒度代码段描述
            call make_gdt_descriptor
            mov [esi+0x28],eax
            mov [esi+0x2c],edx

         ;建立核心数据段描述符
         mov eax,[edi+0x08]                 ;核心数据段起始汇编地址
         mov ebx,[edi+0x0c]                 ;核心代码段汇编地址 
         sub ebx,eax
         dec ebx                            ;核心数据段界限
         add eax,edi                        ;核心数据段基地址
         mov ecx,0x00409200                 ;字节粒度的数据段描述符 
         call make_gdt_descriptor
         mov [esi+0x30],eax
         mov [esi+0x34],edx 
      
         ;建立核心代码段描述符
         mov eax,[edi+0x0c]                 ;核心代码段起始汇编地址
         mov ebx,[edi+0x00]                 ;程序总长度
         sub ebx,eax
         dec ebx                            ;核心代码段界限
         add eax,edi                        ;核心代码段基地址
         mov ecx,0x00409800                 ;字节粒度的代码段描述符
         call make_gdt_descriptor
         mov [esi+0x38],eax
         mov [esi+0x3c],edx

         ;加载core的描述符
         mov word [0x7c00+pgdt], 63

         lgdt [0x7c00+pgdt]

         ;edi+10是core中的代码入口地址
         jmp far [edi+0x10]


;------------------------------------------------------------------
read_hard_disk:
        push eax
        push ebx
        push ecx
        push edx
        ;eax 指明读取扇区
        ;ebx 指明内存地址
        push eax

        mov dx, 0x1f2
        mov al, 1
        out dx, al ;读取扇区数
        

        inc dx
        pop eax
        out dx, al

        inc dx
        shr eax, 8
        out dx, al

        inc dx
        shr eax,8
        out dx, al

        inc dx
        shr eax, 8
        or al, 0xe0 ;1110 0000
        out dx, al  ;   master

        ;0x1f7读硬盘寄存器， 0x20
        inc dx
        mov al,0x20
        out dx, al 
    .waits:
        in al, dx
        and al,0x88;0x10001000
        cmp al,0x08
        jnz .waits

        mov ecx,256
        mov dx,0x1f0
    .readw:
        in ax,dx
        mov [ebx], ax
        add ebx,2
        loop .readw

        pop edx
        pop ecx
        pop ebx
        pop eax
        ret
;------------------------------------
make_gdt_descriptor:
        ;EAX 线性基址
        ;EBX 段界限
        ;ECX 属性， 无关属性设置为 0
        ;返回EDX:EAX=完整描述符
        mov edx,eax
        shl eax,16
        or ax,bx ;描述符前三十二位构造完毕

        and edx,0xffff0000
        rol edx, 8
        bswap edx;基地址空间分配好了

        ;配置段界限高4位
        xor bx,bx
        or edx,ebx

        ;配置属性
        or edx,ecx
        ret
;------------------------------------------------
pgdt    dw 0
        dd 0x00007e00 ;GDT物理地址
times 510-($-$$) db 0
                 db 0x55,0xaa











