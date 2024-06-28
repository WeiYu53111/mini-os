# mini-os
跟着《操作系统真象还原》书写一个小系统，目的是通过写代码的过程中熟悉linux、以及C语言。我使用的是mac air m2，因此bochs配置会有所不同，以及后续编译C语言代码的时候会略有不同。
在跟着《操作系统真象还原》写代码前，我也看了《x86汇编语言：从实模式到保护模式（第2版)》一书，对x86架构的一些知识点有所了解。
该仓库只是为了让自己有一个输出与记录的地方。


# 开发环境搭建

第5章 5.2开启分页只用到mac环境搭建即可。从第5章 5.3用C语言写内核 开始就要用云服务器x86架构的ubuntu去编译C脚本生成可执行的elf文件了。
为什么这麻烦？因为交叉编译环境还没搞定，要源码安装binutils、gcc。交叉编译等以后有时间再尝试。

[mac开发环境搭建](note/mac开发环境搭建.md)  
[云服务器开发环境搭建](note/云服务器开发环境搭建.md)

## 进度
### 2024-05-25  第1-2章 实验环境配置、MBR
通过bios提供的中断程序打印helloword功能的MBR程序，可用的bochs配置文件，串联各个步骤的Makefile编写
代码对应git commit记录为  HelloWord

### 2024-05-28  第3章 完善MBR
MBR程序中将BIOS中断打印字符方式改为内存映射的方式显示字符  
汇编实现读取硬盘，并封装成函数  
MBR从硬盘读取加载器并跳转到加载器运行
代码对应git commit记录为 "第三章代码-完善MBR"  
  [相关笔记](note/loader.md)

### 2024-05-30 第4章 进入保护模式
改动如下：  
1、loader程序变大，修改mbr程序读取多个扇区, 方便以后增大loader程序不用再改动mbr  
2、loader程序增加开启保护模式逻辑  
3、boot.inc增加常量配置项给loader使用  
代码对应git commit记录为 "第四章代码-进入保护模式"  
[相关笔记](note/protect.md)


### 2024-05-31 第5章 5.1获取物理内存大小
loader程序，使用BIOS中断0x15获取物理内存大小功能  
代码对应git commit记录为 "第5章 5.1获取物理内存大小"  
[相关笔记](note/memory_detect.md)

### 2024-06-03 第5章 5.2开启分页
loader程序中增加了以下逻辑  
1、读取硬盘，加载操作系统demo到16mb内存处  
2、创建页目录、页表并建立映射关系  
代码对应git commit记录为 "第5章 5.2开启分页"  
[相关笔记](note/virtual_memory.md)

### 2024-06-11 第5章 5.3 C语言编写内核
1、云服务器环境初始化
2、优化了Makefile中的target,方便Clion可以一键上传、远程编译、下载然后运行bochs
3、编写了sync.sh脚本用于同步、远程编译、下载编译后的目标文件、可执行文件
4、修改了loader脚本，增加了虚拟地址的映射关系创建逻辑、增加了elf文件头、segment头解析逻辑、增加了segment复制逻辑
代码对应git commit记录为 "第5章 5.3 C语言编写内核"
[相关笔记](note/elf.md)


### 2024-06-13 第6章 实现单个字符打印
1、汇编脚本print.asm实现put_char函数打印单个字符  
2、main.c中调用put_char函数输出"kernel"字符串  
3、修改Makefile、sync.sh增加同步lib目录以及print.asm的编译、链接  
代码对应git commit记录为 "第6章 实现单个字符打印"  
[相关笔记](note/print.md)


### 2024-06-14 第6章 实现字符串、整形打印
1、汇编实现put_str函数  
2、汇编实现put_int函数  
代码对应git commit记录为"第6章 实现字符串、整形打印"  
[相关笔记](note/print_int.md)

### 2024-06-24 第7章 时钟中断打印字符串
初始化了中断描述表，为时钟中断绑定了打印字符串函数
该小节知识点很多，详情请看笔记
代码对应git commit记录为"第7章 时钟中断打印字符串"  
[相关笔记](note/interrupt.md)


### 2024-06-28 第7章 设置8253提高时钟中断频率
通过设置8253提高时钟中断频率，为后续线程调度做准备
代码对应git commit记录为"第7章 设置8253提高时钟中断频率"  
[相关笔记](note/interrupt2.md)
