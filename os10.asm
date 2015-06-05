; Copyright (C) 2007-2015 fclaerhout.fr - Licenced under the GPL.
; 20070315

; The BIOS loads us at 0x7C00 in Real-Mode (16bit), we jump to 0x7C0:start.

[ORG 0]
[BITS 16]

jmp 0x7C0:start


; String resources:
	_welcome
		db 'Copyright (C) 2003-2007 Ghost Corp. - Licended under the GPL.',13
		db 'O/S 10 Starting, please wait.',13,0
	_CPUCheck db '> Checking CPU compatibility...',0
	_driveReset db '> Resetting boot device...',0
	_sectorsCopy db '> Loading additional sectors...',0
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
	call getSMAP


stop:
	mov byte [fs:0xF9F],0x1D
	mov byte [fs:0xF9E],'D'
	mov byte [fs:0xF9D],0x1D
	mov byte [fs:0xF9C],'N'
	mov byte [fs:0xF9B],0x1D
	mov byte [fs:0xF9A],'E'
	hlt


; Assume a 80x25 layout, the last byte being (80.25-1).2=3999=0xF9F. Use SI.
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
	.stop:
		ret
	

; ASCIZ string address in AX. Assume a 80x25 layout. Use AX,BX,SI,DI.
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
	.end:
		mov [lastPosition],si
		mov [lastCol],di
		ret


failed:
	mov ax,_failed
	call outputString
	jmp stop


; Return if this is a 32bit CPU. Use AX.
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


; Reset the boot device, BIOS(0x13,0).
; DL contains the drive number. Use AX,DL,SI.
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
	.succeeded:
		mov ax,_OK
		call outputString
		ret


; Use the BIOS(0x13,2) routine to copy sectors from a device to RAM.
; Use AX,BX,CX,DX,SI. DL contains the drive number.
BIOSLoadNextSectors:
	mov ax,_sectorsCopy
	call outputString
	mov si,5 ; The copy will be attempted 5 times.
	.start:
		; The next sectors are loaded right after the current code (0x7C00+512).
		mov ax,0x7C0
		mov es,ax ; ES contains the destination code segment value.
		mov bx,512 ; BX contains the destination offset.
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


; String Resources:
	_freeRAM db '> Getting System Memory Map:',13,0
	_BIOSxE820ACPI3 db '  Trying BIOS 0xE820 (ACPI 3.0 extension)...',0
	_BIOSxE820 db 13,'  Trying BIOS 0xE820...',0
	_BIOSxE881 db 13,'  Trying BIOS 0xE881...',0
	_BIOSxE801 db 13,'  Trying BIOS 0xE801...',0
	_BIOSxC7 db 13,'  Trying BIOS 0xC7...',0
	_BIOSx88 db 13,'  Trying BIOS 0x88...',0
	_CMOS db 13,'  Reading CMOS...',0
	_Probing db 13,'  Manual Probing...',0
	_freeTag db 'Free',13,0
	_reservedTag db 'Reserved',13,0
	_ACPIReclaimTag db 'ACPI Reclaim',13,0
	_ACPINVSTag db 'ACPI NVS',13,0
	_badMemoryTag db 'Bad memory',13,0
	_undefinedTag db 'Undefined',13,0
	_buffer db '  @'
		_address times 16 db '.'
		db ' L'
		_length times 16 db '.'
		db ' '
		_type times 16 db '.'
		db ' ',0


