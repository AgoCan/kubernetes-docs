# 控制节点上的拓扑管理策略
FEATURE STATE: Kubernetes v1.17 alpha

越来越多的系统利用 CPU 和硬件加速器的组合来支持对延迟要求较高的任务和高吞吐量的并行计算。 这类负载包括电信、科学计算、机器学习、金融服务和数据分析等。 此类混合系统即用于构造这些高性能环境。

为了获得最佳性能，需要进行与 CPU 隔离、内存和设备局部性有关的优化。 但是，在 Kubernetes 中，这些优化由各自独立的组件集合来处理。

拓扑管理器（Topology Manager） 是一个 Kubelet 的一部分，旨在协调负责这些优化的一组组件。

## 准备开始
你必须拥有一个 Kubernetes 的集群，同时你的 Kubernetes 集群必须带有 kubectl 命令行工具。 如果你还没有集群，你可以通过 Minikube 构建一 个你自己的集群，或者你可以使用下面任意一个 Kubernetes 工具构建：

要获知版本信息，请输入 `kubectl version`.

## 拓扑管理器如何工作
在引入拓扑管理器之前， Kubernetes 中的 CPU 和设备管理器相互独立地做出资源分配决策。 这可能会导致在多处理系统上出现并非期望的资源分配；由于这些与期望相左的分配，对性能或延迟敏感的应用将受到影响。 这里的不符合期望意指，例如， CPU 和设备是从不同的 NUMA 节点分配的，因此会导致额外的延迟。

拓扑管理器是一个 Kubelet 组件，扮演信息源的角色，以便其他 Kubelet 组件可以做出与拓扑结构相对应的资源分配决定。

拓扑管理器为组件提供了一个称为 建议供应者（Hint Providers） 的接口，以发送和接收拓扑信息。 拓扑管理器具有一组节点级策略，具体说明如下。

拓扑管理器从 建议提供者 接收拓扑信息，作为表示可用的 NUMA 节点和首选分配指示的位掩码。 拓扑管理器策略对所提供的建议执行一组操作，并根据策略对提示进行约减以得到最优解；如果存储了与预期不符的建议，则该建议的优选字段将被设置为 false。 在当前策略中，首选的是最窄的优选掩码。 所选建议将被存储为拓扑管理器的一部分。 取决于所配置的策略，所选建议可用来决定节点接受或拒绝 Pod 。 之后，建议会被存储在拓扑管理器中，供 建议提供者 进行资源分配决策时使用。

## 拓扑管理器策略
当前拓扑管理器：

- 在启用了 static CPU 管理器策略的节点上起作用。 请参阅控制 CPU 管理策略
- 适用于通过扩展资源发出 CPU 请求或设备请求的 Pod

如果满足这些条件，则拓扑管理器将调整请求的资源。

拓扑管理器支持四种分配策略。 您可以通过 Kubelet 标志 `--topology-manager-policy` 设置策略。 所支持的策略有四种：

- none (默认)
- best-effort
- restricted
- single-numa-node

### none 策略
这是默认策略，不执行任何拓扑对齐。

### best-effort 策略
对于 Guaranteed 类的 Pod 中的每个容器，具有 `best-effort` 拓扑管理策略的 kubelet 将调用每个建议提供者以确定资源可用性。 使用此信息，拓扑管理器存储该容器的首选 NUMA 节点亲和性。 如果亲和性不是首选，则拓扑管理器将存储该亲和性，并且无论如何都将 pod 接纳到该节点。

之后 建议提供者 可以在进行资源分配决策时使用这个信息。

### restricted 策略
对于 Guaranteed 类 Pod 中的每个容器， 配置了 `restricted` 拓扑管理策略的 kubelet 调用每个建议提供者以确定其资源可用性。。 使用此信息，拓扑管理器存储该容器的首选 NUMA 节点亲和性。 如果亲和性不是首选，则拓扑管理器将从节点中拒绝此 Pod 。 这将导致 Pod 处于 `Terminated` 状态，且 Pod 无法被节点接纳。

