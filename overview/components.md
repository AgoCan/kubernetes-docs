# Kubernetes 组件
本文档概述了交付正常运行的 Kubernetes 集群所需的各种二进制组件。

## Master 组件

Master 组件提供集群的控制平面。Master 组件对集群进行全局决策（例如，调度），并检测和响应集群事件（例如，当不满足部署的 replicas 字段时，启动新的 pod）。

Master 组件可以在集群中的任何节点上运行。然而，为了简单起见，安装脚本通常会启动同一个计算机上所有 Master 组件，并且不会在计算机上运行用户容器。请参阅构[建高可用性集群](https://kubernetes.hankbook.cn/practice/kubeadm-colony/high-availability.md)示例对于多主机 VM 的安装。

### kube-apiserver
主节点上负责提供 Kubernetes API 服务的组件；它是 Kubernetes 控制面的前端。

kube-apiserver 在设计上考虑了水平扩缩的需要。 换言之，通过部署多个实例可以实现扩缩。

### etcd
etcd 是兼具一致性和高可用性的键值数据库，可以作为保存 Kubernetes 所有集群数据的后台数据库。

您的 Kubernetes 集群的 etcd 数据库通常需要有个备份计划。 [etcd-github](https://github.com/etcd-io/etcd/blob/master/Documentation/docs.md)  

[etcd官方文档](https://etcd.io/docs/)

### kube-scheduler
主节点上的组件，该组件监视那些新创建的未指定运行节点的 Pod，并选择节点让 Pod 在上面运行。

调度决策考虑的因素包括单个 Pod 和 Pod 集合的资源需求、硬件/软件/策略约束、亲和性和反亲和性规范、数据位置、工作负载间的干扰和最后时限。


### kube-controller-manager

在主节点上运行控制器的组件。

*控制器：控制器通过apiserver监控集群的公共状态，并致力于将当前状态变为期望状态*

从逻辑上讲，每个控制器都是一个单独的进程，但是为了降低复杂性，它们都被编译到同一个可执行文件，并在一个进程中运行。

这些控制器包括:

- 节点控制器（Node Controller）: 负责在节点出现故障时进行通知和响应。
- 副本控制器（Replication Controller）: 负责为系统中的每个副本控制器对象维护正确数量的 Pod。
- 端点控制器（Endpoints Controller）: 填充端点(Endpoints)对象(即加入 Service 与 Pod)。
- 服务帐户和令牌控制器（Service Account & Token Controllers）: 为新的命名空间创建默认帐户和 API 访问令牌.


## Node 组件
节点组件在每个节点上运行，维护运行的 Pod 并提供 Kubernetes 运行环境。

### kubelet
一个在集群中每个节点上运行的代理。它保证容器都运行在 Pod 中。

kubelet 接收一组通过各类机制提供给它的 PodSpecs，确保这些 PodSpecs 中描述的容器处于运行状态且健康。kubelet 不会管理不是由 Kubernetes 创建的容器。

### kube-proxy
kube-proxy 是集群中每个节点上运行的网络代理,实现 Kubernetes Service 概念的一部分。

*service: 一种将运行在一组Pod上的应用程序公开为网络服务的方法*

kube-proxy 维护节点上的网络规则。这些网络规则允许从集群内部或外部的网络会话与 Pod 进行网络通信。


如果有 kube-proxy 可用，它将使用操作系统数据包过滤层。否则，kube-proxy 会转发流量本身。

### 容器运行环境(Container Runtime)
容器运行环境是负责运行容器的软件。

Kubernetes 支持多个容器运行环境: Docker、 containerd、cri-o、 rktlet 以及任何实现 Kubernetes CRI (容器运行环境接口)。

## 插件(Addons)

插件使用 Kubernetes 资源 (DaemonSet, Deployment等) 实现集群功能。因为这些提供集群级别的功能，所以插件的命名空间资源属于 kube-system 命名空间。

### dns
尽管并非严格要求其他附加组件，但所有示例都依赖集群 DNS，因此所有 Kubernetes 集群都应具有 DNS。

除了您环境中的其他 DNS 服务器之外，集群 DNS 还是一个 DNS 服务器，它为 Kubernetes 服务提供 DNS 记录。

Cluster DNS 是一个 DNS 服务器，和您部署环境中的其他 DNS 服务器一起工作，为 Kubernetes 服务提供DNS记录。

Kubernetes 启动的容器自动将 DNS 服务器包含在 DNS 搜索中。

### 用户界面(Dashboard)

Dashboard 是 Kubernetes 集群的通用基于 Web 的 UI。它使用户可以管理集群中运行的应用程序以及集群本身并进行故障排除。


### 容器资源监控
容器资源监控将关于容器的一些常见的时间序列度量值保存到一个集中的数据库中，并提供用于浏览这些数据的界面。

### 集群层面日志
集群层面日志 机制负责将容器的日志数据保存到一个集中的日志存储中，该存储能够提供搜索和浏览接口。
