all:c.img
mbr.bin: 32bit_mbr.asm
		nasm -f bin 32bit_mbr.asm -o mbr.bin
core.bin: core.asm
		nasm -f bin core.asm -o core.bin
usr.bin: usr.asm
		nasm -f bin usr.asm -o usr.bin
c.img: mbr.bin core.bin usr.bin
		dd if=mbr.bin of=c.img bs=512 count=1 seek=0 conv=notrunc
		dd if=core.bin of=c.img bs=512 count=9 seek=1 conv=notrunc
		dd if=usr.bin of=c.img bs=512 count=2 seek=49 conv=notrunc