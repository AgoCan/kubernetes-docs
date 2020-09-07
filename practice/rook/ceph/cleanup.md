# 清理集群

如果要拆除群集并启动一个新群集，请注意以下需要清除的资源：

- `rook-ceph`名称空间：由`operator.yaml`和创建的`Rook`运算符和集群`cluster.yaml`（集群CRD）
- `/var/lib/rook`：集群中每台主机上的路径，其中`ceph mons`和`osds`缓存配置
请注意，如果您更改了默认名称空间或路径（例如`dataDirHostPath`示例`yaml`文件中的路径），则需要在这些说明中调整这些名称空间和路径。

**删除块和文件工件**
首先，您需要清理在Rook群集顶部创建的资源

这些命令将从块和文件演练中清除资源（卸载卷，删除卷声明等）。如果您没有完成本演练的那些部分，则可以跳过以下说明：

```bash
kubectl delete -f ../wordpress.yaml
kubectl delete -f ../mysql.yaml
kubectl delete -n rook-ceph cephblockpool replicapool
kubectl delete storageclass rook-ceph-block
kubectl delete -f csi/cephfs/kube-registry.yaml
kubectl delete storageclass rook-cephfs
```

**删除CephCluster CRD**

在清除了这些块和文件资源之后，您可以删除Rook群集。在删除Rook运算符和代理之前，删除它非常重要，否则资源可能无法正确清理。

```bash
kubectl -n rook-ceph delete cephcluster rook-ceph
```
在继续下一步之前，请验证群集CRD是否已删除。

```bash
kubectl -n rook-ceph get cephcluster
```
**删除操作员和相关资源**
这将开始Rook Ceph运算符以及所有其他资源的清理过程。这包括相关资源，例如代理程序和使用以下命令的发现守护程序集：
```bash
kubectl delete -f operator.yaml
kubectl delete -f common.yaml
```
**删除主机上的数据**

重要说明：最后的清理步骤要求删除群集中每个主机上的文件。`dataDirHostPath`群集CRD中指定的属性下的所有文件都需要删除。否则，在启动新群集时将保持不一致的状态。

连接到每台机器并删除`/var/lib/rook`，或由指定的路径`dataDirHostPath`。

将来，当我们基于`K8s`的本地存储功能时，将不需要此步骤。

如果您修改了演示设置，则可以根据设备，主机路径等进行其他清理。

`Rook for osds`使用的节点上的磁盘可以通过以下方法重置为可用状态：

***此处请不要乱执行，sgdisk --zap-all是删除所有分区的意思***
```bash
#!/usr/bin/env bash
DISK="/dev/sdb"
# Zap the disk to a fresh, usable state (zap-all is important, b/c MBR has to be clean)
# You will have to run this step for all disks.
sgdisk --zap-all $DISK

# These steps only have to be run once on each node
# If rook sets up osds using ceph-volume, teardown leaves some devices mapped that lock the disks.
ls /dev/mapper/ceph-* | xargs -I% -- dmsetup remove %
# ceph-volume setup can leave ceph-<UUID> directories in /dev (unnecessary clutter)
rm -rf /dev/ceph-*
```

**故障排除**

如果未按照上述顺序执行清除指令，或者您在清除群集时遇到困难，请尝试以下操作。

清理群集的最常见问题是`rook-ceph`名称空间或群集CRD无限期保持`terminating`状态。在删除所有名称空间之前，无法删除名称空间，因此请查看哪些资源正在等待终止。

看一下`pod`：
```
kubectl -n rook-ceph get pod
```

如果Pod仍在终止，则需要等待，否则尝试强行终止它 `（kubectl delete pod <name>）`。

现在查看集群CRD：

```
kubectl -n rook-ceph get cephcluster
```

如果即使您之前执行过delete命令，群集CRD仍然存在，请参阅下一节有关删除终结器的部分。

**删除群集CRD终结器**

创建群集CRD时，Rook运算符会自动添加终结器。使用终结器，操作员可以确保删除群集CRD之前，将清除所有块和文件安装。如果没有适当的清理，则占用存储空间的Pod将无限期地挂起，直到系统重新启动为止。

