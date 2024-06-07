section .rodata
    newline db 10 
section .data
    number dd 0 
    input db 128 
    argc  dd 0      
    argv  dd 0      
    ifile dd 0
    ofile dd 0
    ifilelen dd 0
    keep db 0
    errormsg db 'error'
     len2    equ 0
    ofilelen dd 0
    len equ $-input
    inputlen equ $-input
    lenInput dd 0
     O_CREAT equ 0100    ; Create the file if it doesn't exist
    O_WRONLY equ 01     ; Open the file for writing only
    O_TRUNC equ 0200    ; Truncate the file if it already exists
    %define O_RDONLY 0x0000   ; read-only access
  
section .bss
    buffer: resb 1024
    fd resd 1 
     ifd resd 1       
     ofd  resb 1
    fd2 resb 1
BUFSZ EQU 1000    
section .text
global _start
global icheck
global Loop
global test
extern strlen
extern malloc
%define SYS_WRITE 4
%define STDOUT 1
%define STDERR 2
%define SYS_READ  3
%define STDIN  0
%define SYS_OPEN 5
%define O_RDWR 2
%define SYS_SEEK 19
%define SEEK_SET 0
%define SHIRA_OFFSET 0x291
%define EXIT 1
%define SYS_CLOSE 6
%define CREATE 8
; all the defines we took from sites like stackoverflow and etc that there we saw all the defines we need.
;we were helped by stackoverflow , git , etc...

_start:
    ; from start
    pop    dword ecx        ; ecx = argc
    mov    esi,esp          ; esi = argv
    mov   [number], ecx ; save the value of argc in argc_value
    cmp    ecx, 1           ; Check if argc >= 2
    jle    stdin             ; If not, jump to exit
   
    mov     eax,ecx         ; put the number of arguments into eax
    shl     eax,2           ; compute the size of argv in bytes
    add     eax,esi         ; add the size to the address of argv 
    add     eax,4           ; skip NULL at the end of argv

Loop:    
    mov ecx, [esi + 4]      ; ecx = pointer to the argument string
    mov eax, 0             ; set eax to 0
innerloop:
    cmp byte [ecx+eax], 0    ; check if the current character is null
    je checki                 ; if it is, exit the loop
    inc eax                  ; otherwise, move to the next character
    jmp innerloop

checki:
    cmp word [ecx],"-i" ;learnt from the class
    jne checko
    add ecx,2
    mov [ifile] ,ecx
    sub ecx,2
    sub eax ,2
    mov [ifilelen], eax
    add eax,2
    jmp continue
checko:
     cmp word [ecx],"-o"
    jne continue
    add ecx,2
    mov [ofile] ,ecx
    sub ecx,2
    sub eax ,2
    mov [ofilelen], eax
    add eax,2
    jmp continue

continue:
    mov edx, eax            
    mov eax, SYS_WRITE
    mov ebx, STDERR
    mov ecx, [esi + 4]
    int 0x80

    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, newline
    mov edx, 1
    int 0x80

    sub dword [number], 1
    cmp dword [number], 1
    jle checkFiles
    add esi, 4              
    jmp Loop

checkFiles:
  
    cmp byte [ifile], 0
    jne checkfileo
    cmp byte [ofile],0
    jne stdintofile
    jmp stdin

checkfileo:
    cmp byte [ofile],0
    jne filetofile
    jmp readfromfile

stdintofile: 
    ; create the file
    mov eax, CREATE          
    mov ebx, [ofile]      
    mov ecx, 0777o   ;from google 
    int 0x80            

    ;check error
    cmp eax, 0
    jl open_error       

    mov [fd2], eax

stdin2:
    ; read input from stdin
    mov eax, SYS_READ
    mov ebx, STDIN
    mov ecx, input
    mov edx, 128
    int 0x80
    cmp eax,0
    je exit

   ; length of input
    push ecx
    call strlen
    mov ebx, eax
    pop ecx

    ; encode input string
    push ecx
    call encode
    pop ecx
 
    mov eax, SYS_WRITE
    mov ebx, [fd2]
    mov ecx, input
    int 0x80

    mov eax, 0

