; Copyright (C) 2007-2015 fclaerhout.fr, released under the MIT license
; 20070303

; Compilation: nasm -f bin os7_source -o os7_image
; Bootdisk floppy image: dd if=/dev/zero of=bootdisk_image bs=512 count=2880
;   dd if=os7_image of=bootdisk_image conv=notrunc
; Simulation: bochs -q or qemu -fda bootdisk_image -boot a

; The BIOS loads us at 0:0x7C00 in Real-Mode (16bit mode), we go to 0x7C0:0.

	[ORG 0]
	[BITS 16]

	jmp 0x7C0:start
	
	start:
		; The first step is to disable the interrupts as the handlers are not ready.
		cli
		; The boot device number is stored in DL by the BIOS so we must not modify
		; this register.
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
		; Bottom-right label.
		mov byte [gs:0xF9F],0x01
		mov byte [gs:0xF9E],' '
		mov byte [gs:0xF9D],0x1F
		mov byte [gs:0xF9C],'t'
		mov byte [gs:0xF9B],0x1F
		mov byte [gs:0xF9A],'o'
		mov byte [gs:0xF99],0x1F
		mov byte [gs:0xF98],'o'
		mov byte [gs:0xF97],0x1F
		mov byte [gs:0xF96],'B'
		call loadNextSectors
		mov byte [gs:0xF9E],'!' ; All was OK.
		call gStart16


	; Mark END and halt, this ensures we are not lost in an infinite loop somewhere.
	stop:
		mov byte [gs:0xF93],0x1D
		mov byte [gs:0xF92],'D'
		mov byte [gs:0xF91],0x1D
		mov byte [gs:0xF90],'N'
		mov byte [gs:0xF8F],0x1D
		mov byte [gs:0xF8E],'E'
		hlt


	; Next sector loading.
	loadNextSectors:
		mov byte [gs:0xF9E],'1'
		call BIOSResetDrive
		call BIOSLoadNextSectors
		ret


	; Reset the boot device, BIOS(0x13,0). DL contains the drive number.
	BIOSResetDrive:
		mov byte [gs:0xF9E],'2'
		mov si,5 ; The reset will be attempted 5 times.
		.start:
			xor ah,ah ; Select the BIOS function (0).
			int 0x13
			cmp ah,0 ; Did we get an error? (0=no)
			je .succeeded
			dec si
			cmp si,0 ; Can we try again?
			jne .start
		.failed
			jmp stop
		.succeeded
			ret


	; Use the BIOS(0x13,2) routine to copy sectors from a device to RAM.
	; DL contains the drive number.
	BIOSLoadNextSectors:
		mov byte [gs:0xF9E],'3'
		mov si,5 ; The copy will be attempted 5 times.
		.start:
			; The next sectors are loaded right after the current code (0x7C00+512).
			mov ax,0x7C0
			mov es,ax
			mov bx,512
			xor dh,dh ; Head number.
			mov cl,2 ; Sector number (start from 1)
			mov ch,0 ; Disk cylinder.
			mov al,4 ; Number of sectors to read.
			mov ah,2 ; Select the BIOS function (2)
			int 0x13
			cmp ah,0 ; Did we get an error? (0=no)
			je .succeeded
			dec si			
			cmp si,0 ; Can we try again?
			jne .start
		.failed:
			jmp stop
		.succeeded:
			ret


; Padding and magic number.
	times 510-($-$$) db 0
	db 0x55
	db 0xAA
	

; ---8<--- Other Sectors (2+) --->8---


	; Set the O/S tag.
	gStart16:
		mov byte [gs:0xF9F],0x01
		mov byte [gs:0xF9E],' '
		mov byte [gs:0xF9D],0x1F
		mov byte [gs:0xF9C],'7'
		mov byte [gs:0xF9B],0x1F
		mov byte [gs:0xF9A],' '
		mov byte [gs:0xF99],0x1F
		mov byte [gs:0xF98],'S'
		mov byte [gs:0xF97],0x1F
		mov byte [gs:0xF96],'/'
		mov byte [gs:0xF95],0x1F
		mov byte [gs:0xF94],'O'
		hlt


	
