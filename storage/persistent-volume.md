# 持久卷
本文档描述了Kubernetes 中持久卷的当前状态。建议熟悉卷。

## 介绍
与管理计算实例相比，管理存储是一个明显的问题。PersistentVolume子系统为用户和管理员提供了一个API，该API从如何使用存储中抽象出如何提供存储的详细信息。为此，我们引入了两个新的API资源：PersistentVolume和PersistentVolumeClaim。

一个 PersistentVolume（PV）是已经由管理员提供或者动态使用供应的集群中的一块存储的存储类。它是集群中的资源，就像节点是集群资源一样。PV是类似于Volumes的卷插件，但是其生命周期独立于使用PV的任何单个Pod。此API对象捕获NFS，iSCSI或特定于云提供商的存储系统的存储实现的详细信息。

一个 PersistentVolumeClaim（PVC）是由用户进行存储的请求。它类似于pod。容器消耗节点资源，PVC消耗PV资源。Pod可以请求特定级别的资源（CPU和内存）。声明可以请求特定的大小和访问模式（例如，可以将它们安装为读/写一次或多次只读）。

虽然PersistentVolumeClaims允许用户使用抽象存储资源，但对于不同的问题，用户通常需要具有不同属性（例如性能）的PersistentVolume。集群管理员需要能够提供各种PersistentVolume，这些PersistentVolume不仅在大小和访问模式上有更多差异，而且还不让用户了解如何实现这些卷的细节。对于这些需求，有StorageClass资源。

## 卷和声明的生命周期
PV是集群中的资源。PVC是对这些资源的请求，并且还充当对资源的声明检查。PV和PVC之间的交互遵循以下生命周期：

### Provisioning（供应）

可以通过两种方式设置PV：静态或动态。

#### static（静态）
集群管理员创建许多PV。它们带有实际存储的详细信息，可供群集用户使用。它们存在于Kubernetes API中，可供使用。

#### Dynamic（动态）
当管理员创建的所有静态PV均与用户的PersistentVolumeClaim不匹配时，群集可能会尝试动态地为PVC专门配置一个卷。此设置基于StorageClasses：PVC必须请求 存储类，并且管理员必须已经创建并配置了该类，才能进行动态设置。要求该类的声明`""`实际上为其自身禁用了动态预配置。

要启用基于存储类别的动态存储配置，集群管理员需要 在API服务器上启用DefaultStorageClass 准入控制器。例如，这可以通过确保API服务器组件`DefaultStorageClass`的`--enable-admission-plugins`标志的值位于逗号分隔的有序列表中来完成。有关API服务器命令行标志的更多信息，请查看kube-apiserver文档。

### binding (绑定)
用户创建一个PersistentVolumeClaim，或者在动态预配置的情况下，已经创建了一个PersistentVolumeClaim，该请求具有特定的请求存储量和某些访问模式。主服务器中的控制回路监视新的PVC，找到匹配的PV（如果可能），并将它们绑定在一起。如果为新PVC动态设置了PV，则循环将始终将该PV绑定到PVC。否则，用户将始终获得至少他们想要的东西，但是音量可能会超过要求的东西。绑定后，无论绑定如何绑定，PersistentVolumeClaim绑定都是互斥的。PVC与PV的绑定是一对一的映射，使用ClaimRef是PersistentVolume和PersistentVolumeClaim之间的双向绑定。

如果不存在匹配的卷，则声明将无限期保持未绑定。随着匹配量的增加，声明将受到约束。例如，配备有许多50Gi PV的群集将与请求100Gi的PVC不匹配。将100Gi PV添加到群集时，可以绑定PVC。

### Using（使用）
pods使用声明作为volume。群集检查索赔以找到绑定的卷并将该卷装入Pod。对于支持多种访问模式的卷，用户可以在将其声明用作Pod中的卷时指定所需的模式。

一旦用户拥有声明并绑定了该声明，则绑定的PV属于该用户的时间长短，只要他们需要它即可。用户通过persistentVolumeClaim在Pod的volumes区块中包含一部分来安排Pod 并访问其声明的PV 。

### 使用中的存储对象保护
“使用中的存储对象保护”功能的目的是确保不会从系统中删除绑定到PVC的Pod和PersistentVolume（PV）主动使用的PersistentVolumeClaims（PVC），因为这可能会导致数据丢失。

