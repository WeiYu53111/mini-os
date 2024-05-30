
; 将boot.inc引进进来
%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
    ; 需要设置数据段寄存器,DB命令会将数据写入  ds:[bx+si]
    ;mov ax,LOADER_BASE_ADDR
    ;mov ds,ax


    ; 此处必须要跳转到 标号为loader_start处,因为从MBR过来后,cs:ip指向的是GDT_BASE,不是我们要执行的指令
    jmp loader_start
    ; 进入保护模式需要：
    ; 1、关闭A20地址环绕
    ; 2、构建GDT表 、更新GDTR描述符
    ; 3、CR0的PE位置1


    ; ------------------------------------------------ 构建GDT表
    ;构建gdt及其内部的描述符
    ;GDT表的第一个描述符必须是空描述符(全是0)，CPU硬性规定
    GDT_BASE:
        dd 0x00000000  ; 由于使用的是 平坦模型，所以段基址都是0
        dd 0x00000000
    CODE_DESC:
        dd 0x0000FFFF
        dd DESC_CODE_HIGH4
    DATA_STACK_DESC:
        dd 0x0000FFFF
        dd DESC_DATA_HIGH4

    VIDEO_DESC:
        dd 0x80000007;limit=(0xbffff-0xb8000)/4k=0x7
	    dd DESC_VIDEO_HIGH4  ; 此时dpl已改为0

    GDT_SIZE equ $ - GDT_BASE
    GDT_LIMIT equ GDT_SIZE -1

    times 60 dq 0   ; 此处预留60个描述符的slot,  dq 写8个字节

    ;以下是定义gdt的指针，前2字节是gdt界限，后4字节是gdt起始地址
    gdt_ptr:
        dw  GDT_LIMIT
        dd  GDT_BASE

    ; 构建段选择子  ，13位索引值 + 1位TI + 2位RPL
    SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0         ; 相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT + RPL0
    SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0	 ; 同上
    SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0	 ; 同上



    loader_start:
        ;xchg bx,bx

        ; ------------------------------------------------ 打开A20
        in al,0x92
        or al,0000_0010B
        out 0x92,al


        ; ------------------------------------------------ 更新GDTR
        lgdt [gdt_ptr]


        ; ------------------------------------------------ cr0 pe位置1
        mov eax ,cr0
        or  eax ,0x00000001
        mov cr0 ,eax


        ; 已经进入了保护模式,接下来要使用选择子跳转到32位的
        ;jmp dword SELECTOR_CODE:p_mode_start	     ; 刷新流水线，避免分支预测的影响,这种cpu优化策略，最怕jmp跳转，
        jmp  SELECTOR_CODE:p_mode_start	     ; 刷新流水线，避免分支预测的影响,这种cpu优化策略，最怕jmp跳转，
                             ; 这将导致之前做的预测失效，从而起到了刷新的作用。

        ;xchg bx,bx
        [bits 32]

        p_mode_start:
           mov ax, SELECTOR_DATA
           mov ds, ax
           mov es, ax
           mov ss, ax
           mov esp,LOADER_STACK_TOP
           mov ax, SELECTOR_VIDEO
           mov gs, ax

           mov byte [gs:160], 'P'
           xchg bx,bx
   jmp $