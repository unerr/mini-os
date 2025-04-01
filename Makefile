all: os

kernel: kernel_entry.asm
	nasm -f bin kernel_entry.asm -o kernel.bin

bootload: bootloader.asm
	nasm -f bin bootloader.asm -o boot.bin

os: bootload kernel
	cat boot.bin kernel.bin > os.bin
