;这是一个主引导扇区，
;我们的主要工作：1、初始化GDT， 2、跳转进入保护模式开启分页机制， 3、加载并跳转到loader程序
;建立一个段称为 mbr段，段内汇编地址由偏移地址加上0x7c00
%include "mbr.inc"
[bits 16]
SECTION mbr vstart=0x00
        ;初始化堆栈
        mov ax, cs
        mov ss, ax
        mov sp, 0x7c00
        ;初始化堆栈之后，计算GDT，安装GDT描述
        ;安装描述符
        mov edi, [Pgdt+2+0x7c00]
        ;安装空描述符
        mov eax, 0x00
        mov ebx, 0x00
        mov ecx, 0x00
        call MakeGDT
        mov [edi], ebx
        mov [edi+0x04], eax

        ;安装0~4G数据段描述符
        mov eax, 0x00000000
        mov ebx, 0x000fffff
        mov ecx, DA_DATA_RW
        or ecx, DA_4KB_32bit
        call MakeGDT
        mov [edi+GDT_DATA_4G_DESC_INDEX],ebx
        mov [edi+GDT_DATA_4G_DESC_INDEX+0x04], eax

        ;安装mbr只执行代码段
        mov eax, 0x00007c00
        mov ebx, 0x000001ff
        mov ecx, DA_CODE_E
        or ecx, DA_BYTE_32bit
        call MakeGDT
        mov [edi+GDT_MBR_DESC_INDEX], ebx
        mov [edi+GDT_MBR_DESC_INDEX+0x04], eax

        ;安装栈段代码段
        mov eax, 0x00007c00
        mov ebx, 0x000fffff
        mov ecx, DA_DATA_RW_DOWN
        or ecx, DA_BYTE_32bit
        call MakeGDT
        mov [edi+GDT_STACK_DESC_INDEX], ebx
        mov [edi+GDT_STACK_DESC_INDEX+0x04], eax

        ;安装显存段描述符
        mov eax, 0x000b8000
        mov ebx, 0x00007fff
        mov ecx, DA_DATA_RW
        or ecx,  DA_BYTE_32bit
        call MakeGDT
        mov [edi+GDT_VIDEO_DESC_INDEX], ebx
        mov [edi+GDT_VIDEO_DESC_INDEX+0x04], eax

        ;忘记在这里更新大小了
        mov word[cs:Pgdt+0x7c00],39
        ;关中断，进入32位保护模式
        lgdt [cs:Pgdt+0x7c00]
        ;打开A20地址线
        in al,0x92
        or al,0x02
        out 0x92,al

        cli
        ;打开cr0 中pe位
        mov eax, cr0
        or eax,0x01
        mov cr0,eax

        ;跳转到代码段中执行
        jmp dword 0x0010:Flush


;这一个主要功能是进入保护模式，同时跳转到Loader程序中去执行

[bits 32]
 Flush:  
    ;显示一段内容
    mov cx, GDT_VIDEO_DESC_INDEX
    mov ds,cx
    
    mov byte [0x00], 'H'  
    mov byte [0x02], 'e'  
    mov byte [0x04], 'l'  
    mov byte [0x06], 'l'
    mov byte [0x08], 'o'  
    mov byte [0x0a], ' '  
    mov byte [0x0c], 'W'  
    mov byte [0x0e], 'o'
    mov byte [0x10], 'r'  
    mov byte [0x12], 'l'  
    mov byte [0x14], 'd' 
    jmp $

[bits 16]
    MakeGDT:
        ;需要三个参数，第一个段基址eax, 第二个段界限ebx， 第三个段属性ecx
        ;将重新组合的描述符储存在eax:ebx中
        mov edx, eax
        and edx, 0x0000ffff
        rol edx, 16
        or  dx, bx
        ;edx 存储着低4byte

        and eax, 0xffff0000
        rol eax, 8
        bswap eax
        or eax,ecx

        ;填充段界限的19-16位
        and ebx,0x000f0000
        or eax,ebx 

        mov ebx,edx
        ret
    ;------------------------
    ReadHardDisk:
        ret
    ;
Pgdt    dw 0x00
        dd 0x00007e00 ;gdt起始地址
;----------------------------
times 510-($-$$) db 0
                 db 0x55, 0xaa


        
