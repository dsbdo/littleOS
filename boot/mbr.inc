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
GDT_DATA_4G_DESC equ 0x0008
GDT_MBR_DESC     equ 0x0010
GDT_STACK_DESC   equ 0x0018
GDT_VIDEO_DESC   equ 0x0020
;描述符类型常量描述 TYPE 四位
;描述符P DPL S位常量
;描述符粒度描述G      D/B                 L       AVL
;             粒度    默认操作指令长度    64bit
