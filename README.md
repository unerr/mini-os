# What is this?
I have written this project to explain how a bootloader works. This project differs because it uses 32-bit (Protected) mode and 64-bit (Long) mode.
Of course, your system must support 64-bit mode for that. It will be easier for you to understand if you know assembly.

# Dependencies
Install <a href="https://www.qemu.org/download/">qemu</a>, <a href="https://git-scm.com/downloads">git</a>, <a href="https://www.gnu.org/software/make/">make</a> and <a href="https://nasm.us/">nasm</a>(required).

For sure, you may not install qemu, git and make and do it manually but it is much easier just to install them.

# Run the code
```console
make
qemu-system-x86_64 -drive format=raw,file=os.bin
```

# Explanation of bootloader code
- `cli` mnemonic tells the CPU, "Don't listen to interruptions anymore".
- ```nasm
  xor ax, ax
  mov ds, ax
  mov es, ax
  mov ss, ax
  ```
  We can't set segment registers with our values directly so.
- `mov sp, 0x4000` ; Set safe memory address that won't be overlapped. Don't set 0x7C00 as it was because it is a potential issue.
- ```nasm
  mov ah, 0x02
  mov al, 1
  mov ch, 0
  mov cl, 2
  mov dh, 0
  mov bx, 0x100
  mov es, bx
  xor bx, bx
  int 0x13
  jc .error
  ```
  We load the kernel code here. We use <a href="https://www.ctyme.com/intr/int.htm">BIOS interruptions</a>. The pro of this method is that it is easy to use. The con is that we can use it only in 16-bit mode and you shouldn't do the same for real kernel loading due to small amount of memory in Real mode.
  And we handle an error using jc. When the error occurs CF flag is set.
- `lgdt [gdt_descriptor]` loads <a href="https://wiki.osdev.org/Global_Descriptor_Table">GDT (Global Descriptor Table)</a>. I have written GDT in byte format so it is easier to grasp. We must load GDT to switch on Protected mode.
- ```nasm
  mov eax, cr0
  or eax, 1
  mov cr0, eax
  ```
  We can't set control registers directly also. We must set <a href="https://osdev.fandom.com/ru/wiki/CR0">PE flag</a> to move on.
- `jmp 0x08:protected_mode` jumps using GDT (Code segment).
- ```nasm
  mov ax, 0x10
  mov ds, ax
  mov es, ax
  mov ss, ax
  ```
  We must set them according to where we have declared GDT's Data segment. In this case we use 0x10 because we described it to be there.
- ```nasm
  mov esp, 0x900000
  ```
  We set stack pointer to 0x900000 because Real mode stack is too small for Protected mode. It is safer.
- ```nasm
  cld
  mov esi, 0x1000
  mov edi, 0x100000
  mov ecx, 512
  rep movsb
  ```
  We clear direction flag with `cld` so string operations go forward. Then we move 512 bytes of kernel from 0x1000 to 0x100000 for Protected mode.
- ```nasm
  mov eax, cr4
  or eax, 1 << 5
  mov cr4, eax
  ```
  We set PAE (Physical Address Extension) bit in CR4 because Long mode needs it.
- ```nasm
  mov edi, 0x10000
  mov cr3, edi
  ```
  We tell CPU where page tables are by setting CR3 to 0x10000.
- ```nasm
  mov dword [edi], 0x11003
  mov dword [edi + 0x1000], 0x12003
  mov dword [edi + 0x2000], 10000011b
  ```
  We set up page tables for Long mode. PML4 points to PDP, PDP points to PD, and PD maps 2MiB (0x0 to 0x1FFFFF) to physical memory with present and writable flags.
- ```nasm
  mov ecx, 0xC0000080
  rdmsr
  or eax, 1 << 8
  wrmsr
  ```
  We set Long Mode Enable bit in EFER (Extended Feature Enable Register) using MSR to enable 64-bit mode.
- ```nasm
  mov eax, cr0
  or eax, (1 << 31) | 1
  mov cr0, eax
  ```
  We turn on paging (PG flag) and keep Protected mode (PE flag) in CR0 to enter Long mode.
- `jmp 0x18:long_mode` jumps to 64-bit code segment in GDT (offset 0x18) for Long mode.
- ```nasm
  xor ax, ax
  mov ss, ax
  mov es, ax
  mov ds, ax
  mov fs, ax
  mov gs, ax
  ```
  We zero segment registers in Long mode because they’re not used for segmentation anymore (except FS/GS sometimes).
- ```nasm
  mov rax, 0x100000
  jmp rax
  ```
  We jump to kernel at 0x100000 where we copied it earlier to start 64-bit execution.
- ```nasm
  gdt_start:
    dq 0
    ; Code segment
    dw 0xFFFF
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
  ```
  GDT has null descriptor, 32-bit code and data segments, and 64-bit code segment with Long mode bit set. `gdt_descriptor` tells CPU where GDT is and its size for `lgdt`.
- `times 510 - ($-$$) db 0` fills rest of 512-byte boot sector with zeros.
- `dw 0xAA55` adds boot signature so BIOS knows it’s bootable.
# Explanation of kernel code
- `[bits 64]` tells NASM we're writing 64-bit code.
- `[org 0x100000]` sets the origin address to 0x100000, where the bootloader copied the kernel.
- ```nasm
  mov rdi, 0xB8000
  mov rcx, 80*25
  mov ah, 0xf
  mov al, 0x20
  rep stosw
  ```
  We clear the VGA text buffer at 0xB8000. The buffer is 80x25 characters (2000 bytes). We set `ah` to 0xf (white on black) and `al` to 0x20 (space character), then use `rep stosw` to fill the buffer with spaces, clearing the screen.
- ```nasm
  mov rdi, 0xb8000
  mov rsi, hello
  ```
  We set `rdi` to the VGA buffer start (0xB8000) and `rsi` to the address of the `hello` string ("Hello world!").
- ```nasm
  .loop:
    lodsb
    cmp al, 0
    jz .loop_end
    mov ah, 0xf
    stosw
    jmp .loop
  .loop_end:
  ```
  We load each byte of the string with `lodsb` into `al`. If `al` is 0 (end of string), we jump to `.loop_end`. Otherwise, we set `ah` to 0xf (white on black), write the character and attribute to the VGA buffer with `stosw`, and loop until done.
- `hlt` stops the CPU after displaying the string.
- ```nasm
  hello: db "Hello world!", 0
  ```
  Defines the null-terminated string "Hello world!" to be displayed.
