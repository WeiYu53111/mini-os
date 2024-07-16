
; 将boot.inc引进进来
%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ 0x7c00
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
       ;xchg bx,bx
       mov [total_mem_bytes], edx	 ;将内存换为byte单位后存入total_mem_bytes处。

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
       mov byte [gs:162], 'r'
       mov byte [gs:164], 'o'
       mov byte [gs:166], 't'
       mov byte [gs:168], 'e'
       mov byte [gs:170], 'c'
       mov byte [gs:172], 't'

        ;--------加载 main

        mov eax,KERNEL_START_SECTOR	    ; 起始扇区lba地址
        mov ebx,KERNEL_LOAD_ADDR        ; 写入的地址
        mov cx,200			            ; 待读入的扇区数
        ;xchg bx,bx
        call rd_disk_m_32		        ; 以下读取程序的起始部分（一个扇区）
       ; ---------------------------------------------------------------------------
       ; 开启分页
       ;(1 ）准备好页目录表及页表。
       ;(2 ）将页表地址写入控制寄存器 cr3
       ;(3 ）寄存器 的 PG 位置
       ;创建分页
       ;xchg bx,bx
       call setup_page

       ;开启分页功能
       ;xchg bx,bx
       call open_page
       ;lgdt [gdt_ptr]
        ;xchg bx,bx
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;  此时不刷新流水线也没问题  ;;;;;;;;;;;;;;;;;;;;;;;;
        ;由于一直处在32位下,原则上不需要强制刷新,经过实际测试没有以下这两句也没问题.
        ;但以防万一，还是加上啦，免得将来出来莫句奇妙的问题.
        jmp SELECTOR_CODE:enter_kernel	  ;强制刷新流水线

    enter_kernel:
        xchg bx,bx
        nop
        call kernel_init
        xchg bx,bx
        jmp SELECTOR_CODE:KERNEL_START_ADDR

    ;-------------   创建页目录及页表   ---------------
    setup_page:
        ;先把页目录占用的空间逐字节清0
        mov ecx, 4096
        mov esi, 0
        .clear_page_dir:
            mov byte [PAGE_DIR_TABLE_POS + esi], 0
            inc esi
            loop .clear_page_dir

        ;开始创建页目录项(PDE)
        .create_pde:				     ; 创建Page Directory Entry
            mov eax, PAGE_DIR_TABLE_POS
            add eax, 0x1000 			     ; 此时eax为第一个页表的位置及属性
            mov ebx, eax				     ; 此处为ebx赋值，是为.create_pte做准备，ebx为基址。

       ;   一个页表可表示4MB内存,下面将1mb内存映射到第一个页表，
       ;   保证加载器的代码在开启分页后能够正常运行，最简单的方式就是直接原地址映射之后不变
       or eax, PG_US_U | PG_RW_W | PG_P	     ; 页目录项的属性RW和P位为1,US为1,表示用户属性,所有特权级别都可以访问.
       mov [PAGE_DIR_TABLE_POS + 0x0], eax       ; 第1个目录项,在页目录表中的第1个目录项写入第一个页表的位置(0x101000)及属性(7)

       ;   创建页表项
       mov ecx ,256   ; 1mb / 4k = 256个页
       mov esi,0
       mov edx,PG_US_U | PG_RW_W | PG_P
       call create_pte


       ;---------------------------------------创建内核段的  PDE以及PTE
       ;内核按照规定应该放在虚拟地址的3g~4g, 起始地址是0xc0000000 取高10位 计算页目录项
       ;0xc0000000 ,  11_0000_0000 =0x300 = 768
       ;xchg bx,bx
       mov eax,PAGE_DIR_TABLE_POS + 0x2000   ; 0x101000被上面用了，0x102000还没有人用,本节中也没人用了，所以放这里
       mov ebx,eax
       or eax,PG_US_U | PG_RW_W | PG_P  ; 页目录项的属性US,RW和P位都为1
       mov [PAGE_DIR_TABLE_POS + 0xc00],eax

       ;创建页表项
       ;bochs当前模拟的内存大小是64mb,我们把kernel.bin加载16mb处,segment复制到3mb处
       ;所以要将0xc0000000映射到3mb处，映射多少与kernel.bin一样，暂时先映射4mb
       mov ecx,1024
       mov esi,0
       mov edx, KERNEL_SEGMENT_LOAD_ADDR ;edx就是要映射的地址
       or edx,PG_US_U | PG_RW_W | PG_P
       call create_pte

      ;-----------------------------创建kernel.bin的 PDE以及PTE，
      ;因为解析ELF头的时候是在开启分页之后，解析的时候只能使用虚拟地址
      ;因此直接将16mb的虚拟地址映射到物理地址16mb处，这样子
      ;16mb二进制表示  00_00000_10000_00000_00000_00000_00000
      ;高10位为4，中间10位为0，低12位为0,对应 第二个页目录项、第0个页表的第0个页表项
      mov eax,PAGE_DIR_TABLE_POS + 0x3000
      mov ebx,eax
      or eax,PG_US_U | PG_RW_W | PG_P
      mov [PAGE_DIR_TABLE_POS+0x10],eax

      ; 接下来是页表的映射，因为我们写的内核大小目前还很小，先暂时映射个4mb吧也就是把整个页表映射完
      mov ecx,1024
      mov esi,0
      mov edx,0x1000000
      or edx,PG_US_U | PG_RW_W | PG_P
      call create_pte


      ; 为后续内存申请模块 记录页目录的起始地址
      mov eax,PAGE_DIR_TABLE_POS
      or eax,PG_US_U | PG_RW_W | PG_P
      mov [PAGE_DIR_TABLE_POS + 4092],eax


      ret ; setup_page结束

   create_pte:
       mov [ebx+esi*4],edx;此时的ebx已经在上面通过eax赋值为0x101000,也就是第一个页表的地址
       add edx,4096
       inc esi
       loop create_pte
       ret


    open_page:
       ; 把页目录地址赋给cr3
       mov eax, PAGE_DIR_TABLE_POS
       mov cr3, eax

       ; 打开cr0的pg位(第31位)
       mov eax, cr0
       or eax, 0x80000000
       mov cr0, eax
       ret


   ;-------------------------------------------------------------------------------
   ;功能:读取硬盘n个扇区
   rd_disk_m_32:
   ;-------------------------------------------------------------------------------
   							 ; eax=LBA扇区号
   							 ; ebx=将数据写入的内存地址
   							 ; ecx=读入的扇区数
         mov esi,eax	   ; 备份eax
         mov di,cx		   ; 备份扇区数到di
   ;读写硬盘:
   ;第1步：设置要读取的扇区数
         mov dx,0x1f2
         mov al,cl
         out dx,al            ;读取的扇区数
         mov eax,esi	   ;恢复ax

   ;第2步：将LBA地址存入0x1f3 ~ 0x1f6

         ;LBA地址7~0位写入端口0x1f3
         mov dx,0x1f3
         out dx,al

         ;LBA地址15~8位写入端口0x1f4
         mov cl,8
         shr eax,cl
         mov dx,0x1f4
         out dx,al

         ;LBA地址23~16位写入端口0x1f5
         shr eax,cl
         mov dx,0x1f5
         out dx,al

         shr eax,cl
         and al,0x0f	   ;lba第24~27位
         or al,0xe0	   ; 设置7～4位为1110,表示lba模式
         mov dx,0x1f6
         out dx,al

   ;第3步：向0x1f7端口写入读命令，0x20
         mov dx,0x1f7
         mov al,0x20
         out dx,al

   ;;;;;;; 至此,硬盘控制器便从指定的lba地址(eax)处,读出连续的cx个扇区,下面检查硬盘状态,不忙就能把这cx个扇区的数据读出来

   ;第4步：检测硬盘状态
     .not_ready:		   ;测试0x1f7端口(status寄存器)的的BSY位
         ;同一端口,写时表示写入命令字,读时表示读入硬盘状态
         nop
         in al,dx
         and al,0x88	   ;第4位为1表示硬盘控制器已准备好数据传输,第7位为1表示硬盘忙
         cmp al,0x08
         jnz .not_ready	   ;若未准备好,继续等。

   ;第5步：从0x1f0端口读数据
         mov ax, di	   ;以下从硬盘端口读数据用insw指令更快捷,不过尽可能多的演示命令使用,
   			   ;在此先用这种方法,在后面内容会用到insw和outsw等

         mov dx, 256	   ;di为要读取的扇区数,一个扇区有512字节,每次读入一个字,共需di*512/2次,所以di*256
         mul dx
         mov cx, ax
         mov dx, 0x1f0
     .go_on_read:
         in ax,dx
         mov [ebx], ax
         add ebx, 2
   			  ; 由于在实模式下偏移地址为16位,所以用bx只会访问到0~FFFFh的偏移。
   			  ; loader的栈指针为0x900,bx为指向的数据输出缓冲区,且为16位，
   			  ; 超过0xffff后,bx部分会从0开始,所以当要读取的扇区数过大,待写入的地址超过bx的范围时，
   			  ; 从硬盘上读出的数据会把0x0000~0xffff的覆盖，
   			  ; 造成栈被破坏,所以ret返回时,返回地址被破坏了,已经不是之前正确的地址,
   			  ; 故程序出会错,不知道会跑到哪里去。
   			  ; 所以改为ebx代替bx指向缓冲区,这样生成的机器码前面会有0x66和0x67来反转。
   			  ; 0X66用于反转默认的操作数大小! 0X67用于反转默认的寻址方式.
   			  ; cpu处于16位模式时,会理所当然的认为操作数和寻址都是16位,处于32位模式时,
   			  ; 也会认为要执行的指令是32位.
   			  ; 当我们在其中任意模式下用了另外模式的寻址方式或操作数大小(姑且认为16位模式用16位字节操作数，
   			  ; 32位模式下用32字节的操作数)时,编译器会在指令前帮我们加上0x66或0x67，
   			  ; 临时改变当前cpu模式到另外的模式下.
   			  ; 假设当前运行在16位模式,遇到0X66时,操作数大小变为32位.
   			  ; 假设当前运行在32位模式,遇到0X66时,操作数大小变为16位.
   			  ; 假设当前运行在16位模式,遇到0X67时,寻址方式变为32位寻址
   			  ; 假设当前运行在32位模式,遇到0X67时,寻址方式变为16位寻址.

         loop .go_on_read
         ret

    ;-----------------   将kernel.bin中的segment拷贝到编译的地址   -----------
    kernel_init:
       xor eax, eax
       xor ebx, ebx		;ebx记录程序头表地址
       xor ecx, ecx		;cx记录程序头表中的program header数量
       xor edx, edx		;dx 记录program header尺寸,即e_phentsize


       ;xchg bx,bx
       ; 获取到程序头表的起始位置 e_phoff偏移文件开始部分28字节的地方是e_phoff
       ;mov ebx,[KERNEL_LOAD_ADDR + 28]
       ; 前面只是获取到偏移量,需要加上起始地址
       ;add ebx,KERNEL_LOAD_ADDR
       ; 偏移文件开始部分44字节的地方是e_phnum,表示有几个program header
       ;mov cx, [KERNEL_LOAD_ADDR + 44]
       ; 偏移文件42字节处的属性是e_phentsize,表示program header大小
       ;mov dx, [KERNEL_LOAD_ADDR + 42]


      mov dx, [KERNEL_LOAD_ADDR + 42]	  ; 偏移文件42字节处的属性是e_phentsize,表示program header大小
      mov ebx, [KERNEL_LOAD_ADDR + 28]   ; 偏移文件开始部分28字节的地方是e_phoff,表示第1 个program header在文件中的偏移量
                      ; 其实该值是0x34,不过还是谨慎一点，这里来读取实际值
      add ebx, KERNEL_LOAD_ADDR
      mov cx, [KERNEL_LOAD_ADDR + 44]    ; 偏移文件开始部分44字节的地方是e_phnum,表示有几个program header

      ;xchg bx,bx
       ; 遍历所有segment
        .each_segment:
           cmp byte [ebx + 0], PT_NULL		  ; 若p_type等于 PT_NULL,说明此program header未使用。
           je .PTNULL

           ;此处由调用者来平栈，调用约定是 cdecl, 参数从右往左入栈
           ;为函数memcpy压入参数,参数是从右往左依然压入.函数原型类似于 mem_cpy(dst,src,size)
           ;xchg bx,bx
           push dword [ebx + 16]		  ; program header中偏移16字节的地方是p_filesz,压入函数mem_cpy的第三个参数:size
           mov eax, [ebx + 4]			  ; 距程序头偏移量为4字节的位置是p_offset
           add eax, KERNEL_LOAD_ADDR  ; 加上kernel.bin被加载到的物理地址,eax为该段的物理地址
           push eax				      ; 压入函数mem_cpy的第二个参数:源地址
           push dword [ebx + 8]	      ; 压入函数mem_cpy的第一个参数:目的地址,偏移程序头8字节的位置是p_vaddr，这就是目的地址
           call mem_cpy				  ; 调用mem_cpy完成段复制
           add esp,12				  ; 清理栈中压入的三个参数
        .PTNULL:
           add ebx, edx				  ; edx为program header大小,即e_phentsize,在此ebx指向下一个program header
           loop .each_segment
           ret

        ;复制内存, 需要参数： 源起始地址，目标起始地址，复制内容总大小
        ;----------  逐字节拷贝 mem_cpy(dst,src,size) ------------
        ;输入:栈中三个参数(dst,src,size)
        ;输出:无
        ;---------------------------------------------------------
        mem_cpy:
            cld
            push ebp
            mov ebp, esp
            push ecx		   ; rep指令用到了ecx，但ecx对于外层段的循环还有用，故先入栈备份
            mov edi, [ebp + 8]	   ; dst
            mov esi, [ebp + 12]	   ; src
            mov ecx, [ebp + 16]	   ; size
            ;xchg bx,bx
            rep movsb		   ; 逐字节拷贝

            ;恢复环境
            pop ecx
            pop ebp
            ret



