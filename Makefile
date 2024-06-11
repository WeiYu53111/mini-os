BUILD:=./build


# ---------------------------- 清理
clean:
	# 清理上一次的生成结果
	echo "delete dir build"
	rm -rf $(BUILD)

# ---------------------------- 初始化,创建文件夹
init:
	# 初始化,创建目录
	mkdir -p $(BUILD)/boot
	mkdir -p $(BUILD)/kernel

# ---------------------------- 编译生成目标文件、可执行文件
compile:$(BUILD)/boot/mbr.o ${BUILD}/boot/loader.o ${BUILD}/kernel/kernel.bin

${BUILD}/boot/mbr.o: boot/mbr.asm
	nasm -i boot/include/ boot/mbr.asm -o ${BUILD}/boot/mbr.o

${BUILD}/boot/loader.o: boot/loader.asm
	nasm -i boot/include/ boot/loader.asm -o ${BUILD}/boot/loader.o

${BUILD}/kernel/main.o: kernel/main.asm
	nasm -i boot/include/ kernel/main.asm -o ${BUILD}/kernel/main.o

$(BUILD)/kernel/kernel.bin: kernel/main.c
	# 生成32位的目标文件
	gcc -m32 -c -o $(BUILD)/kernel/main.o kernel/main.c
	# 使用链接器生成可执行文件
	ld -m elf_i386 $(BUILD)/kernel/main.o -Ttext 0xc0001000 -e main -o $(BUILD)/kernel/kernel.bin

# ---------------------------- 写入磁盘文件
write:compile
	rm -f $(BUILD)/hd.img $(BUILD)/hd.img.lock
	# 创建磁盘
	bximage -q -func=create -hd=60M $(BUILD)/hd.img
	# 将boot机器码写入磁盘的第一个扇区
	dd if=$(BUILD)/boot/mbr.o of=$(BUILD)/hd.img bs=512 count=1 conv=notrunc
	# 将加载器机器码写入磁盘的第一个扇区
	dd if=$(BUILD)/boot/loader.o of=$(BUILD)/hd.img bs=512 count=4 seek=1 conv=notrunc
	# 将汇编写的main.asm编译得到的机器码写入磁盘文件
	#dd if=$(BUILD)/kernel/main.o of=$(BUILD)/hd.img bs=512 count=1 seek=5 conv=notrunc
	# 将C语言写main.c编译得到的机器码写入磁盘文件
	dd if=$(BUILD)/kernel/kernel.bin of=$(BUILD)/hd.img bs=512 count=200 seek=10 conv=notrunc

bochs:init compile write
	bochs -q -f bochsrc

# ---------------------------- 执行同步脚本,里面会上传代码、远程执行编译、下载编译后的输出文件
sync:
	sh sync.sh

# ---------------------------- 运行bochs,磁盘中的内容来自远程服务器
bochs-remote: sync write
	# sync 执行同步脚本并
	bochs -q -f bochsrc

bochs-remote-run-only:
	bochs -q -f bochsrc