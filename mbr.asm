;32位主引导扇区代码
;初始化栈
mov ax, cs
mov ss, ax
mov sp, 0x7c00

;计算GDT所在的逻辑段地址
mov ax, [cs:gdt_base+0x7c00]
mov dx, [cs:gdt_base+0x7c00+0x02]
mov bx, 16
div bx
;ds指向GDT的段地址
mov ds, ax
;bx 指向的是偏移地址
mov bx, dx

;初始化段描述符,第一个为空描述符
mov dword [bx+0x00], 0x00
mov dword [bx+0x04], 0x00

;创建#1描述符，保护模式下的代码段描述符
;31-24 段基地址 G D/B L AVL 19-16段界限 P DPL S TYPE 23-16段基地址
;15-0 段基地址 15-0段界限
;段基地址： 0x00007c00, 段界限： 0x00001ff 表示该段是512byte S=1 代码段或数据段， D=1 32位的段 P=1该段存在 DPL=0 特权级最高，TYPE=1000 只执行代码段
mov dword [bx+0x08],0x7c0001ff
mov dword [bx+0x0c],0x00409800

;创建#2显示缓冲区的的数据段
;0x000b8000 段界限：2000*2 = 4000 byte
;S=1, D=1 P=1 DPL=0 TYPE=0010, 可读可写段
mov dword [bx+0x10],0x8000ffff;1MB
mov dword [bx+0x14],0x0040920b;

;创建#3描述符，初始化堆栈段描述符
mov dword [bx+0x18],0x00007a00 ;ESP所允许的最小值 0x07a01 
mov dword [bx+0x1c],0x00409600
;初始化GDTR内容
mov word [cs:gdt_size+0x7c00],31 ;描述符占的总字节数-1,因为这是一个偏移地址，所以是总长减一

lgdt [cs:gdt_size+0x7c00]

;打开A20 地址线
in al,0x92
or al,0x02
out 0x92,al
;关中断
cli 
;准备打开保护模式，需要将CR0 寄存器中PE位置位1
mov eax,cr0
or eax,1
mov cr0, eax

;下面已经进入保护模式
;0x0008 是段选择子
;15-3 是属于描述符索引， 2 TI （0，GDT ； 1，LDT） RPL特权级描述
jmp dword 0x0008:flush
;32位偏移地址
[bits 32]
flush:
    ;段选择子0x10
    mov cx, 00000000000_10_000B
    mov ds, cx
    ;屏幕上显示
         mov byte [0x00],'P'  
         mov byte [0x01], 0x07
         mov byte [0x02],'r'
         mov byte [0x03], 0x07
         mov byte [0x04],'o'
         mov byte [0x06],'t'
         mov byte [0x08],'e'
         mov byte [0x0a],'c'
         mov byte [0x0c],'t'
         mov byte [0x0e],' '
         mov byte [0x10],'m'
         mov byte [0x12],'o'
         mov byte [0x14],'d'
         mov byte [0x16],'e'
         mov byte [0x18],' '
         mov byte [0x1a],'O'
         mov byte [0x1c],'K'
    ;体验使用栈段
    mov cx, 00000000000_11_000B ;堆栈段选择子
    mov ss,cx
    mov esp,0x7c00
    mov ebp,esp
    push byte '.'

    sub ebp,4
    cmp ebp,esp
    jnz ghalt
    pop eax
    mov [0x1e], al
    mov byte [0x1f],0x07
ghalt:
    hlt
gdt_size dw 0
gdt_base dd 0x00007e00

times 510-($-$$) db 0
                 db 0x55,0xaa