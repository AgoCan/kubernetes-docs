# nodes
[参考文档](https://kubernetes.io/docs/concepts/architecture/nodes/)
节点是`Kubernetes`中的工作机，以前称为`minion`。`node`可以是`VM`或物理机，具体取决于群集。每个`node`都包含运行Pods所需的服务，并由`master`管理。节点上的服务包括`container runtime`，`kubelet`和`kube-proxy`。

## Node Status
节点的状态包含以下信息：

- Addresses（地址）
- Conditions（条件）
- Capacity and Allocatable（容量和可分配）
- Info（信息）

可以使用以下命令显示节点状态和有关节点的其他详细信息：

```bash
kubectl describe node <insert-node-name-here>
```

每个部分将在下面详细描述。

### Addresses

这些字段的用法因您的云提供商或裸机配置而异。

- HostName（主机名）：节点内核报告的主机名。可以通过kubelet --hostname-override参数覆盖。  
- ExternalIP（外部IP）：通常是可外部路由的节点的IP地址（可从群集外部获得）。  
- InternalIP（内部IP）：通常仅在群集内可路由的节点的IP地址。

### Conditions

该`conditions`字段描述所有`Running`节点的状态。条件的示例包括：

|Node Condition|Description|
|--|--|
|Ready|`True`如果节点运行状况良好并准备好接受`Pod`，`False`如果节点运行状况不佳并且不接受`Pod`，并且`Unknown`节点控制器最近一次未从节点收到消息`node-monitor-grace-period`（默认值为40秒）|
|MemoryPressure|`True`如果节点内存上存在压力，即节点内存不足；除此以外`False`|
|PIDPressure|`True`进程是否存在压力-即节点上的进程是否过多；除此以外`False`|
|DiskPressure|`True`磁盘大小是否受到压力-即磁盘容量是否不足；除此以外`False`|
|NetworkUnavailable|`True` 如果节点的网络配置不正确，否则 `False`|

节点条件表示为JSON对象。例如，以下响应描述了一个健康的节点。

```json
"conditions": [
  {
    "type": "Ready",
    "status": "True",
    "reason": "KubeletReady",
    "message": "kubelet is posting ready status",
    "lastHeartbeatTime": "2019-06-05T18:38:35Z",
    "lastTransitionTime": "2019-06-05T11:41:27Z"
  }
]
```

如果“就绪状态”条件保持不变`Unknown`或`False`比更长，则将`pod-eviction-timeout`参数传递给`kube-controller-manager`，并计划由节点控制器删除节点上的所有`Pod`。默认驱逐超时持续时间为五分钟。在某些情况下，当节点不可访问时，`apiserver`无法与节点上的`kubelet`通信。在重新建立与`apiserver`的通信之前，无法将删除`pod`的决定传达给`kubelet`。同时，计划删除的`Pod`可能会继续在分区节点上运行。

在`1.5`之前的`Kubernetes`版本中，节点控制器将强制 从`apiserver`中删除这些无法访问的`Pod`。但是，在`1.5`及更高版本中，节点控制器在确认已停止在集群中运行之前不会强制删除它们。您可以将处于可能无法访问的节点上运行的`Pod`处于`Terminating`或`Unknown`状态。如果`Kubernetes`无法从基础架构推断出某个节点永久离开集群的情况，则集群管理员可能需要手动删除该节点对象。从`Kubernetes`中删除节点对象会导致节点上运行的所有`Pod`对象从`apiserver`中删除，并释放它们的名称。

节点生命周期控制器会自动创建 代表条件的污点。当调度程序将`Pod`分配给节点时，调度程序会考虑节点的污点，但`Pod`可以容忍的污点除外。

### Capacity and Allocatable

描述节点上可用的资源：`CPU`，内存和可调度到节点上的`Pod`的最大数量。

容量块中的字段指示节点拥有的资源总量。可分配块指示节点上可供普通Pod消耗的资源量。

### Info

描述有关节点的常规信息，例如内核版本，`Kubernetes`版本（`kubelet`和`kube-proxy`版本），`Docker`版本（如果使用）和操作系统名称。该信息由Kubelet从节点收集。


## Management

与`Pod`和`service`不同，节点不是`Kubernetes`固有创建的：它是由`Google Compute Engine`等云提供商在外部创建的，或者存在于您的物理机或虚拟机池中。因此，当`Kubernetes`创建一个节点时，它将创建一个代表该节点的对象。创建后，`Kubernetes`会检查该节点是否有效。例如，如果尝试从以下内容创建节点：

```json
{
  "kind": "Node",
  "apiVersion": "v1",
  "metadata": {
    "name": "10.240.79.157",
    "labels": {
      "name": "my-first-k8s-node"
    }
  }
}
```

`Kubernetes`在内部创建一个节点对象（表示形式），并通过基于`metadata.name`字段的运行状况检查来验证该节点。如果节点有效（即，所有必需的服务都在运行），则可以运行`pod`。否则，任何集群活动都将忽略它，直到它变为有效。

```
注意： Kubernetes为无效节点保留该对象，并继续检查其是否有效。您必须明确删除Node对象才能停止此过程。
```
当前，有三个与Kubernetes节点接口交互的组件：节点控制器，`kubelet`和`kubectl`。


### Node Controller （节点控制器）

节点控制器是`Kubernetes`主组件，它管理节点的各个方面。

节点控制器在节点的生命中扮演多个角色。第一个是在注册节点时将`CIDR`块分配给该节点（如果已打开`CIDR`分配）。
第二个是使节点控制器的内部节点列表与云提供商的可用计算机列表保持最新。在云环境中运行时，只要节点运行不正常，节点控制器就会询问云提供商，该节点的`VM`是否仍然可用。如果不是，则节点控制器从其节点列表中删除该节点。

第三是监视节点的健康状况。节点控制器负责在节点变得不可访问时将`NodeStatus`的`NodeReady`条件更新为`ConditionUnknown`（即，由于某些原因（例如由于节点关闭），节点控制器停止接收心跳信号），然后从节点中逐出所有`Pod` （使用正常终止）（如果使用该终止，则该节点继续无法访问）。（默认超时为40 `--node-monitor-period`秒，开始报告`ConditionUnknown`，之后为`5m`，开始逐出`pod`。）节点控制器每秒钟检查一次每个节点的状态。

### Heartbeats （心跳）

`Kubernetes`节点发送的心跳有助于确定节点的可用性。心跳有两种形式：更新`NodeStatus`和 租赁对象。每个节点在`kube-node-lease` 名称空间的名称空间中都有一个关联的`Lease`对象。租用是一种轻量级的资源，可在群集扩展时提高节点心跳的性能。

`kubelet`负责创建和更新`NodeStatus`和租赁对象。

### Reliability （可靠性）

在`Kubernetes 1.4`中，我们更新了节点控制器的逻辑，以更好地处理当大量节点无法到达主节点时（例如，由于主节点存在网络问题）的情况。从`1.4`开始，节点控制器在做出关于`Pod`逐出的决定时会查看集群中所有节点的状态。

在大多数情况下，节点控制器将逐出速率限制为每秒`--node-eviction-rate`（默认值为 `0.1`），这意味着每`10`秒不会从超过`1`个节点中逐出容器。

当给定可用性区域中的节点不正常时，节点驱逐行为会更改。节点控制器同时检查区域中有多少百分比的节点不正常（`NodeReady`条件为`ConditionUnknown`或`ConditionFalse`）。如果不健康节点的比例至少为`--unhealthy-zone-threshold`（默认值为 `0.55`），则驱逐速度会降低：如果群集较小（即`--large-cluster-size-threshold`节点少于或等于节点，默认值为 `50`），则驱逐将停止，否则驱逐速度将降低为 `--secondary-node-eviction-rate`（默认值为`0.01`）/秒。每个可用区都实施这些策略的原因是，一个可用区可能会与主分区分开，而其他可用区仍保持连接。如果您的集群没有跨越多个云提供商可用性区域，则只有一个可用性区域（整个集群）。

将节点分布在各个可用区域上的一个关键原因是，当一个整个区域出现故障时，可以将工作负载转移到正常区域。因此，如果区域中的所有节点都不健康，则节点控制器将以正常速率逐出`--node-eviction-rate`。当所有区域都完全不健康时（即群集中没有健康的节点），便是最极端的情况。在这种情况下，节点控制器会假定主连接存在问题，并停止所有逐出直到恢复某些连接。

从`Kubernetes 1.6`开始，`Node Pod`不能容忍污点时，它还负责驱逐在带有NoExecute污点的节点上运行的Pod。此外，作为默认情况下禁用的Alpha功能，`NodeController`负责添加与节点问题（例如，节点不可达或未就绪）相对应的污点。

从版本`1.8`开始，可以使节点控制器负责创建代表节点条件的污点。这是`1.8`版的`Alpha`功能。

### Self-Registration of Nodes （节点自动注册）

当kubelet标志`--register-node`为`true`（默认设置）时，`kubelet`将尝试向`API`服务器注册自身。这是大多数发行版使用的首选模式。

对于自我注册，kubelet使用以下选项启动：

- `--kubeconfig` -用于向apiserver进行身份验证的凭据的路径。
- `--cloud-provider` -如何与云提供商交谈以读取有关其自身的元数据。
- `--register-node` -自动向API服务器注册。
- `--register-with-taints`-使用给定的污点列表（用逗号分隔`<key>=<value>:<effect>`）注册该节点。不操作是否`register-node`为假。
- `--node-ip` -节点的IP地址。
- `--node-labels`-在集群中注册节点时要添加的标签（请参阅`1.13+`中由`NodeRestriction`允许插件实施的标签限制）。
- `--node-status-update-frequency` -指定`kubelet`多久将一次节点状态发布到主节点。

当节点授权模式和 `NodeRestriction`录取插件的启用，`kubelets`仅被授权创建/修改自己的节点资源。

### Manual Node Administration （节点手动管理）

集群管理员可以创建和修改节点对象。

如果管理员希望手动创建节点对象，请设置`kubelet`标志 `--register-node=false`。

管理员可以修改节点资源（与的设置无关`--register-node`）。修改包括在节点上设置标签并将其标记为不可计划。

节点上的标签可以与`Pod`上的节点选择器结合使用，以控制调度，例如，将`Pod`约束为仅适合在节点的子集上运行。

将节点标记为不可调度可防止将新Pod调度到该节点，但不会影响该节点上的任何现有`Pod`。这对于节点重新启动等之前的准备步骤很有用。例如，要将节点标记为不可调度，请运行以下命令：

```
kubectl cordon $NODENAME
```

```
注意：由DaemonSet控制器创建的Pod会绕过Kubernetes调度程序，并且不遵守节点上的unschedulable属性。这假定即使在准备重新引导时耗尽了应用程序，守护程序也属于该计算机。
```

### Node capacity （节点容量）

节点的容量（`CPU`数量和内存量）是节点对象的一部分。通常，节点在创建节点对象时会注册自己并报告其容量。如果您正在执行手动节点管理，则在添加节点时需要设置节点容量。

`Kubernetes`调度程序可确保为节点上的所有`Pod`提供足够的资源。它检查节点上容器请求的总和不大于节点容量。它包括由`kubelet`启动的所有容器，但不包括由容器运行时直接启动的容器，也不包括在容器外部运行的任何进程。

如果要为非`Pod`进程显式保留资源，请按照本教程 为系统守护程序保留资源。

### Node topology (节点拓扑)

功能状态： `Kubernetes v1.17` `α`
如果启用了`TopologyManager` 功能闸，则`kubelet`可以在做出资源分配决策时使用拓扑提示。

### API Object (API对象)
[参考文档](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.17/#node-v1-core)


# Master-Node Communication （master节点通信）

本文档对主服务器（实际上是`apiserver`）与`Kubernetes`集群之间的通信路径进行了分类。目的是允许用户自定义其安装以加强网络配置，以便可以在不受信任的网络（或云提供商的完全公共IP）上运行群集。

## Cluster to Master (集群到主节点)
从群集到主机的所有通信路径都在`apiserver`处终止（其他主机组件均未设计为公开远程服务）。在典型部署中，将`apiserver`配置为侦听启用了一种或多种形式的客户端身份验证的安全`HTTPS`端口（`443`）上的远程连接。 应该启用一种或多种形式的授权，尤其是 在允许匿名请求 或服务帐户令牌的情况下。

应该为节点配置群集的公共根证书，以便它们可以与有效的客户端凭据一起安全地连接到`apiserver`。例如，在默认的`GKE`部署中，提供给`kubelet`的客户端凭据采用客户端证书的形式。

希望连接到`apiserver`的`Pod`可以通过利用服务帐户来安全地这样做，以便`Kubernetes`在实例化`Pod`时会自动将公共根证书和有效的承载令牌注入`Pod`。该`kubernetes`服务（在所有名称空间中）都配置有虚拟IP地址，该地址被重定向（通过`kube-proxy`）到`apiserver`上的`HTTPS`端点。

主组件还通过安全端口与群集`apiserver`通信。

因此，默认情况下，从群集（节点和节点上运行的`Pod`）到主机的连接的默认操作模式是受保护的，并且可以在不受信任和/或公共网络上运行。

## Master to Cluster （主节点到集群）

从主服务器（`apiserver`）到群集有两条主要通信路径。第一个是从`apiserver`到在集群中每个节点上运行的kubelet进程。第二个是通过`apiserver`的代理功能从`apiserver`到任何节点，`pod`或服务。

`apiserver`到`kubelet`

从`apiserver`到`kubelet`的连接用于：

- 获取`pods`的日志
- (通过kubelet)附加到运行`pods`
- 提供`kubelet`的端口转发功能。

这些连接在`kubelet`的`HTTPS`端点处终止。默认情况下，`API`服务器不验证`kubelet`的服务证书，这使得连接受到人在这方面的中间人攻击， 不安全的跑过来不可信和/或公共网络。

要验证此连接，请使用该`--kubelet-certificate-authority`标志为`apiserver`提供根证书捆绑包，以用于验证`kubelet`的服务证书。

如果无法做到 这一点，请根据需要在`apiserver`和`kubelet`之间使用`SSH`隧道，以避免通过不可信或公共网络进行连接。

最后， 应该启用`Kubelet`身份验证和/或授权以保护`kubelet API`。

## apiserver to nodes, pods, and services (apiserver到节点，pod和服务)
从`apiserver`到节点，`pod`或服务的连接默认为纯`HTTP`连接，因此未经身份验证或加密。可以通过`https:`在`API URL`中添加节点，`pod`或服务名称的前缀来在安全的`HTTPS`连接上运行它们，但是它们将不会验证`HTTPS`端点提供的证书，也不会提供客户端凭据，因此在对连接进行加密的同时，不会提供任何完整性保证。这些连接当前在通过不可信和/或公共网络运行时并不安全。

## SSH Tunnels (SSH隧道)
`Kubernetes`支持SSH隧道来保护`Master-> Cluster`通信路径。在此配置中，`apiserver`启动到群集中每个节点的`SSH`隧道（连接到侦听端口`22`的`ssh`服务器），并通过隧道传递发往`kubelet`，`node`，`pod`或`service`的所有流量。该隧道确保流量不会暴露在运行节点的网络外部。

`SSH`隧道目前已被弃用，因此除非您知道自己在做什么，否则不应该选择使用它们。正在设计此通信通道的替代产品。
