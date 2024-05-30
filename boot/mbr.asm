; vstart=0x7c00 声明该程序在内存中的起始地址
; 将boot.inc引进进来
%include "boot.inc"

section mbr vstart=0x7c00
    ; 初始化寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax  ;栈寄存器为什么也是 0 ？？？
    mov fs, ax  ;fs、gs 也是段寄存器之一
    mov sp, 0x7c00

    ; 显卡文本模式，显存与内存映射的范围是  0xB800 - 0xBFFF
    mov ax, 0xb800
    mov gs, ax
    mov gs, ax


    ; 清屏 利用0x06号功能，上卷全部行，则可清屏。
    ; -----------------------------------------------------------
    ;INT 0x10   功能号:0x06	   功能描述:上卷窗口
    ;------------------------------------------------------
    ;输入：
    ;AH 功能号= 0x06
    ;AL = 上卷的行数(如果为0,表示全部)
    ;BH = 上卷行属性
    ;(CL,CH) = 窗口左上角的(X,Y)位置
    ;(DL,DH) = 窗口右下角的(X,Y)位置
    ;无返回值：
    mov     ax, 0x600
    mov     bx, 0x700      ;定义将被滚动区域填充的字符属性（颜色）。
    mov     cx, 0          ; 左上角: (0, 0)
    mov     dx, 0x184f	   ; 右下角: (80,25),
			               ; VGA文本模式中,一行只能容纳80个字符,共25行。
			               ; 下标从0开始,所以0x18=24,0x4f=79
    int     0x10           ; int 中断指令, INT 0x10是BIOS提供的视频服务的中断号

    ; 输出字符串"hello word"
    ; 低字节是 ascii码
    ; 高字节中，低4位是前景色, 高4位是背景色, 而每4位，第4位用于指定颜色的明亮
    ; 0xf  = 0x0f   ,  0000 表示 黑色，  1111 表示 白色，  就是所谓 白字黑底

    mov byte [gs:0x00],'H'
    mov byte [gs:0x01],0xf     ; A表示绿色背景闪烁，4表示前景色为红色

    mov byte [gs:0x02],'e'
    mov byte [gs:0x03],0xf

    mov byte [gs:0x04],'l'
    mov byte [gs:0x05],0xf

    mov byte [gs:0x06],'l'
    mov byte [gs:0x07],0xf

    mov byte [gs:0x08],'o'
    mov byte [gs:0x09],0xf

    mov byte [gs:0x10],' '
    mov byte [gs:0x11],0xf     ; A表示绿色背景闪烁，4表示前景色为红色

    mov byte [gs:0x12],'w'
    mov byte [gs:0x13],0xf

    mov byte [gs:0x14],'o'
    mov byte [gs:0x15],0xf

    mov byte [gs:0x16],'r'
    mov byte [gs:0x17],0xf

    mov byte [gs:0x18],'d'
    mov byte [gs:0x19],0xf

    mov eax,LOADER_START_SECTOR	 ; 起始扇区lba地址
    mov bx,LOADER_BASE_ADDR       ; 写入的地址
    mov cx,4			 ; 待读入的扇区数
    call rd_disk_m_16		 ; 以下读取程序的起始部分（一个扇区）
    ;xchg bx, bx
    jmp LOADER_BASE_ADDR

    ; 读取硬盘函数实现
    rd_disk_m_16:
        ;保存  eax、 cx 寄存器
        mov esi , eax
        mov di , cx

        ;设置要读取的扇区数
        mov dx , 0x1f2
        mov al , cl  ; 在call rd_disk_m_16 前,往cx寄存器中写入 1 ,因此cl = 1
        out dx , al  ; 硬盘通过dx指定端口，al指定参数是指令规定的

        ;恢复eax寄存器，因为在调用该函数时,eax寄存器用来传递 LBA地址，在上一步中使用了al寄存器，因此现在要先恢复
        mov eax, esi

        ;指定LBA地址  0-7位
        mov dx , 0x1f3
        out dx , al  ; 此时eax是lba地址，al就是低 8位

        ;指定LBA地址  8-15位
        mov dx , 0x1f4
        shr eax , 8
        out dx, al ; shr右移 8位

        ;指定LBA地址16-23位
        mov dx , 0x1f5
        shr eax , 8
        out dx, al

        ;还剩4位
        ;向0x1f6端口是硬盘的device寄存器，低4位是LBA的剩余24-27位 ，写入读命令，0x20
        mov dx,0x1f6
        shr eax , 8
        and al , 0xf
        or al , 11100000b ; 第8、6位是1，不知道原因；第7位是 1是主盘、0是备盘
        out dx,al

        ; 0x1f7 次寄存器是用来存储硬盘要执行的命令的
        ; 0x20 是读扇区
        ; 0x30 是写扇区
        mov dx,0x1f7
        mov al,0x20
        out dx,al

    ;检测硬盘状态
    .not_ready:
        nop  ; nop命令起到延迟的作用, “nop”指令代表“无操作”(No Operation)
        in al,dx   ;同一端口，写时表示写入命令字，读时表示读入硬盘状态
        ;xchg bx, bx   ;断点调试, xchg 是bochs 特有的debug指令, 配置文件中需要配置 magic_break: enabled=1
        and al,10001000b; ;第4位为1表示硬盘控制器已准备好数据传输，第8位为1表示硬盘忙
        cmp al,00001000b  ; 表示硬盘已经不忙，且数据准备好了
        jnz .not_ready	   ;若未准备好，继续等。

        mov cx ,di  ; 在函数 rd_disk_m_16  一开始将入参 要读取的扇区数 cx 备份到了 di寄存器
        mov ax ,256
        mul cx  ; 隐含操作ax,al  ,此指令 =  eax = cx * ax
        mov cx ,ax;
        ; 注意,mul指令会把 dx清0，所以要在这里赋值
        mov dx,0x1f0  ; 0x1f0 读取数据的端口

    .read_data:
        in ax,dx
        mov [bx],ax
        add bx,2
        loop .read_data
        ret


    ; $表示当前代码行的偏移位置, $$表示整个程序起始位置
    times 510-($-$$) db 0
    db 0x55,0xaa    ; 硬件规定加载的第一个扇区最后两个字节一定是  0x55 0xaa否则报错

