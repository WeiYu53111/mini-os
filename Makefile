BUILD:=./build


# ------- 定义工具和标志 -------
LIB:=-I kernel/ -I lib/ -I lib/kernel/ -I lib/user/ -I device/ -I thread/
CFLAGS:=-std=gnu11 -Wall $(LIB) -fno-builtin -Wstrict-prototypes -Wimplicit-function-declaration -Wmissing-prototypes -fstack-protector
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
ASM_SOURCES = $(wildcard lib/kernel/*.asm thread/*.asm)
C_SOURCES = $(wildcard device/*.c lib/kernel/*.c kernel/*.c thread/*.c)
#ASM_OBJECTS = $(patsubst %.asm,${BUILD}/%.o,$(notdir $(ASM_SOURCES)))
#C_OBJECTS = $(patsubst %.c,${BUILD}/%.o,$(notdir $(C_SOURCES)))
BOOT_SOURCE =  $(wildcard boot/*.asm)
BOOT_OBJECTS = $(patsubst %.asm,${BUILD}/%.o,$(notdir $(BOOT_SOURCE)))

OBJS = $(BUILD)/main.o $(BUILD)/init.o $(BUILD)/interrupt.o \
      $(BUILD)/timer.o $(BUILD)/kernel.o $(BUILD)/print.o \
      $(BUILD)/debug.o $(BUILD)/memory.o $(BUILD)/bitmap.o \
      $(BUILD)/string.o $(BUILD)/thread.o $(BUILD)/list.o \
      $(BUILD)/switch.o

# ------- 编译规则 -------
${BUILD}/%.o: boot/%.asm
	nasm -f bin -i boot/include/ $< -o $@

# kernel目录下所有汇编脚本
${BUILD}/%.o: lib/kernel/%.asm
	nasm -f elf32 $< -o $@

# thread目录下所有汇编脚本
${BUILD}/%.o: thread/%.asm
	nasm -f elf32 $< -o $@

$(BUILD)/%.o: device/%.c
	gcc -m32 -c $(CFLAGS) -o $@ $<

$(BUILD)/%.o: kernel/%.c
	gcc -m32 -c $(CFLAGS) -o $@ $<

$(BUILD)/%.o: lib/kernel/%.c
	gcc -m32 -c $(CFLAGS) -o $@ $<

$(BUILD)/%.o: thread/%.c
	gcc -m32 -c $(CFLAGS) -o $@ $<

# 第一个链接目标文件必须是main.o,否则entry point address地址会变，从而启动不了
$(BUILD)/kernel.bin: $(OBJS)
	# 两个echo命令是用来查看目标文件是否有缺漏的
	@echo $(ASM_OBJECTS)
	@echo $(C_OBJECTS)
	ld -m elf_i386 -Ttext 0xc0001000 -Map $(BUILD)/kernel.map -e main $^ -o $@
compile: ${BOOT_OBJECTS} ${BUILD}/kernel.bin

show_obj:
	@echo $(BOOT_OBJECTS)
	@echo $(OBJS)


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
	bochs -q -f bochsrc