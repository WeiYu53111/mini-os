
; 将boot.inc引进进来
%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
    ; 需要设置数据段寄存器,DB命令会将数据写入  ds:[bx+si]
    ;mov ax,LOADER_BASE_ADDR
    ;mov ds,ax

    ;xchg bx,bx
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

   ; 前面equ不占用空间，
   ; total_mem_bytes用于保存内存容量,以字节为单位,此位置比较好记。
   ; 当前偏移loader.bin文件头0x200字节,loader.bin的加载地址是0x703 ,具体计算请看 README.md中此章节的笔记
   ; 故total_mem_bytes内存中的地址是0xb00.将来在内核中咱们会引用此地址
   total_mem_bytes:
        dd 0

    ;以下是定义gdt的指针，前2字节是gdt界限，后4字节是gdt起始地址
    gdt_ptr:
        dw  GDT_LIMIT
        dd  GDT_BASE

    ; 构建段选择子  ，13位索引值 + 1位TI + 2位RPL
    SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0         ; 相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT + RPL0
    SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0	 ; 同上
    SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0	 ; 同上

    ; 预留内存存放ARDS
    ards_buf:
        times 244 db 0
    ; ARDS的个数,后面用来遍历ARDS
    ards_nr:
        dw 0



    loader_start:
    ;-------  int 15h eax = 0000E820h ,edx = 534D4150h ('SMAP') 获取内存布局  -------
    xor ebx, ebx		      ;第一次调用时，ebx值要为0,  自己与自己进行异或操作结果为0
    mov edx, 0x534d4150	      ;edx只赋值一次，循环体中不会改变，固定值
    mov di, ards_buf	      ;ards结构缓冲区
    .e820_mem_get_loop:	      ;循环获取每个ARDS内存范围描述结构
        mov eax, 0x0000e820	      ;执行int 0x15后,eax值变为0x534d4150,所以每次执行int前都要更新为子功能号。
        mov ecx, 20		      ;ARDS地址范围描述符结构大小是20字节
        int 0x15
        jc .error_hlt         ;若cf位为1则有错误发生，则让CPU停止工作
        add di, cx		      ;使di增加20字节指向缓冲区中新的ARDS结构位置
        inc word [ards_nr]	      ;记录ARDS数量
        cmp ebx, 0		      ;若ebx为0且cf不为1,这说明ards全部返回，当前已是最后一个
        jnz .e820_mem_get_loop

    ;在所有ards结构中，找出(base_add_low + length_low)的最大值，即内存的容量。
    mov cx, [ards_nr]	      ;遍历每一个ARDS结构体,循环次数是ARDS的数量
    mov ebx, ards_buf
    xor edx, edx		;edx为最大的内存容量,在此先清0
    .find_max_mem_area:	      ;无须判断type是否为1,最大的内存块一定是可被使用
       mov eax, [ebx]	      ;base_add_low
       add eax, [ebx+8]	      ;length_low
       add ebx, 20		      ;指向缓冲区中下一个ARDS结构
       cmp edx, eax		      ;冒泡排序，找出最大,edx寄存器始终是最大的内存容量
       jge .next_ards
       mov edx, eax		      ;edx为总内存大小
    .next_ards:
       ;xchg bx,bx
       loop .find_max_mem_area
       jmp .mem_get_ok

    .mem_get_ok:
       xchg bx,bx
       mov [total_mem_bytes], edx	 ;将内存换为byte单位后存入total_mem_bytes处。


    xchg bx,bx

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

   .error_hlt:		      ;出错则挂起
       hlt

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