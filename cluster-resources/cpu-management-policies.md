# 控制节点上的CPU管理策略（控制容器是否独占cpu资源）
FEATURE STATE: Kubernetes v1.12 beta


Kubernetes保留了Pod如何在从用户抽象的节点上执行的许多方面。这是设计使然。但是，某些工作负载需要在时延和/或性能方面得到更强有力的保证，以使操作可接受。kubelet提供了一些方法来启用更复杂的工作负载放置策略，同时使抽象不受显式放置指令的影响。

## 此话题是本人测试结果

首先，需要在节点上的`kubelet`设置 `--cpu-manager-policy`，按照二进制部署方式，就是 `/usr/lib/systemd/system/kubelet.service`

然后需要加上参数给k8s自己使用cpu和内存的使用量 `–kube-reserved` 该参数的方式是 golang下的map格式，也就是

```bash
# 设置为static模式
--cpu-manager-policy=static     
# 设置kubernetes的使用预留
--kube-reserved=cpu=200m,memory=1G
```

最后一个部署，因为之前启动过kubelet，需要去掉旧的cpu策略信息

```bash
rm -rf /var/lib/kubelet/cpu_manager_state
```

测试的pod创建,按照二进制的部署方式，节点名称就是对应的IP地址，so，请选择自己的ip地址

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: test-cpu-polycy
spec:
  containers:
  - name: test-cpu-polycy
    image: nginx
    resources:
      limits:
        memory: "200Mi"
        cpu: "2"
      requests:
        memory: "200Mi"
        cpu: "2"
  nodeName: 10.10.10.7
```

## 在你开始之前
您需要拥有一个Kubernetes集群，并且必须将kubectl命令行工具配置为与您的集群通信。如果您还没有集群，则可以使用Minikube创建集群，也 可以使用以下Kubernetes游乐场之一：

要检查版本，请输入`kubectl version`。

## CPU管理政策
默认情况下，kubelet使用[CFS](https://en.wikipedia.org/wiki/Completely_Fair_Scheduler)配额 来实施Pod CPU限制。当节点运行许多受CPU限制的Pod时，工作负载可以转移到不同的CPU内核，具体取决于Pod是否受限制以及在计划时可用的CPU内核。许多工作负载对此迁移不敏感，因此无需任何干预即可正常工作。

但是，在CPU缓存亲和力和调度延迟显着影响工作负载性能的工作负载中，kubelet允许备用CPU管理策略确定节点上的某些放置首选项。

### 组态

通过kubelet `--cpu-manager-policy`选项设置CPU管理器策略。有两种受支持的策略：

- none：默认策略。
- static：允许为具有某些资源特征的Pod授予节点上更高的CPU亲和力和排他性。

CPU管理器会定期通过CRI编写资源更新，以使内存CPU分配与cgroupfs保持一致。通过新的Kubelet配置值设置协调频率 `--cpu-manager-reconcile-period`。如果未指定，则默认为与相同的持续时间`--node-status-update-frequency`。

### None 策略

none 策略显式地启用现有的默认 CPU 亲和方案，不提供操作系统调度器默认行为之外的亲和性策略。 通过 CFS 配额来实现 Guaranteed pods 的 CPU 使用限制。

### Static 策略
static 策略针对具有整数型 CPU requests 的 Guaranteed pod ，它允许该类 pod 中的容器访问节点上的独占 CPU 资源。这种独占性是使用 [cpuset cgroup 控制器](https://www.kernel.org/doc/Documentation/cgroup-v1/cpusets.txt) 来实现的。

> 注意： 诸如容器运行时和 kubelet 本身的系统服务可以继续在这些独占 CPU 上运行。独占性仅针对其他 pod。
> 注意： 该策略的 alpha 版本不保证 Kubelet 重启前后的静态独占性分配。
> 注意： CPU 管理器不支持运行时下线和上线 CPUs。此外，如果节点上的在线 CPUs 集合发生变化，则必须驱逐节点上的 pods，并通过删除 kubelet 根目录中的状态文件 cpu_manager_state 来手动重置 CPU 管理器。

该策略管理一个共享 CPU 资源池，最初，该资源池包含节点上所有的 CPU 资源。可用 的独占性 CPU 资源数量等于节点的 CPU 总量减去通过 `--kube-reserved` 或 `--system-reserved` 参数保留的 CPU 。从1.17版本开始，CPU保留列表可以通过 kublet 的 ‘–reserved-cpus’ 参数显式地设置。 通过 ‘–reserved-cpus’ 指定的显式CPU列表优先于使用 ‘`–kube-reserved`’ 和 ‘`–system-reserved`’ 参数指定的保留CPU。 通过这些参数预留的 CPU 是以整数方式，按物理内 核 ID 升序从初始共享池获取的。 共享池是 `BestEffort` 和 `Burstable` pod 运行 的 CPU 集合。Guaranteed pod 中的容器，如果声明了非整数值的 `CPU requests` ，也将运行在共享池的 CPU 上。只有 `Guaranteed` pod 中，指定了整数型 `CPU requests` 的容器，才会被分配独占 CPU 资源。

> 注意： 当启用 static 策略时，要求使用 --kube-reserved 和/或 --system-reserved 或 --reserved-cpus 来保证预留的 CPU 值大于零。 这是因为零预留 CPU 值可能使得共享池变空。

当 Guaranteed pod 调度到节点上时，如果其容器符合静态分配要求，相应的 CPU 会被从共享池中移除，并放置到容器的 cpuset 中。因为这些容器所使用的 CPU 受到调度域本身的限制，所以不需要使用 CFS 配额来进行 CPU 的绑定。换言之，容器 cpuset 中的 CPU 数量与 pod 规格中指定的整数型 CPU limit 相等。这种静态分配增强了 CPU 亲和性，减少了 CPU 密集的工作负载在节流时引起的上下文切换。

考虑以下 Pod 规格的容器：

```yaml
spec:
  containers:
  - name: nginx
    image: nginx