cleanBuffer:    
    cmp eax, 128
    je stdin2
    mov byte [input+eax], 0
    inc eax
    jmp cleanBuffer
 
    mov eax, SYS_CLOSE          
    mov ebx, [fd2]      
    int 0x80      
    jmp exit

readfromfile:
    ; open input file
    mov eax, SYS_OPEN  
    mov ebx, [ifile]     
    mov ecx, O_RDWR     
    int 80h             

  
    cmp eax, 0
    jl open_error       
    mov [ofd], eax     

  read_loop:
    ; read input from file
    mov eax, SYS_READ   
    mov ebx, [ofd]      
    mov ecx, buffer    
    mov edx, 1       
    int 0x80         
    
    cmp eax, 0
    je end_read_loop
    
    ; encode input string
    push ecx
    call encode
    pop ecx
    
    ; write input to output file
    mov eax, SYS_WRITE  
    mov ebx, STDOUT     
    mov ecx, buffer     
    int 0x80         
    
    jmp read_loop

end_read_loop:

    mov eax, SYS_CLOSE  
    mov ebx, [ofd]      
    int 0x80           

    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, newline
    mov edx, 1
    int 0x80

    jmp exit


filetofile:

    mov eax, CREATE          
    mov ebx, [ofile]    
    mov ecx, 0777o     
    int 0x80          

    cmp eax, 0
    jl open_error       

    mov [ofd], eax

    ; open input file
    mov ebx, [ifile]    
    mov eax, SYS_OPEN   
    mov ecx, 0  
    int 0x80           

    cmp eax, 0
    jl open_error    

    mov [ifd], eax

read_loop2:

    mov eax, SYS_READ   
    mov ebx, [ifd]      
    mov ecx, buffer   
    mov edx, 1       
    int 80h        
  
    cmp eax, 0
    je end_read_loop2
    
    ; encode input string
    push ecx
    call encode
    pop ecx
    
    ; write input to output file
    mov eax, SYS_WRITE 
    mov ebx, [ofd]      
    mov ecx, buffer    
    int 80h         
    
    ; jump back to start of loop to read next character
    jmp read_loop2

    end_read_loop2:

    ; close the input file
    mov eax, SYS_CLOSE  
    mov ebx, [ifd]     
    int 80h            

    ; close the output file
    mov eax, SYS_CLOSE 
    mov ebx, [ofd]      
    int 80h             

    jmp exit



stdin:  
   ; read input from stdin
    mov eax, SYS_READ
    mov ebx, STDIN
    mov ecx, input
    mov edx, 128
    int 0x80
    cmp eax,0
    je exit

    ; get length of input
    push ecx
    call strlen
    mov ebx, eax
    pop ecx

    ; encode input string
    push ecx
    call encode
    pop ecx

    ; write input to stdout
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, input
    int 0x80

    mov eax, 0
    
cleanBuffer2:    
    cmp eax, 128
    je stdin
    mov byte [input+eax], 0
    inc eax
    jmp cleanBuffer2   


open_error:
    mov eax, SYS_WRITE         
    mov ebx, STDERR          
    mov ecx, errormsg   
    mov edx, SYS_OPEN         
    int 0x80      

    mov eax, SYS_WRITE
    mov ebx, STDOUT
    mov ecx, newline
    mov edx, STDOUT
    int 0x80

    jmp exit

encode:
    push ebp
    mov ebp, esp
    pushad

    ; ecx = pointer to input string
    mov ecx, [ebp+8]

encode_loop:
    ; Load current character into al
    mov al, byte [ecx]

    ; Check if end of string
    cmp al, 0
    je encode_exit

    ; Check if current character is a letter between A-z
    cmp al, 65
    jl skip
    cmp al, 122
    jg skip

increment:
    ; Increment character by 1
    add al, 1

    ; Store modified character back in string
    mov byte [ecx], al

skip:
    ; Move to next character
    inc ecx

    ; Jump back to start of loop
    jmp encode_loop

encode_exit:
    ; Restore registers
    popad

    ; Restore stack and return
    mov esp, ebp
    pop ebp
    ret


exit:
    mov eax, 1             
    mov ebx, 0             
    int 0x80               