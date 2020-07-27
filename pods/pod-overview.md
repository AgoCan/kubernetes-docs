# pod 概览

## 理解pod

Pod 是 Kubernetes 应用程序的基本执行单元，即它是 Kubernetes 对象模型中创建或部署的最小和最简单的单元。Pod 表示在 集群 上运行的进程。

Pod 封装了应用程序容器（或者在某些情况下封装多个容器）、存储资源、唯一网络 IP 以及控制容器应该如何运行的选项。 Pod 表示部署单元：*Kubernetes 中应用程序的单个实例*，它可能由单个 容器 或少量紧密耦合并共享资源的容器组成。

Docker 是 Kubernetes Pod 中最常用的容器运行时，但 Pod 也能支持其他的容器运行时。

Kubernetes 集群中的 Pod 可被用于以下两个主要用途：

- **运行单个容器的 Pod。** ”每个 Pod 一个容器”模型是最常见的 Kubernetes 用例；在这种情况下，可以将 Pod 看作单个容器的包装器，并且 Kubernetes 直接管理 Pod，而不是容器。
- **运行多个协同工作的容器的 Pod。**  Pod 可能封装由多个紧密耦合且需要共享资源的共处容器组成的应用程序。 这些位于同一位置的容器可能形成单个内聚的服务单元 —— 一个容器将文件从共享卷提供给公众，而另一个单独的“挂斗”（sidecar）容器则刷新或更新这些文件。 Pod 将这些容器和存储资源打包为一个可管理的实体。

每个 Pod 表示运行给定应用程序的单个实例。如果希望横向扩展应用程序（例如，运行多个实例），则应该使用多个 Pod，每个应用实例使用一个 Pod 。在 Kubernetes 中，这通常被称为 _副本_。通常使用一个称为控制器的抽象来创建和管理一组副本 Pod。

### Pod 怎样管理多个容器

Pod 被设计成支持形成内聚服务单元的多个协作过程（作为容器）。 Pod 中的容器被自动的安排到集群中的同一物理或虚拟机上，并可以一起进行调度。 容器可以共享资源和依赖、彼此通信、协调何时以及何种方式终止它们。

注意，在单个 Pod 中将多个并置和共同管理的容器分组是一个相对高级的使用方式。 只在容器紧密耦合的特定实例中使用此模式。 例如，您可能有一个充当共享卷中文件的 Web 服务器的容器，以及一个单独的 sidecar 容器，该容器从远端更新这些文件，如下图所示：

![](/images/pod/pod.svg)

有些 Pod 具有 初始容器 和 应用容器。初始容器会在启动应用容器之前运行并完成。

Pod 为其组成容器提供了两种共享资源：网络 和 *存储*。


### 网络

每个 Pod 分配一个唯一的 IP 地址。 Pod 中的每个容器共享网络命名空间，包括 IP 地址和网络端口。 Pod 内的容器 可以使用 localhost 互相通信。 当 Pod 中的容器与 Pod 之外 的实体通信时，它们必须协调如何使用共享的网络资源（例如端口）。

### 存储
一个 Pod 可以指定一组共享存储卷。 Pod 中的所有容器都可以访问共享卷，允许这些容器共享数据。 卷还允许 Pod 中的持久数据保留下来，以防其中的容器需要重新启动。 有关 Kubernetes 如何在 Pod 中实现共享存储的更多信息，请参考[卷](/storage/README.md)。


## 使用 Pod

你很少在 Kubernetes 中直接创建单独的 Pod，甚至是单个存在的 Pod。 这是因为 Pod 被设计成了相对短暂的一次性的实体。 当 Pod 由您创建或者间接地由控制器创建时，它被调度在集群中的 节点 上运行。 Pod 会保持在该节点上运行，直到进程被终止、Pod 对象被删除、Pod 因资源不足而被 驱逐 或者节点失效为止。

- 注意： 重启 Pod 中的容器不应与重启 Pod 混淆。Pod 本身不运行，而是作为容器运行的环境，并且一直保持到被删除为止。

Pod 本身并不能自愈。 如果 Pod 被调度到失败的节点，或者如果调度操作本身失败，则删除该 Pod；同样，由于缺乏资源或进行节点维护，Pod 在被驱逐后将不再生存。 Kubernetes 使用了一个更高级的称为 控制器 的抽象，由它处理相对可丢弃的 Pod 实例的管理工作。 因此，虽然可以直接使用 Pod，但在 Kubernetes 中，更为常见的是使用控制器管理 Pod。 有关 Kubernetes 如何使用控制器实现 Pod 伸缩和愈合的更多信息，请参考 [Pod 和控制器](/controllers/README.md)。

### Pod 和控制器

控制器可以为您创建和管理多个 Pod，管理副本和上线，并在集群范围内提供自修复能力。 例如，如果一个节点失败，控制器可以在不同的节点上调度一样的替身来自动替换 Pod。

包含一个或多个 Pod 的控制器一些示例包括：

- [Deployment](/controllers/deployment.md)
- [StatefulSet](/controllers/statefulset.md)
- [DaemonSet](/controllers/daemonset.md)

控制器通常使用您提供的 Pod 模板来创建它所负责的 Pod。

## Pod 模板

Pod 模板是包含在其他对象中的 Pod 规范，例如 [Replication Controllers](/controllers/replicationcontroller.md)、 [Jobs](/controllers/jobs.md) 和 [DaemonSet](/controllers/daemonset.md)。 控制器使用 Pod 模板来制作实际使用的 Pod。 下面的示例是一个简单的 Pod 清单，它包含一个打印消息的容器。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  labels:
    app: myapp
spec:
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', 'echo Hello Kubernetes! && sleep 3600']
```

Pod 模板就像饼干切割器，而不是指定所有副本的当前期望状态。 一旦饼干被切掉，饼干就与切割器没有关系。 没有“量子纠缠”。 随后对模板的更改或甚至切换到新的模板对已经创建的 Pod 没有直接影响。 类似地，由副本控制器创建的 Pod 随后可以被直接更新。 这与 Pod 形成有意的对比，Pod 指定了属于 Pod 的所有容器的当前期望状态。 这种方法从根本上简化了系统语义，增加了原语的灵活性。


参考文档：

https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/  
https://kubernetes.io/docs/concepts/workloads/pods/pod/
