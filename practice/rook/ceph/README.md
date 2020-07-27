# rook-ceph
rook的部署安装环境要求

k8s三个节点分别有三块硬盘
```
**[terminal]
/dev/sda # 系统盘
/dev/sdb # 无格式化盘
/dev/sdc # 无格式化盘
```

`rook-ceph`只能使用`RWO`,不能使用`RWM`，官网解释`RBD: This driver is optimized for RWO pod access where only one pod may access the storage`


[ceph中文文档](http://docs.ceph.org.cn/)  不是`rook-ceph`的中文文档
