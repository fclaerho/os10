; Copyright (C) 2007-2015 fclaerhout.fr, released under the MIT license

; This is a 'hello world' bootloader setting a temporary runtime environment.

; Compilation: nasm -f bin os3_source -o os3_image
; Bootdisk floppy image: dd if=/dev/zero of=bootdisk_image bs=512 count=2880
;   dd if=os3_image of=bootdisk_image conv=notrunc
; Simulation: bochs -q or qemu -fda bootdisk_image -boot a

; The BIOS loads us at 0x7C00 in Real-Mode (16bit mode).
[ORG 0x7C00]
[BITS 16]

	jmp 0:start
	
start:
	; Interrupts are disabled as our handlers are not ready.
	cli
	; Data segment setup.
	mov ax,cs
	mov ds,ax
	; Stack setup (grow down below the code, 30Ko available).
	and ax,0
	mov ss,ax
	mov sp,0x7C00
	; We would like to output 'Hello World' on the screen.
	; The video adapter is initially in 'text mode' and we
	; the content is set by the mapped video memory between
	; 0xB8000 and 0xBFFFF (Text color video ram). Two bytes
	; are allocated for each character to be displayed, the
	; first byte is the ascii code, the second byte is the
	; color attribute. The default is 80 columns x 25 rows.
	; First we setup an extra segment to point in this area.
	mov ax,0xB800
		mov gs,ax
		; Then we fill the memory (it just prints 'Hello').
		; Color attribute byte:
		; bit 7: blink
		; bit 6 to 4: background color [0-7]
		; bit 3 to 0: foreground color [0-15]
		;  -000 black
		;  -001 blue
		;  -010 green
		;  -011 cyan
		;  -100 red
		;  -101 magenta
		;  -110 brown
		;  -111 white
		;  -1000 dark gray
		;  -1001 bright blue
		;  -1010 bright green
		;  -1011 bright cyan
		;  -1100 pink
		;  -1101 bright magenta
		;  -1110 yellow
		;  -1111 bright white
		mov byte [gs:0],'H'
		mov byte [gs:1],0x1D ; Light magenta on blue
		mov byte [gs:2],'e'
		mov byte [gs:3],0x1D
		mov byte [gs:4],'l'
		mov byte [gs:5],0x1D
		mov byte [gs:6],'l'
		mov byte [gs:7],0x1D
		mov byte [gs:8],'o'
		mov byte [gs:9],0x1D
		hlt

; Padding and magic number.
	times 510-($-$$) db 0
	db 0x55
	db 0xAA
	
