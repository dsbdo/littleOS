;还是主引导扇区，主要用以熟悉32位汇编编码
mov eax,cs
mov ss,eax
mov sp,0x7c00

;计算GDT所在的逻辑地址
mov eax, [cs:pgdt+0x7c00+0x02] ;GDT的32位线性基地址
xor edx, edx
mov ebx, 16
div ebx

;GDT的段地址
mov ds, eax
;GDT 内部偏移地址
mov ebx, edx

;手动创建#0描述符， 空描述符，处理器要求
mov dword [ebx+0x00], 0x00000000
mov dword [ebx+0x04], 0x00000000

;创建#1描述符，这是一个主代码段，也就是mbr的代码段
;基地址0x00007c00, 界限0x1FF, 
mov dword [ebx+0x08], 0x7c0001ff
mov dword [ebx+0x0c], 0x00409800

;创建#2描述符，这是一个数据段，对应0 ～ 4GB的线性地址空间
mov dword [ebx+0x10],0x0000ffff
mov dword [ebx+0x14],0x00cf9200

;创建#3描述符，这是一个数据段，是主代码段的别名
mov dword [ebx+0x18],0x7c0001ff
mov dword [ebx+0x1c],0x00409200

;创建#4描述符，这是一个栈段
mov dword [ebx+0x20], 0x7c00fffe
mov dword [ebx+0x24], 0x00cf9600

;初始化描述符表寄存器GDTR
mov word [cs:pgdt+0x7c00],39

lgdt [cs:pgdt+0x7c00]

;打开A20地址线
in al, 0x92
or al, 0x02
;打开A20
out 0x92,al 
;关中断
cli
;打开PE位
mov eax, cr0
or eax, 0x01
mov cr0, eax


;进入保护模式，刷新流水线
jmp dword 0x0008:flush
[bits 32]
flush:
    ;数据段描述符选择子
    mov eax, 0x0018
    mov ds,  eax

    ;数据段0 ~ 4GB
    mov eax, 0x0010
    mov es, eax
    mov fs, eax
    mov gs, eax

    ;栈段
    mov eax, 0x0020
    mov ss, eax
    xor esp, esp
    mov dword [es:0x0b8000], 0x072e0750
    mov dword [es:0x0b8004], 0x072e074d
    mov dword [es:0x0b8008], 0x07200720
    mov dword [es:0x0b800c], 0x076b076f

    ;冒泡排序,遍历次数
    mov ecx, pgdt - string - 1
    @1:
        push ecx
        xor bx, bx
    @2:
        mov ax, [string+bx]
        cmp ah,al
        jge @3
        xchg al,ah
        mov [string+bx],ax
    @3:
        inc bx
        loop @2
        pop ecx
        loop @1

        mov ecx, pgdt - string
        xor ebx,ebx
        ;打印字符串
    @4:
        mov ah,0x07
        mov al,[string+ebx]
        mov [es:0xb80a0+ebx*2],ax
        inc ebx
        loop @4


        hlt

    string db 'sfhakjfhasjdfhklajhflkjdashf'

    pgdt:
        dw 0
        dd 0x00007e00
    times 510-($-$$) db 0
                     db 0x55, 0xaa
