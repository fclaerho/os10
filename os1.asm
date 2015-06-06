; Copyright (C) 2007-2015 fclaerhout.fr, released under the MIT license

; This is a minimal bootloader doing nothing but be bootable.

; Initially the machine is in 16bit mode, so the program instruction must
; respect this specific format (also named encoding) to be run by the CPU.
; We indicate the encoding type to the compiler by the BITS directive.

[BITS 16]

; The BIOS copies the 1st sector of the boot device to the physical address
; 0x7C00 and start executing it. The 1st problem here is that we don't really
; know if the segmented address used by the BIOS is 0:0x7C00 or 0x7C0:0.
; On most BIOS, this will be 0:0x7C00 but we cannot be sure. This point
; is important as any jump attempted in the code will use the segmented
; address CS:(address calculated by the compiler) where the address
; calculated by the compiler depends on the ORG directive. ORG indicates
; the initial offset from which all the label address should be calculated.
; So if ORG=0x7C00, we must have CS=0, if ORG=0, we must have CS=0x7C0.
; E.G. if a label is at 0x7C0a and CS=0x7C0, any jump to this label will
; result in a effective jump to 0x7C00+0x7C0a...
; Whatever the BIOS used as initial segmented address, we still have the
; option to set what we need with a far jump.
; As a segment is limited to 64KB (16bit), if we use CS=0, we will be limited
; to the range [0,0xFFFF], whereas if we use CS=0x7C0, we will be able
; to use the range [0x7C00,0x17BFF], it does not change a lot of things but
; still ensure a bit more of free space. Anyway, to keep is simple we choose
; the option CS=0 and ORG=0x7C00.

[ORG 0x7C00]

	jmp 0:start

start:
	; 'hlt' stands for 'halt', it stops the CPU.
	hlt

; This is a boot loader, to be recognized as such by the BIOS, it must
; end by a magic number. Additionally the magic number must be exactly
; at the end of the 1st sector so the byte 510 and 511, which is done
; by the following code: padding to fill the space between here and the
; byte 509, then add 0xAA55, the magic number.

	times 510-($-$$) db 0 ; This code depend on the compiler, here nasm.
	db 0x55
	db 0xAA
	
; Additional Note:
; When the BIOS has completed its job, the register DL contain the identifier
; of the boot device, this value, that we need later, must not be lost.
