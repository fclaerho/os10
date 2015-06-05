; Copyright (C) 2007-2015 fclaerhout.fr, released under the MIT license

; This is a minimal bootloader setting a temporary runtime environment.

; The BIOS loads us at 0x7C00 in Real-Mode (16bit mode).
[ORG 0x7C00]
[BITS 16]

	jmp 0:start ; Set CS to 0.
	
start:
	; At startup, the only interrupt handlers set are the BIOS ones.
	; However it is safer to disable the interrupt while our proper
	; handler are not ready.
	cli
	; Then we setup the temporary runtime environment for the CPU, allowing us
	; to perform the job of a bootloader (copy other segments of the O/S).
	; Setting up the runtime environment consists in setting up the segment
	; registers and the stack.
	; For the moment we only need DS (the data segment) and the stack.
	; DS must also be compatible with the ORG directive above so we set it to
	; the same value than CS (i.e. 0).
	; NOTE: A segment register (cs,ds,ss,es,fs,gs) cannot be set directly
	; with a 'mov' instruction, this is done in two steps.
	mov ax,cs
	mov ds,ax
	; The conventional memory layout is initially as follows:
	; RAM:
	;  -0x00000-0x003FF IVT (Interrupt Vector Table) 256 entries of 4 bytes
	;  -0x00400-0x004FF BDA (BIOS Data Area)
	;  -0x00500-0x9FBFF free conventional memory (below 1M)
	;  -0x9FC00-0x9FFFF EBDA (Extended BDA)
	; VIDEO RAM (mapped):
	;  -0xA0000-0xAFFFF VGA Frambuffer
	;  -0xB0000-0xB7FFF Text Monochrom
	;  -0xB8000-0xBFFFF Text Color
	;  -0xC0000-0xC7FFF Video BIOS
	; BIOS:
	;  -0xF0000-0xFFFFF Motherboard BIOS (~64M)
	; So we are currently in the 'free conventional memory' area and there is
	; some space just below for the stack (which will grow down).
	; 0x7C00-0x500~30ko, this is sufficient for now.
	; 0x7C00 is below 64K, so it's coherent with ss=0.
	; IMPORTANT NOTE: The stack must be set before calling any function as
	; 'call' and 'ret' use the stack.
	and ax,0
	mov ss,ax
	mov sp,0x7C00
	hlt

; Padding and magic number.
	times 510-($-$$) db 0
	db 0x55
	db 0xAA
	
