# Volumes

容器中的文件在磁盘上是临时存放的，这给容器中运行的特殊应用程序带来一些问题。 首先，当容器崩溃时，kubelet 将重新启动容器，容器中的文件将会丢失——因为容器会以干净的状态重建。 其次，当在一个 Pod 中同时运行多个容器时，常常需要在这些容器之间共享文件。 Kubernetes 抽象出 Volume 对象来解决这两个问题。

## 背景
Docker 也有 Volume 的概念，但对它只有少量且松散的管理。 在 Docker 中，Volume 是磁盘上或者另外一个容器内的一个目录。 直到最近，Docker 才支持对基于本地磁盘的 Volume 的生存期进行管理。 虽然 Docker 现在也能提供 Volume 驱动程序，但是目前功能还非常有限（例如，截至 Docker 1.7，每个容器只允许有一个 Volume 驱动程序，并且无法将参数传递给卷）。

另一方面，Kubernetes 卷具有明确的生命周期——与包裹它的 Pod 相同。 因此，卷比 Pod 中运行的任何容器的存活期都长，在容器重新启动时数据也会得到保留。 当然，当一个 Pod 不再存在时，卷也将不再存在。也许更重要的是，Kubernetes 可以支持许多类型的卷，Pod 也能同时使用任意数量的卷。

卷的核心是包含一些数据的目录，Pod 中的容器可以访问该目录。 特定的卷类型可以决定这个目录如何形成的，并能决定它支持何种介质，以及目录中存放什么内容。

使用卷时, Pod 声明中需要提供卷的类型 (`.spec.volumes` 字段)和卷挂载的位置 (`.spec.containers.volumeMounts` 字段).

容器中的进程能看到由它们的 Docker 镜像和卷组成的文件系统视图。 Docker 镜像 位于文件系统层次结构的根部，并且任何 Volume 都挂载在镜像内的指定路径上。 卷不能挂载到其他卷，也不能与其他卷有硬链接。 Pod 中的每个容器必须独立地指定每个卷的挂载位置。

## Volume 的类型
Kubernetes 支持下列类型的卷：

- awsElasticBlockStore
- azureDisk
- azureFile
- cephfs
- cinder
- configMap
- csi
- downwardAPI
- emptyDir
- fc (fibre channel)
- flexVolume
- flocker
- gcePersistentDisk
- gitRepo (deprecated)
- glusterfs
- hostPath
- iscsi
- local
- nfs
- persistentVolumeClaim
- projected
- portworxVolume
- quobyte
- rbd
- scaleIO
- secret
- storageos
- vsphereVolume

### awsElasticBlockStore
awsElasticBlockStore 卷将 Amazon Web服务（AWS）EBS 卷 挂载到您的 Pod 中。 与 emptyDir 在删除 Pod 时会被删除不同，EBS 卷的内容在删除 Pod 时会被保留，卷只是被卸载掉了。 这意味着 EBS 卷可以预先填充数据，并且可以在 Pod 之间传递数据。

> 警告:您在使用 EBS 卷之前必须先创建它，可以使用 aws ec2 create-volume 命令进行创建；也可以使用 AWS API 进行创建。

使用 awsElasticBlockStore 卷时有一些限制：

- Pod 正在运行的节点必须是 AWS EC2 实例。
- 这些实例需要与 EBS 卷在相同的地域（region）和可用区（availability-zone）。
- EBS 卷只支持被挂载到单个 EC2 实例上。


#### 创建 EBS 卷

在将 EBS 卷用到 Pod 上之前，您首先要创建它。

```bash
aws ec2 create-volume --availability-zone=eu-west-1a --size=10 --volume-type=gp2
```
确保该区域与您的群集所在的区域相匹配。（也要检查卷的大小和 EBS 卷类型都适合您的用途！）

#### AWS EBS 配置示例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-ebs
spec:
  containers:
  - image: k8s.gcr.io/test-webserver
    name: test-container
    volumeMounts:
    - mountPath: /test-ebs
      name: test-volume
  volumes:
  - name: test-volume
    # This AWS EBS volume must already exist.
    awsElasticBlockStore:
      volumeID: <volume-id>
      fsType: ext4
