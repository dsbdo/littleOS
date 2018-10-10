;这是一个主引导扇区，
;我们的主要工作：1、初始化GDT， 2、跳转进入保护模式开启分页机制， 3、加载并跳转到loader程序
;建立一个段称为 mbr段，段内汇编地址由偏移地址加上0x7c00
%include "mbr.inc"
[bits 16]
SECTION mbr vstart=0x7c00
        ;初始化堆栈
        mov ax, cs
        mov ss, ax
        mov sp, 0x7c00
        ;初始化堆栈之后，计算GDT，安装GDT描述
        ;安装描述符
        ;关中断，进入32位保护模式
        lgdt [cs:Pgdt]
        ;打开A20地址线
        in 0x92,al
        or al,0x02
        out 0x92,al

        cli
        ;打开cr0 中pe位
        mov eax, cr0
        or cr0,0x01
        mov cr0,eax

        ;跳转到代码段中执行
        jmp dword 0x0010:Flush

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
;这一个主要功能是进入保护模式，同时跳转到Loader程序中去执行

[bits 32]
Flush:  
    ;显示一段内容
    
Pgdt    dw 0x00
        dd 0x00007e00 ;gdt起始地址
;----------------------------
times 510-($-$$) db 0
                 db 0x55, 0xaa


        
