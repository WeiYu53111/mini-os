BUILD:=./build

clean:
	echo "delete dir build"
	rm -rf $(BUILD)

init:
	# 初始化,创建目录
	mkdir -p $(BUILD)/boot

all:init $(BUILD)/hd.img

$(BUILD)/hd.img:$(BUILD)/boot/mbr.o
	rm -f $(BUILD)/hd.img
	# 创建磁盘
	bximage -q -func=create -hd=60M $(BUILD)/hd.img
	# 将机器码写入磁盘的第一个扇区
	dd if=$(BUILD)/boot/mbr.o of=$(BUILD)/hd.img bs=512 count=1 conv=notrunc

${BUILD}/boot/mbr.o: boot/mbr.asm
	nasm boot/mbr.asm -o ${BUILD}/boot/mbr.o

bochs:$(BUILD)/hd.img
	bochs -q -f bochsrc