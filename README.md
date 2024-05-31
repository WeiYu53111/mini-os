# mini-os
跟着《操作系统真象还原》书写一个小系统，目的是通过写代码的过程中熟悉linux、以及C语言。我使用的是mac air m2，因此bochs配置会有所不同，以及后续编译C语言代码的时候会略有不同。
在跟着《操作系统真象还原》写代码前，我也看了《x86汇编语言：从实模式到保护模式（第2版)》一书，对x86架构的一些知识点有所了解。
该仓库只是为了让自己有一个输出与记录的地方。


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


# bochs配置

bochs版本是2.8，使用brew方式安装的
```shell
brew install bochs
```
此外还要安装sdl2
```shell
brew install sdl2
```
安装完成后，配置bochs，
1、从bochs的安装目录下复制配置文件模板，由于是brew安装的因此，模版文件目录是在
![img.png](note/img/bochs-sample.png)


2、需要修改配置文件中的选项如下：
```
# 交叉编译的时候使用这个
display_library: sdl2

# host设置bochs使用的内存, guest设置被模拟系统认为自己有多少内存 , block_size是指一个块的大小
memory: guest=64, host=64, block_size=512

# bios程序
romimage: file=/opt/homebrew/opt/bochs/share/bochs/BIOS-bochs-latest

# vgabios程序
vgaromimage: file=/opt/homebrew/opt/bochs/share/bochs/VGABIOS-lgpl-latest

# 启动方式为硬盘启动
boot: disk

# 指定启动硬盘文件在哪里
ata0: enabled=1, ioaddr1=0x1f0, ioaddr2=0x3f0, irq=14
ata0-master: type=disk, mode=flat, path="./build/hd.img"
```


# 运行说明
通过make命令编译程序、创建磁盘并编译后的机器码写入磁盘、运行bochs,详细请看Makefile。makefile知识在《操作系统真象还原》第8.1小节。
以下是运行命令的顺序：
```bash
# 编译程序、创建磁盘并编译后的机器码写入磁盘
make all
# 运行虚拟机启动我们写的操作系统
make bochs
```