> 注意：当存在使用PVC的Pod对象时，Pod会积极使用PVC。

如果用户删除了Pod正在使用的PVC，则不会立即删除该PVC。PVC的清除被推迟，直到任何Pod不再主动使用PVC。另外，如果管理员删除绑定到PVC的PV，则不会立即删除该PV。PV的去除被推迟，直到PV不再与PVC结合。

当PVC的状态为`Terminating`且`Finalizers`列表包括`kubernetes.io/pvc-protection：`时，您可以看到PVC受到保护。

```
kubectl describe pvc hostpath
Name:          hostpath
Namespace:     default
StorageClass:  example-hostpath
Status:        Terminating
Volume:
Labels:        <none>
Annotations:   volume.beta.kubernetes.io/storage-class=example-hostpath
               volume.beta.kubernetes.io/storage-provisioner=example.com/hostpath
Finalizers:    [kubernetes.io/pvc-protection]
...
```

您可以看到，当PV的状态为PV `Terminating`且该`Finalizers`列表也包括该PV时，该PV受到保护`kubernetes.io/pv-protection：`

```
kubectl describe pv task-pv-volume
Name:            task-pv-volume
Labels:          type=local
Annotations:     <none>
Finalizers:      [kubernetes.io/pv-protection]
StorageClass:    standard
Status:          Terminating
Claim:
Reclaim Policy:  Delete
Access Modes:    RWO
Capacity:        1Gi
Message:
Source:
    Type:          HostPath (bare host directory volume)
    Path:          /tmp/data
    HostPathType:
Events:            <none>
```

### Reclaiming (回收)
当用户完成其卷处理后，他们可以从允许回收资源的API中删除PVC对象。PersistentVolume的回收策略告诉集群在释放其声明后如何处理该卷。当前，可以保留，回收或删除卷。

#### Retain（保留）
该`Retain`回收政策允许资源的回收手册。删除PersistentVolumeClaim后，PersistentVolume仍然存在，并且该卷被视为“released(已释放)”。但是它尚不适用于其他索赔，因为前一个索赔人的数据保留在卷上。管理员可以按照以下步骤手动回收该卷。

1. 删除PersistentVolume。删除PV之后，外部基础架构中的关联存储资产（例如AWS EBS，GCE PD，Azure Disk或Cinder卷）仍然存在。
2. 相应地手动清理关联存储资产上的数据。
3. 手动删除关联的存储资产，或者如果要重复使用相同的存储资产，请使用存储资产定义创建一个新的PersistentVolume。

#### Delete（删除）

对于支持Delete回收策略的卷插件，删除操作会同时从Kubernetes中删除PersistentVolume对象以及外部基础架构中的关联存储资产，例如AWS EBS，GCE PD，Azure Disk或Cinder卷。动态设置的卷将继承其StorageClass的回收策略，默认为Delete。管理员应根据用户的期望配置StorageClass。否则，PV必须在创建后进行编辑或打补丁。请参阅更改持久卷的回收策略。

#### Recycle（回收）

> 警告：本Recycle回收政策已弃用。相反，推荐的方法是使用动态配置。 (文档来自于1.18版本)

如果基础卷插件支持，Recycle回收策略将rm -rf /thevolume/\*对该卷执行基本的scrub（）并使其可用于新的索赔。

但是，管理员可以使用Kubernetes控制器管理器命令行参数配置自定义回收站Pod模板，如此处所述。 定制回收站Pod模板必须包含卷规范，如以下示例所示：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pv-recycler
  namespace: default
spec:
  restartPolicy: Never
  volumes:
  - name: vol
    hostPath:
      path: /any/path/it/will/be/replaced
  containers:
  - name: pv-recycler
    image: "k8s.gcr.io/busybox"
    command: ["/bin/sh", "-c", "test -e /scrub && rm -rf /scrub/..?* /scrub/.[!.]* /scrub/*  && test -z \"$(ls -A /scrub)\" || exit 1"]
    volumeMounts:
    - name: vol
      mountPath: /scrub
