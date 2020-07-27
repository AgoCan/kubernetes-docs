# Pod 拓扑扩展约束
1.16版本 alpha

可以使用_拓扑扩展约束_来控制 Pods 在集群内故障域（例如地区，区域，节点和其他用户自定义拓扑域）之间的分布。这可以帮助实现高可用以及提升资源利用率。

## 先决条件

### 启用功能

确保 EvenPodsSpread 功能已开启（在 1.16 版本中该功能默认关闭）。阅读[功能选项](https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/)了解如何开启该功能。EvenPodsSpread 必须在 API Server 和 scheduler 中都要开启。

### 节点标签

拓扑扩展约束依赖于节点标签来标识每个节点所在的拓扑域。例如，一个节点可能具有标签：`node=node1,zone=us-east-1a,region=us-east-1`

假设你拥有一个具有以下标签的 4 节点集群：

```
NAME    STATUS   ROLES    AGE     VERSION   LABELS
node1   Ready    <none>   4m26s   v1.16.0   node=node1,zone=zoneA
node2   Ready    <none>   3m58s   v1.16.0   node=node2,zone=zoneA
node3   Ready    <none>   3m17s   v1.16.0   node=node3,zone=zoneB
node4   Ready    <none>   2m43s   v1.16.0   node=node4,zone=zoneB
```

然后从逻辑上看集群如下：

```
+---------------+---------------+
|     zoneA     |     zoneB     |
+-------+-------+-------+-------+
| node1 | node2 | node3 | node4 |
+-------+-------+-------+-------+
```

