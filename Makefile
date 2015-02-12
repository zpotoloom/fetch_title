default:
	nasm -f elf -g fetch_title.asm -o fetch_title.o
	ld -m elf_i386 -s -o fetch_title fetch_title.o
	rm fetch_title.o