```

然而，在卷部分的自定义回收器Pod模板中指定的特定路径被替换为正在回收的卷的特定路径。

### 扩展永久卷声明
功能状态： Kubernetes v1.11 beta版本

现在默认启用对扩展PersistentVolumeClaims（PVC）的支持。您可以扩展以下类型的卷：

- gcePersistentDisk
- awsElasticBlockStore
- Cinder
- glusterfs
- rbd
- Azure File
- Azure Disk
- Portworx
- FlexVolumes
- CSI

仅当PVC的存储类的allowVolumeExpansion字段设置为true时，才能展开PVC 。

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gluster-vol-default
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://192.168.10.100:8080"
  restuser: ""
  secretNamespace: ""
  secretName: ""
allowVolumeExpansion: true
```

要请求更大的PVC体积，请编辑PVC对象并指定更大的尺寸。这将触发支持基础PersistentVolume的卷的扩展。永远不会创建新的PersistentVolume来满足要求。相反，将调整现有卷的大小。

### CSI卷扩展
功能状态： Kubernetes v1.16 beta

默认情况下启用对扩展CSI卷的支持，但它也需要特定的CSI驱动程序来支持卷扩展。有关更多信息，请参阅特定CSI驱动程序的文档。

#### 调整包含文件系统的卷的大小
如果文件系统是XFS，Ext3或Ext4，则只能调整包含文件系统的卷的大小。

当卷包含文件系统时，仅当新Pod在ReadWrite模式下使用PersistentVolumeClaim时才调整文件系统的大小。当Pod启动时或Pod运行且基础文件系统支持联机扩展时，即完成文件系统扩展。

FlexVolumes允许调整大小，如果驱动程序设置与RequiresFSResize能力true。可以在Pod重新启动时调整FlexVolume的大小。

### 调整使用中的PersistentVolumeClaim的大小

功能状态： Kubernetes v1.15 beta

> 注意：自Kubernetes 1.15起，可扩展的使用中的PVC从beta版本开始提供，从1.11版本开始以alpha版本提供。ExpandInUsePersistentVolumes必须启用该功能，对于许多具有beta功能的群集，情况会自动如此。

在这种情况下，您无需删除并重新创建使用现有PVC的Pod或部署。文件系统扩展后，所有使用中的PVC都将自动供其Pod使用。此功能对Pod或部署中未使用的PVC无效。您必须创建一个使用PVC的Pod，然后才能完成扩展。

与其他卷类型类似-当由Pod使用时，FlexVolume卷也可以扩展。

> 注意：仅当基础驱动程序支持调整大小时，才可以调整FlexVolume的大小。

> 注意：扩展EBS量是一项耗时的操作。而且，每卷有每6小时修改一次的每卷配额。

## 持久卷的类型

PersistentVolume类型作为插件实现。Kubernetes当前支持以下插件：

- GCEPersistentDisk
- AWSElasticBlockStore
- AzureFile
- AzureDisk
- CSI
- FC (Fibre Channel)
- FlexVolume
- Flocker
- NFS
- iSCSI
- RBD (Ceph Block Device)
- CephFS
- Cinder (OpenStack block storage)
- Glusterfs
- VsphereVolume
- Quobyte Volumes
- HostPath (Single node testing only -- local storage is not supported in any way and WILL NOT WORK in a multi-node cluster)
- Portworx Volumes
- ScaleIO Volumes
- StorageOS

## 持久卷
每个PV包含规格和状态，即规格和状态。PersistentVolume对象的名称必须是有效的 DNS子域名。

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv0003
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: slow
  mountOptions:
    - hard
    - nfsvers=4.1
  nfs:
    path: /tmp
    server: 172.17.0.2
