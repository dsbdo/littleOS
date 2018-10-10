all:c.img 
mbr.bin: 32bit_mbr.asm
		nasm -f bin 32bit_mbr.asm -o mbr.bin
core.bin: core.asm
		nasm -f bin core.asm -o core.bin

c.img: mbr.bin core.bin 
		.\windows\dd.exe if=mbr.bin of=c.img bs=512 count=1 seek=0 conv=notrunc
		.\windows\dd.exe if=core.bin of=c.img bs=512 count=9 seek=1 conv=notrunc
		.\windows\dd.exe if=usr.bin of=c.img bs=512 count=2 seek=49 conv=notrunc
clean: 
		del *.img
		del *.bin