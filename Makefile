BUILD:=./build


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
compile:$(BUILD)/mbr.o ${BUILD}/loader.o $(BUILD)/print.o $(BUILD)/init.o $(BUILD)/interrupt.o $(BUILD)/kernel.o ${BUILD}/kernel.bin

${BUILD}/mbr.o: boot/mbr.asm
	nasm -i boot/include/ boot/mbr.asm -o ${BUILD}/mbr.o

${BUILD}/loader.o: boot/loader.asm
	nasm -i boot/include/ boot/loader.asm -o ${BUILD}/loader.o

#${BUILD}/kernel/main.o: kernel/main.asm
	#nasm -i boot/include/ kernel/main.asm -o ${BUILD}/kernel/main.o

$(BUILD)/print.o: lib/kernel/print.asm
	nasm -f elf32 lib/kernel/print.asm -o ${BUILD}/print.o

$(BUILD)/kernel.o: lib/kernel/kernel.asm
	nasm -f elf32 lib/kernel/kernel.asm -o ${BUILD}/kernel.o

$(BUILD)/init.o: lib/kernel/init.c
	# 生成32位的目标文件
	gcc -m32 -c -I lib/kernel -I lib -fno-builtin -o $(BUILD)/init.o lib/kernel/init.c

$(BUILD)/interrupt.o: lib/kernel/interrupt.c
	# 生成32位的目标文件
	gcc -m32 -c -I lib/kernel -I lib -fno-builtin -fstack-protector -o $(BUILD)/interrupt.o lib/kernel/interrupt.c

$(BUILD)/kernel.bin: kernel/main.c
	# 生成32位的目标文件
	gcc -m32 -c -I lib/kernel -I lib -fno-builtin -o $(BUILD)/main.o kernel/main.c
	# 使用链接器生成可执行文件
	ld -m elf_i386 -Ttext 0xc0001000 -e main -o $(BUILD)/kernel.bin $(BUILD)/main.o $(BUILD)/print.o \
	$(BUILD)/kernel.o $(BUILD)/init.o $(BUILD)/interrupt.o

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