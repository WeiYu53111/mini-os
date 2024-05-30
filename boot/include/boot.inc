;-------------	 loader和kernel   ----------
LOADER_BASE_ADDR equ 0x500                     ; loader起始位置
LOADER_START_SECTOR equ 0x1                    ; loader起始扇区编号


;--------------   gdt描述符属性  -------------

; G=1是用来表示段界限大小粒度为4K，G=0表示为 1字节，GDT描述符的高32位中的第23位
DESC_G_4K   equ	  1_00000000000000000000000b

; D/B位,如果该段时代码段则是D位，D=1表示指令中的有效地址以及操作是32位
; GDT描述符的高32位中的第22位
DESC_D_32   equ	   100_0000_0000_0000_0000_0000b

; L位,GDT描述符高32位中的第21位，L=1表示是64位代码标记，此时我们是保护模式，处于32位，此处标记为0便可。
DESC_L	    equ	    00_0000_0000_0000_0000_0000b

; AVL位，GDT描述符高32位中的第20位，  cpu不用此位，暂置为0
DESC_AVL    equ	     0_00000000000000000000b	;

;
DESC_LIMIT_CODE2  equ 1111_0000000000000000b
DESC_LIMIT_DATA2  equ DESC_LIMIT_CODE2
DESC_LIMIT_VIDEO2  equ 0000_000000000000000b

; P位,对应GDT描述高32位中的第16位，当P=1表示在内存中
DESC_P	    equ		  1_000000000000000b


; DPL位，特权级，对应GDT描述高32位中的第14-15位
DESC_DPL_0  equ		   00_0000000000000b
DESC_DPL_1  equ		   01_0000000000000b
DESC_DPL_2  equ		   10_0000000000000b
DESC_DPL_3  equ		   11_0000000000000b

; S位，对应GDT描述高32位中的第13位，S=0表示是系统段，S=1为非系统段
DESC_S_CODE equ		     1_000000000000b
DESC_S_DATA equ	         DESC_S_CODE
DESC_S_sys  equ		     0_000000000000b

;此处是对应GDT描述中高32位的第8-12位，type字段
;x=1,c=0,r=0,a=0 代码段是可执行的,非依从的,不可读的,已访问位a清0.
DESC_TYPE_CODE  equ	      1000_0000_0000b

;x=0,e=0,w=1,a=0 数据段是不可执行的,向上扩展的,可写的,已访问位a清0.
DESC_TYPE_DATA  equ	      0010_00000000b



; DESC_CODE_HIGH4 是GDT描述符的高4个字节，也就是高32位
; 最后的0x00 是低8位，对应的是段基址的 17~24位，平坦模型，所以都是0
; 00 << 24 后与各个变量想加，因此高8位是 0 ，对应段基址的最后8位
DESC_CODE_HIGH4 equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_CODE2 + DESC_P + DESC_DPL_0 + DESC_S_CODE + DESC_TYPE_CODE + 0x00
DESC_DATA_HIGH4 equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_DATA2 + DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x00
DESC_VIDEO_HIGH4 equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_VIDEO2 + DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x0b



;--------------   选择子属性  ---------------
RPL0  equ   00b
RPL1  equ   01b
RPL2  equ   10b
RPL3  equ   11b
TI_GDT	 equ   000b
TI_LDT	 equ   100b