; Estimation of the free RAM ranges. We still need the BIOS to do that.
; We proceed as advised by everyone: E820, E881, e801, C7, 88, CMOS and
; manual probing to finish if everything else failed.
; Our SMAP is stored right above the BDA at 0x500 and each entry consists
; of 24 bytes (ACPI 3.0 compliant). The first entry is reserved and its
; first byte account for the total number of entries in the map, the
; remaining byte are ignored (what a waste of space).
getSMAP:
	mov ax,_freeRAM
	call outputString
	and ax,0
	mov es,ax ; ES is used as segment for the SMAP entries.
	mov byte [es:0x500],0 ; Initially there is no SMAP entry.

	BIOSxE820ACPI3:
		; ACPI 3.0 extends a SMAP entry by 4 bytes, making it 24 bytes.
		; We store the system map entries just above the BDA at 0x500.
		; So the first entry is at 0x500, the second at 0x500+24, etc.
		mov ax,_BIOSxE820ACPI3
		call outputString
		and ebx,0
		mov di,0x518
		.start
			mov eax,0x0000E820
			mov edx,'PAMS' ; 'SMAP' (System Map) in the right byte order.
			mov ecx,24
			int 0x15
			jc .failed ; FIXME: maybe just the SMAP end.
			cmp ecx,24
			jne .failed
			cmp ebx,0
			jz .succeeded
			add di,24 ; points to the next buffer entry.
			; Then we increment the SMAP entry counter.
			mov al,[es:0x500]
			inc al
			mov [es:0x500],al
			jmp .start
		.succeeded:
			jmp outputSMAP
		.failed

	BIOSxE820:
		; Same thing as above except a system map entry does 20 bytes.
		mov ax,_BIOSxE820
		call outputString
		and ebx,0
		mov di,0x518
		.start
			mov eax,0x0000E820
			mov edx,'PAMS'
			mov ecx,20
			int 0x15
			jc .failed ; FIXME: maybe just the SMAP end.
			cmp ecx,20
			jne .failed
			cmp ebx,0
			jz .succeeded
			add di,24 ; points to the next buffer entry.
			; Then we increment the SMAP entry counter.
			mov al,[es:0x500]
			inc al
			mov [es:0x500],al
			jmp .start
		.succeeded:
			jmp outputSMAP
		.failed

	BIOSxE881:
		mov ax,_BIOSxE881
		call outputString
		;
		; // TODO
		;
		
	BIOSxE801:
		mov ax,_BIOSxE801
		call outputString
		;
		; // TODO
		;

	BIOSxC7:
		mov ax,_BIOSxC7
		call outputString
		mov ah,0xC7
		int 0x15
		; if (CF or AH!=0x88), something's wrong.
		jc .failed
		cmp ah,0x88
		jne .failed
		.succeeded:
			;
			; // TODO
			;
			jmp outputSMAP
		.failed:

	BIOSx88:
		; This call returns the free extended memory size between 1MB and 16MB.
		mov ax,_BIOSx88
		call outputString
		mov ah,0x88
		int 0x15
		; if (CF or AH!=0x88), something's wrong.
		jc .failed
		cmp ah,0x88
		jne .failed
		; if (AX>=0x3C00) (15MB, the ubound), there is probably more memory.
		cmp ax,0x3C00
		jg .failed
		.succeeded:
			;
			; // TODO
			;
			jmp outputSMAP
		.failed:

	CMOSRAM:
		mov ax,_CMOS
		call outputString
		;
		; // TODO
		;

	RAMProbing:
		mov ax,_Probing
		call outputString
		;
		; // TODO
		;
		.failed:
			jmp failed
	
	; The output of the SMAP is not really useful except for debugging purposes.
	outputSMAP:
		mov ax,_OK
		call outputString
		mov al,[es:0x500] ; AL: SMAP entry counter.
		and ah,0 ; AH: Current entry.
		mov bx,23 ; BX: Source character offset (init 0x500+23).
		.forEachEntry:
			cmp ah,al
			jne .skip ; Did we process each entry?
			jmp .outputEnd ; If yes, we need a long jump to the end.
			.skip:
			add bx,8 ; We start from the last byte due to the byte order.
			and si,0 ; Source byte counter.
			and di,0 ; Destination character counter.
			.entryStart:
				cmp si,24 ; Did we process the 24 byte of the entry?
				je .entryEnd ; If yes the buffer is displayed.
				; If not, we get back a byte, split it into 2 hex character,
				; translate them into their ASCII code and store them in the
				; buffer.
				mov cl,[es:0x500+bx] ; CL contains the initial byte.
				mov dl,cl ; DL contains the low nibble of CL.
				and dl,0xF0
				ror dl,4
				cmp dl,9
				jg .translateHighToLetter
				.translateHighToDigit:
					add dl,'0'
					jmp .storeHigh
				.translateHighToLetter:
					add dl,55
				.storeHigh:
					mov [_address+di],dl
				inc di ; We process now the low nibble.
				mov dl,cl
				and dl,0xF
				cmp dl,9
				jg .translateLowToLetter
				.translateLowToDigit:
					add dl,'0'
					jmp .storeLow
				.translateLowToLetter:
					add dl,55
				.storeLow:
					mov [_address+di],dl
				; We prepare the next byte
				dec bx
				inc si
				inc di
				cmp si,8
				jne .skip1
					add di,2 ; Jump over the ' L'.
					add bx,16
				.skip1
				cmp si,16
				jne .skip2
					inc di ; Jump over the ' '.
					add bx,16
				.skip2
				jmp .entryStart
			.entryEnd:
				push ax
				push bx
				push si
				push di
				mov ax,_buffer
				call outputString
				cmp dl,'1'
				je .outputFreeTag
				cmp dl,'2'
				je .outputReservedTag
				cmp dl,'3'
				je .outputACPIReclaimTag
				cmp dl,'4'
				je .outputACPINVSTag
				cmp dl,'5'
				je .outputBadMemoryTag
				jmp .outputUndefinedTag
				.outputFreeTag:
					mov ax,_freeTag
					call outputString
					jmp .end
				.outputReservedTag:
					mov ax,_reservedTag
					call outputString
					jmp .end
				.outputACPIReclaimTag:
					mov ax,_ACPIReclaimTag
					call outputString
					jmp .end
				.outputACPINVSTag:
					mov ax,_ACPINVSTag
					call outputString
					jmp .end
				.outputBadMemoryTag:
					mov ax,_badMemoryTag
					call outputString
					jmp .end
				.outputUndefinedTag:
					mov ax,_undefinedTag
					call outputString
			.end:
				pop di
				pop si
				pop bx
				pop ax
				inc ah
				add bx,8
				jmp .forEachEntry
		.outputEnd:
			jmp stop
