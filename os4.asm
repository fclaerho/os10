; Copyright (C) 2007-2015 fclaerhout.fr, released under the MIT license

; This bootloader clears the screen and output 'pwn3d!'.

; The BIOS loads us at 0x7C00 in Real-Mode (16bit mode).

	[ORG 0x7C00]
	[BITS 16]

	jmp 0:start
	
	start:
		; The first step is to disable the interrupts as the handlers are not ready.
		cli
		; Temporary runtime environment setting (only ds is setup, we don't plan to
		; use the extra segment for now, so we won't waste some bytes setting them up)
		mov ax,cs
		mov ds,ax
		; We setup gs to the video mapped memory area.
		mov ax,0xB800
		mov gs,ax
		; Stack setup (grow down below the code, 30Ko available).
		xor ax,ax
		mov ss,ax
		mov sp,0x7C00
		; First we clear the screen, which currently contain the BIOS output.
		call clearScreen
		; Then we print our message.
		call sayHello
		hlt


	; This routine loops on each character location on the screen and reset its
	; content with a space and a color attribute white/black. As the layout is
	; assumed to be 80 columns per 25 rows, the last byte is at 80*2*25-1=3999
	; and 3999=0xF9F.
	clearScreen:
		push si ; Backup.
		mov si,0xF9F
		.start:
			mov byte [gs:si],0x0A
			dec si
			mov byte [gs:si],' '
			cmp si,0
			jz .stop
			dec si
			jmp .start
		.stop
			pop si
			ret


	sayHello:
		mov byte [gs:0],'p'
		mov byte [gs:2],'w'
		mov byte [gs:4],'n'
		mov byte [gs:6],'3'
		mov byte [gs:8],'d'
		mov byte [gs:10],'!'
		ret


; Padding and magic number.
	times 510-($-$$) db 0
	db 0x55
	db 0xAA
	
