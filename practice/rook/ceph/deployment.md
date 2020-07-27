

# 利用helm部署
https://rook.io/docs/rook/v1.1/helm-operator.html  

```bash
git clone https://github.com/rook/rook.git
# 查看版本。然后切换分支。切换分支之后按照官方文档的方式进行部署
git checkout release-1.1

```

k8s三个节点：
每个节点都加载一块无格式化的硬盘，因为使用官方的部署方式，不自己进行修改`cluster.yaml`的参数的话，会自动扫描磁盘。上生产环境的时候，需要自己指定磁盘类型

```yaml
# 案例介绍
# 其中bluestore是直接使用裸磁盘的意思，会加打磁盘的效率
# filestore
nodes:
- name: "master001"
  devices:
  - name: "sdb"
  - name: "sdc"
  config:
    storeType: bluestore
- name: "master002"
  devices:
  - name: "sdb"
  - name: "sdc"
  config:
    storeType: bluestore
- name: "master003"
  devices:
  - name: "sdb"
  - name: "sdc"
  config:
    storeType: bluestore
```

**以下直接摘抄官网的**  

## Ceph Storage快速入门
本指南将引导您完成Ceph集群的基本设置，并使您能够使用集群中运行的其他Pod的块，对象和文件存储。

### 最低版本

Rook支持Kubernetes v1.10或更高版本。

### 先决条件

如果您要`dataDirHostPath`在kubernetes主机上持久保留rook数据，请确保您的主机在指定路径上至少有5GB的可用空间。

如果您感到幸运，可以使用以下kubectl命令和示例yaml文件创建一个简单的Rook集群。有关更详细的安装，请跳至下一部分以部署Rook运算符。

```
cd cluster/examples/kubernetes/ceph
kubectl create -f common.yaml
kubectl create -f operator.yaml
# cluster测试就使用下面的yaml
kubectl create -f cluster-test.yaml
# 正式环境使用
kubectl create -f cluster.yaml
```

集群运行后，您可以创建块，对象或文件存储，以供集群中的其他应用程序使用。

**分割线**  
到达此步骤已经可以见到基本情况，并且使用`toolbox`进行查看

**分割线，以下摘抄官网**  
[官方文档](https://rook.io/docs/rook/v1.1/ceph-toolbox.html)    

Rook工具箱是一个容器，其中包含用于rook调试和测试的常用工具。该工具箱基于`CentOS`，因此可以使用轻松安装更多选择的工具`yum`。

在`Kubernetes`中运行工具箱

Rook工具箱可以作为Kubernetes集群中的部署运行。确保已部署`rook`的`Kubernetes`集群正在运行时（请参阅Kubernetes说明），启动`rook-ceph-tools` `pod`。

将工具规范另存为[toolbox.yaml](https://kubernetes.hankbook.cn/manifests/example/rook/toolbox.yaml)：

```
略，请点击链接查看
```

启动`rook-ceph-tools` `pod`：

```
kubectl create -f toolbox.yaml
```

等待工具箱窗格下载其容器并进入 `running` 状态：

```bash
kubectl -n rook-ceph get pod -l "app=rook-ceph-tools"
```

`rook-ceph-tools` `pod`运行后，您可以使用以下命令连接到它：
```
kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') bash
```

工具箱中的所有可用工具均已准备就绪，可满足您的故障排除需求。例：

```
ceph status
ceph osd status
ceph df
rados df
```

使用完工具箱后，可以删除部署：

```
kubectl -n rook-ceph delete deployment rook-ceph-tools
```

### 网页请求
进入到`cluster`
```bash
cd cluster/examples/kubernetes/ceph
kubectl apply -f dashboard-external-https.yaml
# 查看端口号。也可以自定义好端口号
kubectl get svc -n rook-ceph | grep rook-ceph-mgr-dashboard-external-https
```
然后使用火狐浏览器进行打开。使用其他浏览器还需要自行配置  
https://10.10.10.5:32231
```bash
# 获取密码
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o yaml | grep "password:" | awk '{print $2}' | base64 --decode
```

### 默认存储地方

```
cat cluster.yaml
```
可以看到 `dataDirHostPath: /var/lib/rook` 字段还有`spec.storage.directories.path`也需要修改成一样的  
可以根据自己的需求进行修改

### 测试
搭建一个`wordpress`

```bash
cd cluster/examples/kubernetes
# 创建storageclass
ceph/csi/rbd/storageclass.yaml
kubectl apply -f mysql.yaml
# 请记住修改service为nodeport。
kubectl apply -f wordpress.yaml
```
