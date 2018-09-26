all: load.bin usr.bin  mbr.bin demo.img 

mbr.bin: mbr2.asm
	nasm -f bin mbr2.asm -o mbr.bin
load.bin:load.asm
	nasm -f bin load.asm -o load.bin
usr.bin:usr.asm
	nasm -f bin usr.asm -o usr.bin

demo.img:  mbr.bin
	dd if=mbr.bin	of=demo.img bs=512 count=1 seek=0 conv=notrunc
	#dd if=load.bin of=demo.img bs=512 count=1 seek=0 conv=notrunc
	#dd if=usr.bin  of=demo.img bs=512 count=2 seek=1 conv=notrunc