# 存储驱动类型不是overlay2

发现,overlay2 是不能限制空间大小。然而 docker 19 版本出现了 容器默认的10G大小

检查
```bash
[root@k8s05 ~]# docker info|grep "Storage Driver"
 Storage Driver: devicemapper
WARNING: the devicemapper storage-driver is deprecated, and will be removed in a future release.
WARNING: devicemapper: usage of loopback devices is strongly discouraged for production use.
         Use `--storage-opt dm.thinpooldev` to specify a custom block storage device.
```

问题：

1. 系统版本内核过低导致的。
2. xfs的文件系统 ftype 不是为1
解决
```bash
yum update kernel -y
```

脚本修改，数据盘。不能修改/，因为需要格式化数据盘。

会 **删除所有数据** 请备份好


```bash
xfs_info /data
if [ $? -ne 0 ]; then
    echo "/data filesystem is not xfs, No need to rebuild"
    df -ihT | grep /data
else
    xfs_info /data | grep ftype=1
    if [ $? -ne 0 ]; then
        device=$(df -ihT | grep /data | gawk -F' '   '{print $1}')
        mountPoint=$(df -ihT | grep /data | gawk -F' '   '{print $7}')
        umount $device
        mkfs.xfs -n ftype=1 -f $device
        mount $device $mountPoint

        cat /etc/fstab | grep UUID
        if [ $? -eq 0 ]; then
            olduuid=$(cat /etc/fstab | grep /data | gawk -F' '   '{print $1}' | gawk -F'=' '{print $2}')
            uuid=$(blkid $device | gawk -F' '   '{print $2}' | gawk -F'"' '{print $2}')
            sed -i "s/$olduuid/$uuid/g" /etc/fstab
            cat /etc/fstab | grep /data
            blkid $device
        fi
        echo "Make /data(xfs) filesystem flag ftype=1 Success"
    else
        echo "/data filesystem alreay set ftype=1, No need to rebuild"
    fi
fi
```
