; Copyright (C) 2007-2015 fclaerhout.fr, released under the MIT license
; 20070311

; Compilation:
;   nasm -f bin os9_source -o os9_image
; Bootdisk floppy image generation:
;   dd if=/dev/zero of=bootdisk_image bs=512 count=2880
; Copy of the bootloader to the 1st sector of the image:
; 	dd if=os9_image of=bootdisk_image conv=notrunc
; Simulation with qemu:
;   qemu -fda bootdisk_image -boot a

; The BIOS loads us at 0x7C00 in Real-Mode (16bit), we jump to 0x7C0:start.

[ORG 0]
[BITS 16]

jmp 0x7C0:start


; String resources:
	_welcome
		db 'Copyright (C) 2003-2007 Ghost Corp. - Licended under the GPL.',13
		db 'O/S 9 Booting, please wait.',13,0
	_CPUCheck db '> Checking CPU compatibility...',0
	_driveReset db '> Resetting drive...',0
	_sectorsCopy db '> Loading additional sectors...',0
	_otherThings db '> Doing other things...',0
	_failed db 'FAILED',13,0
	_OK db 'OK',13,0


start:
	; Interrupts are disabled as we do not have any handler.
	cli
	; DL contains the boot device identifier, set earlier by the BIOS,
	; this value must not be lost.
	; Minimal runtime environment setting (CS, stack):
	mov ax,cs
	mov ds,ax
	; Stack setup (grow down below the code, 30KB available before the BDA):
	and ax,0
	mov ss,ax
	mov sp,0x7C00
	; FS points to the video mapped memory (Text Color):
	mov ax,0xB800
	mov fs,ax
	call clearScreen
	; Welcome messages:
	mov ax,_welcome
	call outputString
	; Real jobs:
	call checkCPU
	call loadNextSectors
	call otherThings


stop:
	mov byte [fs:0xF9F],0x1D
	mov byte [fs:0xF9E],'D'
	mov byte [fs:0xF9D],0x1D
	mov byte [fs:0xF9C],'N'
	mov byte [fs:0xF9B],0x1D
	mov byte [fs:0xF9A],'E'
	hlt


; Assume a 80x25 layout, the last byte being (80.25-1).2=3999=0xF9F.
clearScreen:
	mov si,0xF9F
	.start:
		mov byte [fs:si],0xF
		dec si
		mov byte [fs:si],' '
		cmp si,0
		jz .stop
		dec si
		jmp .start
	.stop
		ret
	

; ASCIZ string address in AX. Assume a 80x25 layout.
lastPosition dw 0
lastCol dw 0
outputString:	
	; AX and BX are exchanged, BX will contain the string address.
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
		mov byte [fs:si],al
		; The column is shifted and the string pointer too.
		add si,2
		add di,2
		inc bx
		jmp .start
	.jumpLine:
		add si,160
		sub si,di
		xor di,di
		inc bx
		jmp .start
	.end
		mov [lastPosition],si
		mov [lastCol],di
		ret


failed:
	mov ax,_failed
	call outputString
	jmp stop


; Return if this is a 32bit CPU.
checkCPU:
	mov ax,_CPUCheck
	call outputString
	;
	; From Grzegorz Mazur <http://grafi.ii.pw.edu.pl/gbm>
	;
	pushf ; Stack[FLAGS]
	pop ax ; AX <- FLAGS
	push ax ; Stack[FLAGS]
	or ax,0x7000 ; Set Bit 14 (NT) and Bits 13,12 (IOPL).
	push ax ; Stack[FLAGS,FLAGS+0x7000]
	popf ; FLAGS <- FLAGS+0x7000, Stack[FLAGS]
	pushf ; Stack [FLAGS,FLAGS']
	pop ax ; Stack [FLAGS], AX <- FLAGS'
	popf ; Stack[], FLAGS restored.
	and ax,0x7000
	cmp ax,0x7000 ; If the 3 bits are still set, it is a 32bit CPU.
	je .succeeded
	.failed:
		jmp failed
	.succeeded:
		mov ax,_OK
		call outputString
		ret
	

loadNextSectors:
	call BIOSResetDrive
	call BIOSLoadNextSectors
	ret


; Reset the boot device, BIOS(0x13,0). DL contains the drive number.
BIOSResetDrive:
	mov ax,_driveReset
	call outputString
	mov si,5 ; The reset will be attempted 5 times.
	.start:
		and ah,0 ; Select the BIOS function (0).
		int 0x13
		cmp ah,0 ; Did we get an error? (0=no)
		je .succeeded
		dec si
		cmp si,0 ; Can we try again?
		jne .start
	.failed
		jmp failed
	.succeeded
		mov ax,_OK
		call outputString
		ret


; Use the BIOS(0x13,2) routine to copy sectors from a device to RAM.
; DL contains the drive number.
BIOSLoadNextSectors:
	mov ax,_sectorsCopy
	call outputString
	mov si,5 ; The copy will be attempted 5 times.
	.start:
		; The next sectors are loaded right after the current code (0x7C00+512).
		mov ax,0x7C0
		mov es,ax ; ES contains the destination code segment value.
		mov bx,512
		and dh,0 ; Head number.
		; DL still contains the drive identifier.
		mov cl,2 ; Sector number (start from 1)
		and ch,0 ; Disk cylinder.
		mov al,4 ; Number of sectors to read.
		mov ah,2 ; Select the BIOS function (2)
		int 0x13
		cmp ah,0 ; Did we get an error? (0=no)
		je .succeeded
		dec si			
		cmp si,0 ; Can we try again?
		jne .start
	.failed:
		jmp failed
	.succeeded:
		mov ax,_OK
		call outputString
		ret


; Padding and magic number.
	times 510-($-$$) db 0
	db 0x55
	db 0xAA
	

; ---8<--- Other Sectors (2+) --->8---


otherThings:
	mov ax,_otherThings
	call outputString
	ret
	

; NOTE: The code of the 1st sector only has 4 free bytes left on the 512, this
; is not great...
