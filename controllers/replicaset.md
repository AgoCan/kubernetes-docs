# ReplicaSet
ReplicaSet 是下一代的 Replication Controller。 ReplicaSet 和 Replication Controller 的唯一区别是选择器的支持。ReplicaSet 支持新的基于集合的选择器需求，这在标签用户指南中有描述。而 Replication Controller 仅支持基于相等选择器的需求。

## demo

## 怎样使用 ReplicaSet

大多数支持 Replication Controllers 的kubectl命令也支持 ReplicaSets。但rolling-update 命令是个例外。如果您想要滚动更新功能请考虑使用 Deployment。rolling-update 命令是必需的，而 Deployment 是声明性的，因此我们建议通过 rollout命令使用 Deployment。

虽然 ReplicaSets 可以独立使用，但今天它主要被Deployments 用作协调 Pod 创建、删除和更新的机制。 当您使用 Deployment 时，您不必担心还要管理它们创建的 ReplicaSet。Deployment 会拥有并管理它们的 ReplicaSet。

## 什么时候使用 ReplicaSet

ReplicaSet 确保任何时间都有指定数量的 Pod 副本在运行。 然而，Deployment 是一个更高级的概念，它管理 ReplicaSet，并向 Pod 提供声明式的更新以及许多其他有用的功能。 因此，我们建议使用 Deployment 而不是直接使用 ReplicaSet，除非您需要自定义更新业务流程或根本不需要更新。

这实际上意味着，您可能永远不需要操作 ReplicaSet 对象：而是使用 Deployment，并在 spec 部分定义您的应用。

## 示例

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: guestbook
    tier: frontend
spec:
  # modify replicas according to your case
  replicas: 3
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      containers:
      - name: php-redis
        image: gcr.io/google_samples/gb-frontend:v3
```

将此清单保存到 frontend.yaml 中，并将其提交到 Kubernetes 集群，应该就能创建 yaml 文件所定义的 ReplicaSet 及其管理的 Pod。

```
**[terminal]
$ kubectl create -f http://k8s.io/examples/controllers/frontend.yaml
replicaset.apps/frontend created
$ kubectl describe rs/frontend
Name:		frontend
Namespace:	default
Selector:	tier=frontend,tier in (frontend)
Labels:		app=guestbook
		tier=frontend
Annotations:	<none>
Replicas:	3 current / 3 desired
Pods Status:	3 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:       app=guestbook
                tier=frontend
  Containers:
   php-redis:
    Image:      gcr.io/google_samples/gb-frontend:v3
    Port:       80/TCP
    Requests:
      cpu:      100m
      memory:   100Mi
    Environment:
      GET_HOSTS_FROM:   dns
    Mounts:             <none>
  Volumes:              <none>
Events:
  FirstSeen    LastSeen    Count    From                SubobjectPath    Type        Reason            Message
  ---------    --------    -----    ----                -------------    --------    ------            -------
  1m           1m          1        {replicaset-controller }             Normal      SuccessfulCreate  Created pod: frontend-qhloh
  1m           1m          1        {replicaset-controller }             Normal      SuccessfulCreate  Created pod: frontend-dnjpy
  1m           1m          1        {replicaset-controller }             Normal      SuccessfulCreate  Created pod: frontend-9si5l
