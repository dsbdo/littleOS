all: load.bin usr.bin demo.img


load.bin:load.asm
	nasm -f bin load.asm -o load.bin
usr.bin:usr.asm
	nasm -f bin usr.asm -o usr.bin

demo.img:  load.bin usr.bin
	dd if=load.bin of=demo.img bs=512 count=1 seek=0 conv=notrunc
	dd if=usr.bin  of=demo.img bs=512 count=2 seek=1 conv=notrunc