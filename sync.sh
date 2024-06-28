
#------------------- 定义环境变量
user=root
host=2c

# 远程目录
remote_root_dir=/root/mini-os
remote_boot=$remote_root_dir/boot
remote_kernel=$remote_root_dir/kernel
remote_build=$remote_root_dir/build
# 本地目录
local_build=.


#------------------- 上传代码到
ssh root@2c "mkdir -p $remote_build"
scp -r boot $user@$host:$remote_root_dir
scp -r kernel $user@$host:$remote_root_dir
scp -r device $user@$host:$remote_root_dir
scp -r Makefile $user@$host:$remote_root_dir
scp -r lib $user@$host:$remote_root_dir

#------------------- 远程执行make

ssh root@2c << ENDSSH | grep '^>' | cut -d '>' -f2
  cd "$remote_root_dir"
  make clean
  make init
  make compile
ENDSSH


#------------------- 删除上次编译的文件
rm -rf build

#------------------- 下载编译好的文件
mkdir -p $local_build
scp -r $user@$host:$remote_build $local_build/