可以复用在大多数集群上自动创建和填充的[知名标签](https://kubernetes.io/docs/reference/kubernetes-api/labels-annotations-taints/)，而不是手动添加标签。


## Pod 的拓扑约束

### API

`pod.spec.topologySpreadConstraints` 字段定义如下所示：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  topologySpreadConstraints:
  - maxSkew: <integer>
    topologyKey: <string>
    whenUnsatisfiable: <string>
    labelSelector: <object>
```

可以定义一个或多个 `topologySpreadConstraint` 来指示 `kube-scheduler` 如何将每个传入的 Pod 根据与现有的 Pod 的关联关系在集群中部署。字段包括：

- maxSkew 描述 pod 分布不均的程度。这是给定拓扑类型中任意两个拓扑域中匹配的 pod 之间的最大允许差值。它必须大于零。
- topologyKey 是节点标签的键。如果两个节点使用此键标记并且具有相同的标签值，则调度器会将这两个节点视为处于同一拓扑中。调度器试图在每个拓扑域中放置数量均衡的 pod。
- whenUnsatisfiable 指示如果 pod 不满足扩展约束时如何处理：
  - DoNotSchedule（默认）告诉调度器不用进行调度。
  - ScheduleAnyway 告诉调度器在对最小化倾斜的节点进行优先级排序时仍对其进行调度。
- labelSelector 用于查找匹配的 pod。匹配此标签的 pod 将被统计，以确定相应拓扑域中 pod 的数量。有关详细信息，请参考标签选择器。

执行 `kubectl explain Pod.spec.topologySpreadConstraints` 命令了解更多关于 topologySpreadConstraints 的信息。

### 例子：单个拓扑扩展约束

假设你拥有一个 4 节点集群，其中标记为 foo:bar 的 3 个 pod 分别位于 node1，node2 和 node3 中（P 表示 pod）：

```
+---------------+---------------+
|     zoneA     |     zoneB     |
+-------+-------+-------+-------+
| node1 | node2 | node3 | node4 |
+-------+-------+-------+-------+
|   P   |   P   |   P   |       |
+-------+-------+-------+-------+
```

如果希望传入的 pod 均匀散布在现有的 pod 区域，则可以指定字段如下：

- pods/topology-spread-constraints/one-constraint.yaml

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: mypod
  labels:
    foo: bar
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        foo: bar
  containers:
  - name: pause
    image: k8s.gcr.io/pause:3.1
```

`topologyKey: zone` 意味着均匀分布将只应用于存在标签对为 “zone:” 的节点上。`whenUnsatisfiable: DoNotSchedule` 告诉调度器，如果传入的 pod 不满足约束，则让它保持挂起状态。

如果调度器将传入的 pod 放入 “zoneA”，pod 分布将变为 [3, 1]，因此实际的倾斜为 2（3 - 1）。这违反了 `maxSkew: 1`。此示例中，传入的 pod 只能放置在 “zoneB” 上：

```
+---------------+---------------+      +---------------+---------------+
|     zoneA     |     zoneB     |      |     zoneA     |     zoneB     |
+-------+-------+-------+-------+      +-------+-------+-------+-------+
| node1 | node2 | node3 | node4 |  OR  | node1 | node2 | node3 | node4 |
+-------+-------+-------+-------+      +-------+-------+-------+-------+
|   P   |   P   |   P   |   P   |      |   P   |   P   |  P P  |       |
+-------+-------+-------+-------+      +-------+-------+-------+-------+
```

可以调整 pod 规格以满足各种要求：

- 将 maxSkew 更改为更大的值，比如 “2”，这样传入的 pod 也可以放在 “zoneA” 上。
- 将 topologyKey 更改为 “node”，以便将 pod 均匀分布在节点上而不是区域中。在上面的例子中，如果 maxSkew 保持为 “1”，那么传入的 pod 只能放在 “node4” 上。
- 将 whenUnsatisfiable: DoNotSchedule 更改为 whenUnsatisfiable: ScheduleAnyway，以确保传入的 pod 始终可以调度（假设满足其他的调度 API）。但是，最好将其放置在具有较少匹配 pod 的拓扑域中。（请注意，此优先性与其他内部调度优先级（如资源使用率等）一起进行标准化。）

### 例子：多个拓扑扩展约束
下面的例子建立在前面例子的基础上。假设你拥有一个 4 节点集群，其中 3 个标记为 foo:bar 的 pod 分别位于 node1，node2 和 node3 上（P 表示 pod）：

```
+---------------+---------------+
|     zoneA     |     zoneB     |
+-------+-------+-------+-------+
| node1 | node2 | node3 | node4 |
+-------+-------+-------+-------+
|   P   |   P   |   P   |       |
+-------+-------+-------+-------+
```
可以使用 2 个拓扑扩展约束来控制 pod 在 区域和节点两个维度上进行分布：

- pods/topology-spread-constraints/two-constraints.yaml

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: mypod
  labels:
    foo: bar
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        foo: bar
  - maxSkew: 1
    topologyKey: node
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        foo: bar
  containers:
  - name: pause
    image: k8s.gcr.io/pause:3.1
```
在这种情况下，为了匹配第一个约束，传入的 pod 只能放置在 “zoneB” 中；而在第二个约束中，传入的 pod 只能放置在 “node4” 上。然后两个约束的结果加在一起，因此唯一可行的选择是放置在 “node4” 上。

多个约束可能导致冲突。假设有一个跨越 2 个区域的 3 节点集群：

```
+---------------+-------+
|     zoneA     | zoneB |
+-------+-------+-------+
| node1 | node2 |  nod3 |
+-------+-------+-------+
|  P P  |   P   |  P P  |
+-------+-------+-------+
```
如果对集群应用 “two-constraints.yaml”，会发现 “mypod” 处于 Pending 状态。这是因为：为了满足第一个约束，”mypod” 只能放在 “zoneB” 中，而第二个约束要求 “mypod” 只能放在 “node2” 上。pod 调度无法满足两种约束。

为了克服这种情况，可以增加 maxSkew 或修改其中一个约束，让其使用 whenUnsatisfiable: ScheduleAnyway。

### 约定

这里有一些值得注意的隐式约定：

- 只有与传入 pod 具有相同命名空间的 pod 才能作为匹配候选者。
- 没有 `topologySpreadConstraints[*].topologyKey` 的节点将被忽略。这意味着：

  1. 于这些节点上的 pod 不影响 maxSkew 的计算。在上面的例子中，假设 “node1” 没有标签 “zone”，那么 2 个 pod 将被忽略，因此传入的 pod 将被调度到 “zoneA” 中。
  2. 传入的 pod 没有机会被调度到这类节点上。在上面的例子中，假设一个带有标签 {zone-typo: zoneC} 的 “node5” 加入到集群，它将由于没有标签键 “zone” 而被忽略。

注意，如果传入 pod 的 `topologySpreadConstraints[*].labelSelector` 与自身的标签不匹配，将会发生什么。在上面的例子中，如果移除传入 pod 的标签，pod 仍然可以调度到 “zoneB”，因为约束仍然满足。然而，在调度之后，集群的不平衡程度保持不变。zoneA 仍然有 2 个带有 {foo:bar} 标签的 pod，zoneB 有 1 个带有 {foo:bar} 标签的 pod。因此，如果这不是你所期望的，建议工作负载的 `topologySpreadConstraints[*].labelSelector` 与其自身的标签匹配。

- 如果传入的 pod 定义了 spec.nodeSelector 或 spec.affinity.nodeAffinity，则将忽略不匹配的节点。

假设有一个从 zonea 到 zonec 的 5 节点集群：

```
+---------------+---------------+-------+
|     zoneA     |     zoneB     | zoneC |
+-------+-------+-------+-------+-------+
| node1 | node2 | node3 | node4 | node5 |
+-------+-------+-------+-------+-------+
|   P   |   P   |   P   |       |       |
+-------+-------+-------+-------+-------+
```

你知道 “zoneC” 必须被排除在外。在这种情况下，可以按如下方式编写 yaml，以便将 “mypod” 放置在 “zoneB” 上，而不是 “zoneC” 上。同样，spec.nodeSelector 也要一样处理。

- pods/topology-spread-constraints/one-constraint-with-nodeaffinity.yaml

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: mypod
  labels:
    foo: bar
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        foo: bar
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: zone
            operator: NotIn
            values:
            - zoneC
  containers:
  - name: pause
    image: k8s.gcr.io/pause:3.1
```

## 与 PodAffinity/PodAntiAffinity 相比较

在 Kubernetes 中，与 “Affinity” 相关的指令控制 pod 的调度方式（更密集或更分散）。

- 对于 PodAffinity，可以尝试将任意数量的 pod 打包到符合条件的拓扑域中。
- 对于 PodAntiAffinity，只能将一个 pod 调度到单个拓扑域中。
“EvenPodsSpread” 功能提供灵活的选项来将 pod 均匀分布到不同的拓扑域中，以实现高可用性或节省成本。这也有助于滚动更新工作负载和平滑扩展副本。

## 已知局限性
1.16 版本（此功能为 alpha）存在下面的一些限制：

- Deployment 的缩容可能导致 pod 分布不平衡。
- pod 匹配到污点节点是允许的。参考 [Issue 80921](https://github.com/kubernetes/kubernetes/issues/80921)。


参考文档：

https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/
