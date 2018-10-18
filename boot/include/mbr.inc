;This is some function to support make gdt descriptor
;%1 is the base address, %2 is the limit of the gdt, %3 is the attribute
%macro GdtDescriptor 3
dw %2 & 0xffff
dw %1 & 0xffff
db (%1 >> 16) & 0xff
dw (((%2 & 0x000f0000 ) >> 8) | (%3 & 0x0000f0ff))
db (%1 >> 24) & 0xff
%endmacro


;描述符选择子索引 
GDT_DATA_4G_DESC_INDEX equ 0x0008
GDT_MBR_DESC_INDEX     equ 0x0010
GDT_STACK_DESC_INDEX   equ 0x0018
GDT_VIDEO_DESC_INDEX   equ 0x0020
GDT_NORMAL_DESC_INDEX equ 0x0028
GDT_16CODE_DESC_INDEX equ 0x0030
;描述符类型常量描述 TYPE 四位
;描述符P DPL S位常量
; S 位 0 表示系统段（调用门，中断门）， 1 表示存储段（数据段或者代码段），不是很明白这里的系统段与存储段的区别
;描述符粒度描述G      D/B                 L       AVL
;GDT段颗粒度，操作数大小，是否64bit，AVL冗余位
;DA 表示descriptor Attribute

 ;32位操作数， 段的粒度位byte
DA_BYTE_32bit equ 0x00400000

;32位操作数，段粒度位4KB
DA_4KB_32bit  equ 0x00c00000



;TYPE 描述
;             粒度    默认操作指令长度    64bit
; isData   E/C  W/R  A
;数据段第一位是0
;代码段第二位是1

;	数据段类型	类型值		说明
;			----------------------------------
;			0		只读 
;			1		只读、已访问 
;			2		读/写 
;			3		读/写、已访问 
;			4		只读、向下扩展 
;			5		只读、向下扩展、已访问 
;			6		读/写、向下扩展 
;			7		读/写、向下扩展、已访问 
;
;		
;			类型值		说明
;	代码段类型	----------------------------------
;			8		只执行 
;			9		只执行、已访问 
;			A		执行/读 
;			B		执行/读、已访问 
;			C		只执行、一致码段 
;			D		只执行、一致码段、已访问 
;			E		执行/读、一致码段 
;			F		执行/读、一致码段、已访问 

;--------this is the segment type definition---------
DA_DATA_R equ 0x00009000 
DA_DATA_RW equ 0x00009200
DA_DATA_RW_DOWN equ 0x00009600 ;可读可写，向下扩展

;只执行代码段
DA_CODE_E equ 0x00009800
;可执行可读的代码段 
DA_CODE_ER equ 0x00009A00

;只执行一致代码段，系统API段描述符
DA_CODE_E_CONSISTENT  equ 0x00009C00
;可读可执行的一致代码段
DA_CODE_ER_CONSISTENT equ 0x00009E00


; 当 S=1 时TYPE中的4个二进制位情况：
;      3       2       1       0
;    执行位 一致位 读写位 访问位

; 执行位：置1时表示可执行，置0时表示不可执行；
; 一致位：置1时表示一致码段，置0时表示非一致码段；
; 读写位：置1时表示可读可写，置0时表示只读；
; 访问位：置1时表示已访问，置0时表示未访问。

; 所以一致代码段和非一致代码段的意思就是指这个一致位是否置1，置1就是一致代码段，置0就为非一致代码段。

;  

;  

; 一致代码段:

;  简单理解，就是操作系统拿出来被共享的代码段,可以被低特权级的用户直接调用访问的代码.

; 通常这些共享代码，是"不访问"受保护的资源和某些类型异常处理。比如一些数学计算函数库,为纯粹的数学运算计算,

; 被作为一致代码段.

;  

; 一致代码段的限制作用

; 1.特权级高的程序不允许访问特权级低的数据:核心态不允许调用用户态的数据.
; 2.特权级低的程序可以访问到特权级高的数据.但是特权级不会改变:用户态还是用户态.

;  

; 非一致代码段:

; 为了避免低特权级的访问而被操作系统保护起来的系统代码.

; 非一致代码段的限制作用

; 1.只允许同级间访问.
; 2.绝对禁止不同级访问:核心态不用用户态.用户态也不使用核心态.
