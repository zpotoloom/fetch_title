; --------------------------------------------------------------
; Pre-processor area

; Converts little-endian to big-endian
%define htons(x) (((x & 0xFF) << 8) | (x >> 8)) 

%define crlf $0d, $0a

; --------------------------------------------------------------
section .data

PORT equ 80
;HOST equ 16777343               ; 127.0.0.1
HOST equ 4124127939            ; neti.ee

sockerr:  db "Socket failed", crlf
sockerr_len equ $-sockerr

connerr:  db "Unable to connect", crlf
connerr_len equ $-connerr

get:   db "GET /", crlf
get_len equ $-get


; --------------------------------------------------------------
section .bss

buffer:	resb 2048
title:	resw 10			; 40 characters

; --------------------------------------------------------------
section .text
global _start


_start:
        test eax, eax
        jz main

        jmp exit2
        

main:   call socket
        call connect
        call http_get 
        call read_loop


exit:   mov eax, 6              ; SYS_CLOSE = 6
        mov ebx, esi            ; close fd of socket
        int $80


exit2:  mov eax, 1              ; SYS_EXIT = 1
        xor ebx, ebx            ; exit(0)
        int $80


fail_sock:
        mov eax, 4
        mov ebx, 2
        mov ecx, sockerr
        mov edx, sockerr_len
        int $80
        jmp exitf


fail_conn:
        mov eax, 4
        mov ebx, 2
        mov ecx, connerr
        mov edx, connerr_len
        int $80
        jmp exitf


exitf:
        mov eax, 1              ; SYS_CLOSE = 1
        mov ebx, -1             ; exit(-1)
        int $80


        ;; socket(PF_INET, SOCK_STREAM, 0)
socket:
	push ebp
        mov ebp, esp

        push 0                  ; protocol = 0
        push 1                  ; SOCK_STREAM = 1
        push 2                  ; AF_INET = 2

        mov eax, $66            ; SYS_SOCKETCALL = $66
        mov ebx, 1              ; SYS_SOCKET = 1
        mov ecx, esp
        int $80                 ; eax contains a socket fd, or -1

        cmp eax, -1             ; if ERROR
        je fail_sock            ; then exit(-1)

        mov esi, eax            ; save the fd

        leave
        ret

	

        ;; connect(fd, [AF_INET, port, IPv4], size)
connect:
        push ebp
        mov ebp, esp

        ;; sockaddr strcuture
        push dword 0
        push dword 0
        
        push dword HOST         ; IP in decimal 
        push word htons(PORT)   ; port, tcp/ip uses bigendian
        push word 2             ; AF_INET = 2
        mov ecx, esp

        push 16                 ; size
        push ecx                ; [AF_INET, port, IPv4]
        push dword esi          ; fd of socket

        mov eax, $66            ; SYS_SOCKETCALL
        mov ebx, 3              ; SYS_CONNECT = 3
        mov ecx, esp            ; connect(args)
        int $80

        cmp eax, -1
        je fail_conn

        leave
        ret
	

http_get:
        mov eax, 4
        mov ebx, esi
        mov ecx, get
        mov edx, get_len
        int $80

        ret


read_loop:
        
    .read:
        mov eax, 3              ; SYS_READ = 3
        mov ebx, esi
        mov ecx, buffer
        mov edx, 1024
        int $80

        call parse
	jmp .read

parse:
        push ebp
        mov ebp, esp
        mov ebx, buffer

	mov edx, 0
    .loop:
	inc edx
	inc ebx
	cmp dword [ebx], '<tit'
        jne .loop
	
    .loop1:
	inc ebx
	inc edx
	cmp byte [ebx], '>'
	jne .loop1
	
	mov edi, 0
	inc edx
    .loop2:
	inc ebx
	inc edi
	cmp byte [ebx], '<'
	jne .loop2

	jmp print_title


print_title:
	dec edi		; decrement to exclude < 
	mov eax, 4 
	mov ebx, 1 
	mov ecx, buffer
	add ecx, edx
	mov edx, edi
	int 0x80 
	call exit


