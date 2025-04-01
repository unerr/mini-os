[BITS 16]
[ORG 0x7C00]

start:
	cli
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7C00
	
	mov ah, 0x02         ; Read sectors function
    mov al, 1            ; Read 8 sectors (4KB, adjust as needed)
    mov ch, 0            ; Cylinder 0
    mov cl, 2            ; Sector 2 (after bootloader)
    mov dh, 0            ; Head 0
    mov bx, 0x100       ; Load to 0x1000:0000
    mov es, bx
    xor bx, bx           ; ES:BX = 0x10000
    int 0x13             ; BIOS disk read
    jc .error            ; Jump on error

	lgdt [gdt_descriptor] ; Load GDT table

	mov eax, cr0
	or eax, 1 ; Enable PE flag. It is neccessary to jump into protected_mode
	mov cr0, eax
	
	jmp 0x08:protected_mode
	.error:
		mov si, disk_error
		mov ah, 0x0E
		.loop:
			lodsb
			cmp al, 0
			jz .loop_end
			int 0x10
			jmp .loop
		.loop_end:
		hlt

disk_error: db "Disk read error!", 0
boot_disk: db 0
[bits 32]
protected_mode:
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov esp, 0x900000
	
	cld
	mov esi, 0x1000
	mov edi, 0x100000
	mov ecx, 512
	rep movsb 
	
	mov eax, cr4
	or eax, 1 << 5 ; Must be set if you want to switch on long mode
	mov cr4, eax

	mov edi, 0x10000
	mov cr3, edi ; You say to the processor, "Hey, page tables lie in 0x3000 memory address"
	
	mov dword [edi], 0x11003 ; PML4 (Page map level 4) is used to point to the next table (PDP)
	mov dword [edi + 0x1000], 0x12003 ; PDP (Page directory pointer) is used to point to the next table (PD)
	mov dword [edi + 0x2000], 10000011b ; PD (Page directory) is used to just say, "Now address starting from 0x00 to 0x1fffff(2MiB) are the same in virtual and physic memories"
	
	mov ecx, 0xC0000080
	rdmsr ; Read 64-bit value from the MSR that is specified by ecx register (0xC0000080 is EFER) to edx:eax registers
	or eax, 1 << 8 ; Set Long Mode Enable bit to jump into long mode
	wrmsr ; Write 64-bit value to the MSR that is specified by ecx register(the same address, EFER) from edx:eax registers

	mov eax, cr0
	or eax, (1 << 31) | 1 ; set PE and PG flags to be active
	mov cr0, eax
	
	jmp 0x18:long_mode
[bits 64]
long_mode:
	xor ax, ax
	mov ss, ax
	mov es, ax
	mov ds, ax
	mov fs, ax
	mov gs, ax
	

	mov rax, 0x100000
	jmp rax	
	hlt

gdt_start:
	dq 0

	; Code segment
	dw 0XFFFF
	dw 0
	db 0
	db 10011110b
	db 11001111b
	db 0

	; Data segment
	dw 0xFFFF
	dw 0
	db 0
	db 10010010b
	db 11001111b
	db 0
	
	; Code segment x64
	dw 0xffff
	dw 0
	db 0
	db 10011110b
	db 10101111b
	db 0
gdt_end:

gdt_descriptor:
	dw gdt_end - gdt_start - 1
	dd gdt_start
times 510 - ($-$$) db 0
dw 0xAA55
