; Copyright (C) 2007-2015 fclaerhout.fr, released under the MIT license
; 20070220

; This bootloader clears the screen and offers a basic output routine+scrolling.
; Compilation: nasm -f bin os6_source -o os6_image
; Bootdisk floppy image: dd if=/dev/zero of=bootdisk_image bs=512 count=2880
;   dd if=os6_image of=bootdisk_image conv=notrunc
; Simulation: bochs -q or qemu -fda bootdisk_image -boot a

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
		; Then we print our messages.
		mov ax,starting
		call outputString
		mov ax,ending
		call outputString


	; Mark END and halt, this ensures we are not lost in an infinite loop somewhere.
	stop:
		mov byte [gs:0xF9F],0x1D
		mov byte [gs:0xF9E],'D'
		mov byte [gs:0xF9D],0x1D
		mov byte [gs:0xF9C],'N'
		mov byte [gs:0xF9B],0x1D
		mov byte [gs:0xF9A],'E'
		hlt


	; Assume 80x25 layout.
	clearScreen:
		push si
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


	; Scroll down one line, assume 80x25 layout.
	scrollScreen:
		push ax
		push si
		push di
		mov di,0
		mov si,160
		.start:
			mov ax,[gs:si]
			mov [gs:di],ax
			add di,2
			add si,2
			cmp si,0xEFF
			jle .start
		.clearLastLine:
			mov byte [gs:si],' '
			inc si
			mov byte [gs:si],0x0A
			cmp si,0xF9F
			jz .end
			inc si
			jmp .clearLastLine
		.end
			pop di
			pop si
			pop ax
			ret


	; Output a string which address is in ax. Assume a 80x25 layout.
	lastPosition dw 0
	lastCol dw 0
	outputString:
		pusha
		; We exchange bx and ax, bx will contain the string address.
		xchg bx,ax
		mov si,[lastPosition]
		mov di,[lastCol]
		.start:
			mov al,[bx]
			; If the character is null, this is the end.
			cmp al,0
			jz .end
			; If the character is 13, a line is jumped.
			cmp al,13
			jz .jumpLine
			; The character is displayed.
			mov byte [gs:si],al
			; The column is shifted and the pointer too.
			add si,2
			add di,2
			inc bx
			jmp .start
		.jumpLine:
			add si,160
			sub si,di
			xor di,di
			; *** This auto-scrolling part is not tested yet... ***
			cmp si,0xF9F
			jl .continue
				call scrollScreen
				sub si,160
			.continue:
				inc bx
				jmp .start
		.end:
			mov [lastPosition],si
			mov [lastCol],di
			popa
			ret


; ASCIZ strings and data.
	starting db 'O/S 6, Starting...',13,0
	ending db 'Carrier error, bye.',13,0


; Padding and magic number.
	times 510-($-$$) db 0
	db 0x55
	db 0xAA
	
