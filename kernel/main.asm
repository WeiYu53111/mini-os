

%include "boot.inc"
section kernel vstart=KERNEL_START_ADDR
    [bits 32]
    SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0	 ; 同上
    mov eax,SELECTOR_VIDEO
    mov gs,eax
    xchg ebx,ebx

    mov byte [gs:320], 'K'
    mov byte [gs:322], 'e'
    mov byte [gs:324], 'r'
    mov byte [gs:326], 'n'
    mov byte [gs:328], 'e'
    mov byte [gs:330], 'l'
    jmp $