[bits 64]
[org 0x100000]
kernel_entry:
	mov rdi, 0xB8000
	mov rcx, 80*25
	mov ah, 0xf
	mov al, 0x20
	rep stosw
	
	mov rdi, 0xb8000
	mov rsi, hello
	.loop:
		lodsb
		cmp al, 0
		jz .loop_end
		mov ah, 0xf
		stosw
		jmp .loop
	.loop_end:
	hlt
	

hello: db "Hello world!", 0
