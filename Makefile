# copyright (c) 2015 fclaerhout.fr, released under the MIT license

DISTDIR := images

all: $(patsubst %.asm, $(DISTDIR)/%.image, $(wildcard *.asm))

$(DISTDIR):
	mkdir $(DISTDIR)

$(DISTDIR)/%.bin: %.asm | $(DISTDIR)
	nasm -f bin $< -o $@

$(DISTDIR)/%.image: $(DISTDIR)/%.bin | $(DISTDIR)
	dd if=/dev/zero of=$@ bs=512 count=2880
	dd if=$< of=$@ conv=notrunc
	@echo "bootdisk image ready, use 'bochs -q…' or 'qemu -fda $@ -boot a' for testing"

clean:
	rm -vrf $(DISTDIR)
