BUILD:=./build

clean:
	# 清理上一次的生成结果
	echo "delete dir build"
	rm -rf $(BUILD)

init:
	# 初始化,创建目录
	mkdir -p $(BUILD)/boot

#
all:init $(BUILD)/hd.img

$(BUILD)/hd.img:$(BUILD)/boot/mbr.o ${BUILD}/boot/loader.o
	rm -f $(BUILD)/hd.img $(BUILD)/hd.img.lock
	# 创建磁盘
	bximage -q -func=create -hd=60M $(BUILD)/hd.img
	# 将boot机器码写入磁盘的第一个扇区
	dd if=$(BUILD)/boot/mbr.o of=$(BUILD)/hd.img bs=512 count=1 conv=notrunc
	# 将加载器机器码写入磁盘的第一个扇区
	dd if=$(BUILD)/boot/loader.o of=$(BUILD)/hd.img bs=512 count=4 seek=1 conv=notrunc

${BUILD}/boot/mbr.o: boot/mbr.asm
	nasm -i boot/include/ boot/mbr.asm -o ${BUILD}/boot/mbr.o

${BUILD}/boot/loader.o: boot/loader.asm
	nasm -i boot/include/ boot/loader.asm -o ${BUILD}/boot/loader.o

bochs:all
	bochs -q -f bochsrc