$ kubectl get pods
NAME             READY     STATUS    RESTARTS   AGE
frontend-9si5l   1/1       Running   0          1m
frontend-dnjpy   1/1       Running   0          1m
frontend-qhloh   1/1       Running   0          1m
```

## 编写 ReplicaSet Spec
与所有其他 Kubernetes API 对象一样，ReplicaSet 也需要 apiVersion、kind、和 metadata 字段。

ReplicaSet 也需要 .spec 部分。

### Pod 模版

.spec.template 是 .spec 唯一需要的字段。.spec.template 是 Pod 模版。它和 Pod 的语法几乎完全一样，除了它是嵌套的并没有 apiVersion 和 kind。

除了所需的 Pod 字段之外，ReplicaSet 中的 Pod 模板必须指定适当的标签和适当的重启策略。

对于标签，请确保不要与其他控制器重叠。更多信息请参考 Pod 选择器。

对于 重启策略，.spec.template.spec.restartPolicy 唯一允许的取值是 Always，这也是默认值.

对于本地容器重新启动，ReplicaSet 委托给了节点上的代理去执行，例如Kubelet 或 Docker 去执行。

### Pod 选择器
.spec.selector 字段是标签选择器。ReplicaSet 管理所有标签匹配与标签选择器的 Pod。它不区分自己创建或删除的 Pod 和其他人或进程创建或删除的pod。这允许在不影响运行中的 Pod 的情况下替换副本集。

.spec.template.metadata.labels 必须匹配 .spec.selector，否则它将被 API 拒绝。

Kubernetes 1.9 版本中，API 版本 apps/v1 中的 ReplicaSet 类型的版本是当前版本并默认开启。API 版本 apps/v1beta2 被弃用。

另外，通常您不应该创建标签与此选择器匹配的任何 Pod，或者直接与另一个 ReplicaSet 或另一个控制器（如 Deployment）标签匹配的任何 Pod。 如果你这样做，ReplicaSet 会认为它创造了其他 Pod。Kubernetes 并不会阻止您这样做。

如果您最终使用了多个具有重叠选择器的控制器，则必须自己负责删除。

### Replicas
通过设置 .spec.replicas 您可以指定要同时运行多少个 Pod。 在任何时间运行的 Pod 数量可能高于或低于 .spec.replicas 指定的数量，例如在副本刚刚被增加或减少后、或者 Pod 正在被优雅地关闭、以及替换提前开始。

如果您没有指定 .spec.replicas, 那么默认值为 1。

## 使用 ReplicaSets 的具体方法
### 删除 ReplicaSet 和它的 Pod
要删除 ReplicaSet 和它的所有 Pod，使用kubectl delete 命令。 默认情况下，垃圾收集器 自动删除所有依赖的 Pod。

当使用 REST API 或 client-go 库时，您必须在删除选项中将 propagationPolicy 设置为 Background 或 Foreground。例如：

```bash
kubectl proxy --port=8080
curl -X DELETE  'localhost:8080/apis/extensions/v1beta1/namespaces/default/replicasets/frontend' \
> -d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Foreground"}' \
> -H "Content-Type: application/json"
```

### 只删除 ReplicaSet
您可以只删除 ReplicaSet 而不影响它的 Pod，方法是使用kubectl delete 命令并设置 --cascade=false 选项。

当使用 REST API 或 client-go 库时，您必须将 propagationPolicy 设置为 Orphan。例如：

```bash
kubectl proxy --port=8080
curl -X DELETE  'localhost:8080/apis/extensions/v1beta1/namespaces/default/replicasets/frontend' \
> -d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Orphan"}' \
> -H "Content-Type: application/json"
```

一旦删除了原来的 ReplicaSet，就可以创建一个新的来替换它。 由于新旧 ReplicaSet 的 .spec.selector 是相同的，新的 ReplicaSet 将接管老的 Pod。 但是，它不会努力使现有的 Pod 与新的、不同的 Pod 模板匹配。 若想要以可控的方式将 Pod 更新到新的 spec，就要使用 滚动更新的方式。

### 将 Pod 从 ReplicaSet 中隔离
可以通过改变标签来从 ReplicaSet 的目标集中移除 Pod。这种技术可以用来从服务中去除 Pod，以便进行排错、数据恢复等。 以这种方式移除的 Pod 将被自动替换（假设副本的数量没有改变）。

### 缩放 RepliaSet
通过更新 .spec.replicas 字段，ReplicaSet 可以被轻松的进行缩放。ReplicaSet 控制器能确保匹配标签选择器的数量的 Pod 是可用的和可操作的。

### ReplicaSet 作为水平的 Pod 自动缩放器目标
ReplicaSet 也可以作为 水平的 Pod 缩放器 (HPA) 的目标。也就是说，ReplicaSet 可以被 HPA 自动缩放。 以下是 HPA 以我们在前一个示例中创建的副本集为目标的示例。

```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-scaler
spec:
  scaleTargetRef:
    kind: ReplicaSet
    name: frontend
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 50
```

将这个列表保存到 hpa-rs.yaml 并提交到 Kubernetes 集群，就能创建它所定义的 HPA，进而就能根据复制的 Pod 的 CPU 利用率对目标 ReplicaSet进行自动缩放。

```bash
kubectl create -f https://k8s.io/examples/controllers/hpa-rs.yaml
```
或者，可以使用 kubectl autoscale 命令完成相同的操作。 (而且它更简单！)

```bash
kubectl autoscale rs frontend
```

## ReplicaSet 的替代方案

### Deployment （推荐）
Deployment 是一个高级 API 对象，它以 kubectl rolling-update 的方式更新其底层副本集及其Pod。 如果您需要滚动更新功能，建议使用 Deployment，因为 Deployment 与 kubectl rolling-update 不同的是：它是声明式的、服务器端的、并且具有其他特性。 有关使用 Deployment 来运行无状态应用的更多信息，请参阅 使用 Deployment 运行无状态应用。

### 裸 Pod
与用户直接创建 Pod 的情况不同，ReplicaSet 会替换那些由于某些原因被删除或被终止的 Pod，例如在节点故障或破坏性的节点维护（如内核升级）的情况下。 因为这个好处，我们建议您使用 ReplicaSet，即使应用程序只需要一个 Pod。 想像一下，ReplicaSet 类似于进程监视器，只不过它在多个节点上监视多个 Pod，而不是在单个节点上监视单个进程。 ReplicaSet 将本地容器重启的任务委托给了节点上的某个代理（例如，Kubelet 或 Docker）去完成。

### Job
使用Job 代替ReplicaSet，可以用于那些期望自行终止的 Pod。

### DaemonSet
对于管理那些提供主机级别功能（如主机监控和主机日志）的容器，就要用DaemonSet 而不用 ReplicaSet。 这些 Pod 的寿命与主机寿命有关：这些 Pod 需要先于主机上的其他 Pod 运行，并且在机器准备重新启动/关闭时安全地终止。


参考文档： https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/
