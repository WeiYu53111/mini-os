BUILD:=./build


# ------- 定义工具和标志 -------
LIB:=-I kernel/ -I lib/ -I lib/kernel/ -I lib/user/ -I device/ -I thread/ -I userprog/ -I fs/
CFLAGS:=-g -std=gnu11 -Wall $(LIB) -fno-builtin -Wstrict-prototypes -Wimplicit-function-declaration -Wmissing-prototypes -fno-stack-protector
# ---------------------------- 清理
clean:
	# 清理上一次的生成结果
	echo "delete dir build"
	rm -rf $(BUILD)

# ---------------------------- 初始化,创建文件夹
init:
	# 初始化,创建目录
	mkdir -p $(BUILD)

# ---------------------------- 编译生成目标文件、可执行文件
# ------- 源文件和对象文件 -------
#ASM_SOURCES = $(wildcard lib/kernel/*.asm thread/*.asm)
#C_SOURCES = $(wildcard device/*.c lib/*.c lib/kernel/*.c lib/user/*.c kernel/*.c thread/*.c userprog/*.c fs/*.c)
#ASM_OBJECTS = $(patsubst %.asm,${BUILD}/%.o,$(notdir $(ASM_SOURCES)))
#C_OBJECTS = $(patsubst %.c,${BUILD}/%.o,$(notdir $(C_SOURCES)))
#BOOT_SOURCE =  $(wildcard boot/*.asm)
#BOOT_OBJECTS = $(patsubst %.asm,${BUILD}/%.o,$(notdir $(BOOT_SOURCE)))
BOOT_OBJECTS = $(BUILD)/mbr.o $(BUILD)/loader.o
OBJS = $(BUILD)/main.o $(BUILD)/init.o $(BUILD)/interrupt.o \
      $(BUILD)/timer.o $(BUILD)/kernel.o $(BUILD)/print.o \
      $(BUILD)/debug.o $(BUILD)/memory.o $(BUILD)/bitmap.o \
      $(BUILD)/string.o $(BUILD)/thread.o $(BUILD)/list.o \
      $(BUILD)/switch.o $(BUILD)/console.o $(BUILD)/sync.o \
      $(BUILD)/ioqueue.o $(BUILD)/keyboard.o $(BUILD)/tss.o $(BUILD)/process.o \
      $(BUILD)/syscall-init.o $(BUILD)/syscall.o $(BUILD)/stdio.o \
      $(BUILD)/ide.o $(BUILD)/stdio-kernel.o $(BUILD)/fs.o \
      $(BUILD)/dir.o $(BUILD)/file.o $(BUILD)/inode.o

# ------- 编译规则 -------
vpath %.c device/ fs/ kernel/ lib/ lib/user/ lib/kernel thread/ userprog/
vpath %.asm lib/kernel/ thread/

${BUILD}/%.o: boot/%.asm
	nasm -f bin -i boot/include/ $< -o $@

${BUILD}/%.o: %.asm
	nasm -f elf32 $< -o $@

$(BUILD)/%.o: %.c
	gcc -m32 -c $(CFLAGS) -o $@ $<


# 第一个链接目标文件必须是main.o,否则entry point address地址会变，从而启动不了
$(BUILD)/kernel.bin: $(OBJS)
	# 两个echo命令是用来查看目标文件是否有缺漏的
	@echo $(ASM_OBJECTS)
	@echo $(C_OBJECTS)
	ld -m elf_i386 -Ttext 0xc0001000 -Map $(BUILD)/kernel.map -e main $^ -o $@
compile: ${BOOT_OBJECTS} ${BUILD}/kernel.bin

show_obj:
	@echo $(C_SOURCES)
	#@echo $(BOOT_OBJECTS)
	#@echo $(OBJS)


# ---------------------------- 写入磁盘文件
write:
	rm -f $(BUILD)/hd.img $(BUILD)/hd.img.lock
	# 创建磁盘
	bximage -q -func=create -hd=60M $(BUILD)/hd.img
	# 将boot机器码写入磁盘的第一个扇区
	dd if=$(BUILD)/mbr.o of=$(BUILD)/hd.img bs=512 count=1 conv=notrunc
	# 将加载器机器码写入磁盘的第一个扇区
	dd if=$(BUILD)/loader.o of=$(BUILD)/hd.img bs=512 count=4 seek=1 conv=notrunc
	# 将汇编写的main.asm编译得到的机器码写入磁盘文件
	#dd if=$(BUILD)/kernel/main.o of=$(BUILD)/hd.img bs=512 count=1 seek=5 conv=notrunc
	# 将C语言写main.c编译得到的机器码写入磁盘文件
	dd if=$(BUILD)/kernel.bin of=$(BUILD)/hd.img bs=512 count=200 seek=10 conv=notrunc
	# 删除磁盘2上一次运行产生的锁
	rm -f hd2.img.lock

bochs:init compile write
	bochs -q -f bochsrc

# ---------------------------- 执行同步脚本,里面会上传代码、远程执行编译、下载编译后的输出文件
sync:
	sh sync.sh

# ---------------------------- 云服务器（x86架构），本地（arm64）运行bochs,磁盘中的内容来自远程服务器
bochs-remote: clean sync write
	# sync 执行同步脚本并
	bochs -q -f bochsrc

bochs-remote-run-only:
	# 删除上一次运行的文件锁
	rm -f $(BUILD)/hd.img.lock
	rm -f hd2.img.lock
	bochs -q -f bochsrc
