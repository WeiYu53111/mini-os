
; 将boot.inc引进进来
%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
    xchg bx, bx

    mov     ax, 0x600
    mov     bx, 0x700      ;定义将被滚动区域填充的字符属性（颜色）。
    mov     cx, 0          ; 左上角: (0, 0)
    mov     dx, 0x184f	   ; 右下角: (80,25),
			               ; VGA文本模式中,一行只能容纳80个字符,共25行。
			               ; 下标从0开始,所以0x18=24,0x4f=79
    int     0x10           ; int 中断指令, INT 0x10是BIOS提供的视频服务的中断号

    ; 显卡文本模式，显存与内存映射的范围是  0xB800 - 0xBFFF
    mov ax, 0xb800
    mov gs, ax

    mov byte [gs:0x00],'l'
    mov byte [gs:0x01],0xf     ; A表示绿色背景闪烁，4表示前景色为红色

    mov byte [gs:0x02],'o'
    mov byte [gs:0x03],0xf

    mov byte [gs:0x04],'a'
    mov byte [gs:0x05],0xf

    mov byte [gs:0x06],'d'
    mov byte [gs:0x07],0xf

    mov byte [gs:0x08],'e'
    mov byte [gs:0x09],0xf


    mov byte [gs:0x08],'r'
    mov byte [gs:0x09],0xf

    jmp $