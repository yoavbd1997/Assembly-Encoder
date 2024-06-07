all: part1

part1: start.o Util.o
	ld -m elf_i386 start.o Util.o -o part1

start.o: start.s
	nasm -f elf32 -g start.s -o start.o

Util.o: Util.c
	gcc -m32 -Wall -ansi -c -nostdlib -fno-stack-protector Util.c -o Util.o

.PHONY: clean
clean:
	rm -f *.o part1
