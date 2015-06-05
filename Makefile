# copyright (c) 2015 fclaerhout.fr, released under the MIT license

%.bin: %.asm
	nasm -f bin $< -o $@

%.image: %.bin
	dd if=/dev/zero of=$@ bs=512 count=2880
	dd if=$< of=$@ conv=notrunc
	@echo "bootdisk image ready, use 'bochs -q…' or 'qemu -fda $@ -boot a' for testing"