```

该 pod 属于 BestEffort QoS 类型，因为其未指定 requests 或 limits 值。 所以该容器运行在共享 CPU 池中。

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
该 pod 属于 Burstable QoS 类型，因为其资源 requests 不等于 limits， 且未指定 cpu 数量。所以该容器运行在共享 CPU 池中。

```yaml
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      limits:
        memory: "200Mi"
        cpu: "2"
      requests:
        memory: "100Mi"
        cpu: "1"
```

该 pod 属于 Burstable QoS 类型，因为其资源 requests 不等于 limits。所以该容器运行在共享 CPU 池中。

```yaml
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      limits:
        memory: "200Mi"
        cpu: "2"
      requests:
        memory: "200Mi"
        cpu: "2"
```

该 pod 属于 Guaranteed QoS 类型，因为其 requests 值与 limits相等。同时，容器对 CPU 资源的限制值是一个大于或等于 1 的整数值。所以，该 nginx 容器被赋予 2 个独占 CPU。

```yaml
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      limits:
        memory: "200Mi"
        cpu: "1.5"
      requests:
        memory: "200Mi"
        cpu: "1.5"
```

该 pod 属于 Guaranteed QoS 类型，因为其 requests 值与 limits相等。但是容器对 CPU 资源的限制值是一个小数。所以该容器运行在共享 CPU 池中。

```yaml
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      limits:
        memory: "200Mi"
        cpu: "2"
```

该 pod 属于 Guaranteed QoS 类型，因其指定了 limits 值，同时当未显式指定时，requests 值被设置为与 limits 值相等。同时，容器对 CPU 资源的限制值是一个大于或等于 1 的整数值。所以，该 nginx 容器被赋予 2 个独占 CPU。


参考文档：

https://hex108.gitbook.io/kubernetes-notes/zi-yuan-ge-li-yu-xian-zhi/cpu

https://kubernetes.io/docs/tasks/administer-cluster/cpu-management-policies/

https://www.kernel.org/doc/Documentation/cgroup-v1/cpusets.txt
