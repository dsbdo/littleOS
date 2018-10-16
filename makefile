#多么痛的领悟，这个makefile 仅仅支持Linux文件路径法
ASMFLAGS = -I./boot/include/ -f bin 
ASM = nasm
all: b.img
mbr.bin: ./boot/mbr.asm 
		$(ASM) $(ASMFLAGS) ./boot/mbr.asm -o mbr.bin
b.img: mbr.bin 
		./windows/dd.exe if=mbr.bin of=b.img bs=512 count=1 seek=0 conv=notrunc
		
# clean: 
# 		del *.img
# 		del *.bin