# dd测试

dd语法

```
dd if=path/to/input_file of=/path/to/output_file bs=block_size count=number_of_blocks
```

参数介绍

```
if=file 　　　　　　　　　　　　　　　　输入文件名，缺省为标准输入。
of=file 　　　　　　　　　　　　　　　　输出文件名，缺省为标准输出。
ibs=bytes 　　　　　　　　　　　　　　　一次读入 bytes 个字节(即一个块大小为 bytes 个字节)。
obs=bytes 　　　　　　　　　　　　　　　一次写 bytes 个字节(即一个块大小为 bytes 个字节)。
bs=bytes 　　　　　　　　　　　　　　　 同时设置读写块的大小为 bytes ，可代替 ibs 和 obs 。
cbs=bytes 　　　　　　　　　　　　　　　一次转换 bytes 个字节，即转换缓冲区大小。
skip=blocks 　　　　　　　　　　　　　 从输入文件开头跳过 blocks 个块后再开始复制。
seek=blocks      　　　　　　　　　　 从输出文件开头跳过 blocks 个块后再开始复制。(通常只有当输出文件是磁盘或磁带时才有效)。
count=blocks 　　　　　　　　　　　　　仅拷贝 blocks 个块，块大小等于 ibs 指定的字节数。
conv=conversion[,conversion...]    用指定的参数转换文件。
iflag=FLAGS　　　　　　　　　　　　　　指定读的方式FLAGS，参见“FLAGS参数说明”
oflag=FLAGS　　　　　　　　　　　　　　指定写的方式FLAGS，参见“FLAGS参数说明”
```

```
# 测试纯写入性能
dd if=/dev/zero of=test bs=8k count=10000 oflag=direct
# 测试纯读取性能
dd if=test of=/dev/null bs=8k count=10000 iflag=direct
```