一旦 Pod 处于 `Terminated` 状态，Kubernetes 调度器将不会尝试重新调度该 Pod。建议使用 ReplicaSet 或者 Deployment 来重新部署 Pod。 还可以通过实现外部控制环，以启动对具有 Topology Affinity 错误的 Pod 的重新部署。

如果 Pod 被允许运行在该节点，则 建议提供者 可以在做出资源分配决定时使用此信息。

### single-numa-node 策略
对于 Guaranteed 类 Pod 中的每个容器， 配置了 `single-numa-nodde` 拓扑管理策略的 kubelet 调用每个建议提供者以确定其资源可用性。 使用此信息，拓扑管理器确定单 NUMA 节点亲和性是否可能。 如果是这样，则拓扑管理器将存储此信息，然后 建议提供者 可以在做出资源分配决定时使用此信息。 如果不可能，则拓扑管理器将拒绝 Pod 运行于该节点。 这将导致 Pod 处于 Terminated 状态，且 Pod 无法被节点接受。

一旦 Pod 处于 Terminated 状态，Kubernetes 调度器将不会尝试重新调度该 Pod。建议使用 ReplicaSet 或者 Deployment 来重新部署 Pod。 还可以通过实现外部控制环，以触发具有 Topology Affinity 错误的 Pod 的重新部署。

### Pod 与拓扑管理器策略的交互

考虑以下 pod 规范中的容器：

```yaml
spec:
  containers:
  - name: nginx
    image: nginx

```

该 Pod 在 BestEffort QoS 类中运行，因为没有指定资源 requests 或 limits 。

```yaml
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      limits:
        memory: "200Mi"
      requests:
        memory: "100Mi"
```

由于 requests 数少于 limits，因此该 Pod 以 Burstable QoS 类运行。

如果选择的策略是 none 以外的任何其他策略，拓扑管理器不会考虑这些 Pod 中的任何一个规范。

```yaml
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      limits:
        memory: "200Mi"
        cpu: "2"
        example.com/device: "1"
      requests:
        memory: "200Mi"
        cpu: "2"
        example.com/device: "1"
```

此 Pod 在 Guaranteed QoS 类中运行，因为其 requests 值等于 limits 值。

```yaml
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      limits:
        example.com/deviceA: "1"
        example.com/deviceB: "1"
      requests:
        example.com/deviceA: "1"
        example.com/deviceB: "1"
```

由于没有 CPU 和内存请求，因此该 Pod 在 BestEffort QoS 类中运行。

拓扑管理器将考虑以上两个 Pod。拓扑管理器将咨询 CPU 和设备管理器，以获取 Pod 的拓扑提示。 对于 Guaranteed Pod，static CPU 管理器策略将返回与 CPU 请求有关的提示，而设备管理器将返回有关所请求设备的提示。

对于 BestEffort Pod，由于没有 CPU 请求，CPU 管理器将发送默认提示，而设备管理器将为每个请求的设备发送提示。

使用此信息，拓扑管理器将为 Pod 计算最佳提示并存储该信息，并且供提示提供程序在进行资源分配时使用。


### 已知的局限性

1. 从 K8s 1.16 开始，当前只能在保证 Pod 规范中的 单个 容器需要相匹配的资源时，拓扑管理器才能正常工作。这是由于生成的提示信息是基于当前资源分配的，并且 pod 中的所有容器都会在进行任何资源分配之前生成提示信息。这样会导致除 Pod 中的第一个容器以外的所有容器生成不可靠的提示信息。
2. 由于此限制，如果 kubelet 快速连续考虑多个 Pod/容器，它们可能不遵守拓扑管理器策略。
3. 拓扑管理器允许的最大 NUMA 节点数为 8，并且在尝试枚举可能的 NUMA 关联并生成其提示信息时，将出现状态问题。
4. 调度器不支持拓扑功能，因此可能会由于拓扑管理器的原因而在节点上进行调度，然后在该节点上调度失败。



参考文档：

https://kubernetes.io/docs/tasks/administer-cluster/topology-manager/