清洁安装座后，操作员负责卸下终结器。如果由于某种原因操作员无法删除终结器（即，该操作器不再运行），则可以使用以下命令手动删除终结器：

```
kubectl -n rook-ceph patch crd cephclusters.ceph.rook.io --type merge -p '{"metadata":{"finalizers": [null]}}'
```

在几秒钟内，您应该看到群集CRD已被删除，并且将不再阻止其他清理操作，例如删除rook-ceph名称空间。

**没删除成功**

```
kubectl api-resources -o name --verbs=list --namespaced| xargs -n 1 kubectl get --show-kind --ignore-not-found -n rook-ceph
kubectl -n rook-ceph patch cephcluster.ceph.rook.io rook-ceph -p '{"metadata": {"finalizers": []}}' --type=merge
```

# faq

错误信息

```
**[terminal]
debug 2019-12-12 03:24:27.347 7f3d2c10edc0  0 set uid:gid to 167:167 (ceph:ceph)
debug 2019-12-12 03:24:27.347 7f3d2c10edc0  0 ceph version 14.2.4 (75f4de193b3ea58512f204623e6c5a16e6c1e1ba) nautilus (stable), process ceph-osd, pid 5004
debug 2019-12-12 03:24:27.347 7f3d2c10edc0  0 pidfile_write: ignore empty --pid-file
debug 2019-12-12 03:24:27.368 7f3d2c10edc0 -1 missing 'type' file and unable to infer osd type
```

删除后，重新安装上会出现`osd`的pod起不来。解决方案如下

[参考文档](https://gist.github.com/cheethoe/49d9c1d0003e44423e54a060e0b3fbf1)
此文档或者需要科学上网

原文：
```
**[terminal]
# This will use osd.5 as an example
# ceph commands are expected to be run in the rook-toolbox
1) disk fails
2) remove disk from node
3) mark out osd. `ceph osd out osd.5`
4) remove from crush map. `ceph osd crush remove osd.5`
5) delete caps. `ceph auth del osd.5`
6) remove osd. `ceph osd rm osd.5`
7) delete the deployment `kubectl delete deployment -n rook-ceph rook-ceph-osd-id-5`
8) delete osd data dir on node `rm -rf /var/lib/rook/osd5`
9) edit the osd configmap `kubectl edit configmap -n rook-ceph rook-ceph-osd-nodename-config`
9a) edit out the config section pertaining to your osd id and underlying device.
10) add new disk and verify node sees it.
11) restart the rook-operator pod by deleting the rook-operator pod
12) osd prepare pods run
13) new rook-ceph-osd-id-5 will be created
14) check health of your cluster `ceph -s; ceph osd tree`
```
翻译后(经过测试没成功)：
```
**[terminal]
＃这将以osd.5为例
＃ceph命令应该在rook-toolbox中运行
1）磁盘出现故障
2）从节点中删除磁盘
3）标出osd。 `ceph osd out osd.5`
4）从crush map中删除。 `ceph osd crush remove osd.5`
5）删除caps `ceph auth del osd.5`
6）删除osd。 `ceph osd rm osd.5`
7）删除部署`kubectl delete deploy -n rook-ceph rook-ceph-osd-id-5`
8）删除节点rm -rf /var/lib/rook/osd5`上的osd数据目录
9）编辑osd configmap `kubectl edit configmap -n rook-ceph rook-ceph-osd-nodename-config`
9a）编辑与您的OSD ID和基础设备有关的config部分。
10）添加新磁盘并验证节点是否可见。
11）通过删除rook-operator pod重新启动rook-operator pod
12）OSD准备Pod运行
13）将创建新的rook-ceph-osd-id-5
14）检查集群将康状态`ceph -s; ceph osd tree`
```

------

自己修改并且启动

因为`osd`对磁盘类型，等一系列的选型问题。所以导致的创建失败。
所以需要修改`cluster.yaml`的`useAllDevices: `值改成`true`重新创建即可



[参考文档](https://rook.io/docs/rook/v1.1/ceph-common-issues.html#osd-pods-are-not-created-on-my-devices)