```

### azureDisk
azureDisk 用来在 Pod 上挂载 Microsoft Azure [数据盘（Data Disk）](https://docs.microsoft.com/zh-cn/azure/virtual-machines/linux/managed-disks-overview?toc=%2Fazure%2Fvirtual-machines%2Flinux%2Ftoc.json) . 更多详情请[参考这里](https://github.com/kubernetes/examples/blob/master/staging/volumes/azure_disk/README.md)。

#### CSI迁移
> FEATURE STATE: Kubernetes v1.15 alpha

启用azureDisk的CSI迁移功能后，它会将所有插件操作从现有的内建插件填添加disk.csi.azure.com容器存储接口（CSI）驱动程序中。 为了使用此功能，必须在群集上安装 Azure磁盘CSI驱动程序， 并且 CSIMigration 和 CSIMigrationAzureDisk Alpha功能 必须启用。

### azureFile
azureFile 用来在 Pod 上挂载 Microsoft Azure 文件卷（File Volume） (SMB 2.1 和 3.0)。 更多详情请[参考这里](https://github.com/kubernetes/examples/tree/master/staging/volumes/azure_file/README.md)。

#### CSI迁移
> FEATURE STATE: Kubernetes v1.15 alpha

启用azureFile的CSI迁移功能后，它会将所有插件操作从现有的内建插件填添加file.csi.azure.com容器存储接口（CSI）驱动程序中。 为了使用此功能，必须在群集上安装 Azure文件CSI驱动程序， 并且 CSIMigration 和 CSIMigrationAzureFile Alpha功能 必须启用。

### cephfs

cephfs 允许您将现存的 CephFS 卷挂载到 Pod 中。不像 emptyDir 那样会在删除 Pod 的同时也会被删除，cephfs 卷的内容在删除 Pod 时会被保留，卷只是被卸载掉了。 这意味着 CephFS 卷可以被预先填充数据，并且这些数据可以在 Pod 之间”传递”。CephFS 卷可同时被多个写者挂载。

> 警告:在您使用 Ceph 卷之前，您的 Ceph 服务器必须正常运行并且要使用的 share 被导出（exported）。

更多信息请参考 [CephFS 示例](https://github.com/kubernetes/examples/tree/master/volumes/cephfs/)。

### cinder

> 注意：
先决条件：配置了OpenStack Cloud Provider 的 Kubernetes。 有关 cloudprovider 配置，请参考 cloud provider openstack。

cinder 用于将 OpenStack Cinder 卷安装到 Pod 中。

#### Cinder Volume示例配置
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-cinder
spec:
  containers:
  - image: k8s.gcr.io/test-webserver
    name: test-cinder-container
    volumeMounts:
    - mountPath: /test-cinder
      name: test-volume
  volumes:
  - name: test-volume
    # This OpenStack volume must already exist.
    cinder:
      volumeID: <volume-id>
      fsType: ext4
```

#### CSI迁移

> FEATURE STATE: Kubernetes v1.14 alpha

启用Cinder的CSI迁移功能后，它会将所有插件操作从现有的内建插件填添加 cinder.csi.openstack.org 容器存储接口（CSI）驱动程序中。 为了使用此功能，必须在群集上安装 [Openstack Cinder CSI驱动程序](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/using-cinder-csi-plugin.md)， 并且 CSIMigration 和 CSIMigrationOpenStack Alpha功能 必须启用。

### configMap

configMap 资源提供了向 Pod 注入配置数据的方法。 ConfigMap 对象中存储的数据可以被 configMap 类型的卷引用，然后被应用到 Pod 中运行的容器化应用。

当引用 configMap 对象时，你可以简单的在 Volume 中通过它名称来引用。 还可以自定义 ConfigMap 中特定条目所要使用的路径。 例如，要将名为 log-config 的 ConfigMap 挂载到名为 configmap-pod 的 Pod 中，您可以使用下面的 YAML：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-pod
spec:
  containers:
    - name: test
      image: busybox
      volumeMounts:
        - name: config-vol
          mountPath: /etc/config
  volumes:
    - name: config-vol
      configMap:
        name: log-config
        items:
          - key: log_level
            path: log_level
```

log-config ConfigMap 是以卷的形式挂载的， 存储在 log_level 条目中的所有内容都被挂载到 Pod 的 “/etc/config/log_level” 路径下。 请注意，这个路径来源于 Volume 的 mountPath 和 log_level 键对应的 path。

> 警告:
在使用 ConfigMap 之前您首先要创建它。

> 注意：
容器以 subPath 卷挂载方式使用 ConfigMap 时，将无法接收 ConfigMap 的更新。 (补充，以环境变量的方式也不能接收到更新)










参考文档：https://kubernetes.io/docs/concepts/storage/