```

> 注意：群集中使用PersistentVolume可能需要与卷类型有关的帮助程序。在此示例中，PersistentVolume的类型为NFS，并且需要辅助程序/sbin/mount.nfs来支持NFS文件系统的安装。

### Capacity 容量
通常，PV将具有特定的存储容量。使用PV的capacity属性进行设置。请参阅Kubernetes [资源模型](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/scheduling/resources.md)以了解期望的单位capacity。

当前，存储大小是可以设置或请求的唯一资源。将来的属性可能包括IOPS，吞吐量等。

### Volume Mode 挂在卷模式

功能状态： Kubernetes v1.18 stable

Kubernetes支持两个volumeModesPersistentVolumes：Filesystem和Block。

volumeMode是可选的API参数。 Filesystem是volumeMode省略参数时使用的默认模式。

具有的卷volumeMode: Filesystem已安装到Pods的目录中。如果该卷由块设备支持并且该设备为空，则Kuberneretes会在首次安装该设备之前在该设备上创建一个文件系统。

您可以设置的值volumeMode以Block将卷用作原始块设备。这样的卷作为一个块设备呈现在Pod中，上面没有任何文件系统。此模式对于为Pod提供最快的访问卷的方式很有用，而Pod和卷之间没有任何文件系统层。另一方面，在Pod中运行的应用程序必须知道如何处理原始块设备 volumeMode: Block。

### Access Modes

PersistentVolume可以通过资源提供者支持的任何方式安装在主机上。如下表所示，提供商将具有不同的功能，并且每个PV的访问模式均设置为该特定卷支持的特定模式。例如，NFS可以支持多个读/写客户端，但是特定的NFS PV可能以只读方式在服务器上导出。每个PV都有自己的一组访问模式，用于描述该特定PV的功能。

访问方式为：

- ReadWriteOnce-可以通过单个节点以读写方式安装该卷
- ReadOnlyMany-该卷可以被许多节点只读挂载
- ReadWriteMany-该卷可以被许多节点读写安装

在CLI中，访问模式缩写为：

- RWO-ReadWriteOnce
- ROX-ReadOnlyMany
- RWX-ReadWriteMany

> 重要！即使一次卷支持多个卷，也只能一次使用一种访问模式挂载该卷。例如，GCEPersistentDisk可以由单个节点安装为ReadWriteOnce，也可以由多个节点安装为ReadOnlyMany，但不能同时安装。

|Volume Plugin|ReadWriteOnce|ReadOnlyMany|ReadWriteMany|
|---|---|---|---|
|AWSElasticBlockStore|✓|-|-|
|AzureFile|✓|✓|✓|
|AzureDisk|✓|-|-|
|CephFS|✓|✓|✓|
|Cinder|✓|-|-|
|CSI|depends on the driver|depends on the driver|depends on the driver|
|FC|✓|✓|-|
|FlexVolume|✓|✓|depends on the driver|
|Flocker|✓|-|-|
|GCEPersistentDisk|✓|✓|-|
|Glusterfs|✓|✓|✓|
|HostPath|✓|-|-|
|iSCSI|✓|✓|-|
|Quobyte|✓|✓|✓|
|NFS	|✓	|✓|	✓|
|RBD	|✓	|✓|	-|
|VsphereVolume	|✓	|-	|- (works when Pods are collocated)|
|PortworxVolume	|✓	|-	|✓|
|ScaleIO	|✓	|✓	|-|
|StorageOS	|✓	|-	|-|

### Calss

PV可以具有一个类，该类可以通过将storageClassName属性设置 为StorageClass的名称来指定 。特定类别的PV只能绑定到请求该类别的PVC。不storageClassName存在的PV 没有类别，只能绑定到不要求特定类别的PVC。

过去，使用annotation `volume.beta.kubernetes.io/storage-class`代替`storageClassName`属性。此注释仍然有效；但是，它将在以后的Kubernetes版本中完全弃用。

### Reclaim Policy (回收策略)
当前的回收政策是：

- Retain-手动填海
- Recycle-基本擦洗（rm -rf /thevolume/\*）
- Delete-删除了相关的存储资产，例如AWS EBS，GCE PD，Azure Disk或OpenStack Cinder卷

### 挂载选项
当在节点上安装持久卷时，Kubernetes管理员可以指定其他安装选项。

> 注意：并非所有的Persistent Volume类型都支持安装选项。

以下卷类型支持安装选项：

- AWSElasticBlockStore
- AzureDisk
- AzureFile
- CephFS
- Cinder (OpenStack block storage)
- GCEPersistentDisk
- Glusterfs
- NFS
- Quobyte Volumes
- RBD (Ceph Block Device)
- StorageOS
- VsphereVolume
- iSCSI

挂载选项未经验证，因此如果其中一个无效，挂载将仅失败。

过去，使用注释volume.beta.kubernetes.io/mount-options代替mountOptions属性。此注释仍然有效；但是，它将在以后的Kubernetes版本中完全弃用。

### 节点亲和力

写到此处 https://kubernetes.io/docs/concepts/storage/persistent-volumes/#node-affinity
