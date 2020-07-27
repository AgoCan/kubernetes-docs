# 亲和性和反亲和性

## 将Pod分配给节点
您可以约束Pod只能在特定节点上运行 ，或者更喜欢在特定节点上运行。有几种方法可以做到这一点，推荐的方法都使用 标签选择器进行选择。通常，此类约束是不必要的，因为调度程序会自动进行合理的放置（例如，将Pod分散到节点上，而不将Pod放置在可用资源不足的节点上，等等），但是在某些情况下，您可能需要更多控制Pod停靠的节点，例如，以确保Pod最终落在连接了SSD的机器上，或将来自大量通信量很大的两个不同服务的Pod放置在同一可用区中。  

### nodeSelector

`nodeSelector`是节点选择约束的最简单推荐形式。 `nodeSelector`是`PodSpec`的一个字段。它指定键值对的映射。为了使Pod可以在节点上运行，该节点必须具有每个指示的键值对作为标签（它也可以具有其他标签）。最常见的用法是一对键值对。

让我们来看一个使用方法的例子`nodeSelector`。


#### 先决条件

本示例假定您已基本了解Kubernetes pods 并且已建立Kubernetes集群。

#### 第一步：将标签粘贴到节点

运行`kubectl get nodes`以获取群集节点的名称。选择要向其添加标签的标签，然后运行`kubectl label nodes <node-name> <label-key>=<label-value>`以向您选择的节点添加标签。例如，如果我的节点名称是“ `kubernetes-foo-node-1.ca-robinson.internal`”，而我想要的标签是“ `disktype = ssd`”，那么我可以运行`kubectl label nodes kubernetes-foo-node-1.c.a-robinson.internal disktype=ssd`。

您可以通过重新运行`kubectl get nodes --show-labels`并检查节点现在是否具有标签来验证它是否有效。您还可以`kubectl describe node "nodename"`用来查看给定节点的标签的完整列表。

#### 第二步：将nodeSelector字段添加到您的Pod配置中

取出要运行的任何Pod配置文件，然后向其中添加一个`nodeSelector`部分。例如，如果这是我的pod配置：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    env: test
spec:
  containers:
  - name: nginx
    image: nginx
```

然后像这样添加一个nodeSelector：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    env: test
spec:
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
  nodeSelector:
    disktype: ssd
```

然后，运行时`kubectl apply -f pod-nginx.yaml`（[pod-nginx.yaml](https://kubernetes.hankbook.cn/manifests/example/pods/pod-nginx.yaml)），会将Pod安排在将标签附加到的节点上。您可以通过运行`kubectl get pods -o wide`并查看分配给Pod的“节点” 来验证其是否有效。

## 插曲：内置节点标签
除了您附加的标签外，节点还预填充了一组标准标签。这些标签是
[以下标签的网址总录](https://kubernetes.io/docs/reference/kubernetes-api/labels-annotations-taints/#kubernetes-io-hostname)    
- kubernetes.io/hostname
- failure-domain.beta.kubernetes.io/zone
- failure-domain.beta.kubernetes.io/region
- topology.kubernetes.io/zone
- topology.kubernetes.io/region
- beta.kubernetes.io/instance-type
- node.kubernetes.io/instance-type
- kubernetes.io/os
- kubernetes.io/arch

**注意**：这些标签的值是特定于云提供商的，因此不能保证可靠。例如，kubernetes.io/hostname在某些环境中，的值可能与节点名称相同，而在其他环境中，其值可能不同。


## 节点隔离/限制

向Node对象添加标签可以将吊舱定位到特定的节点或节点组。这可以用来确保特定的Pod仅在具有一定隔离性，安全性或监管属性的节点上运行。当为此目的使用标签时，强烈建议选择节点上的kubelet进程无法修改的标签键。这可以防止受感染的节点使用其kubelet凭据在自己的Node对象上设置这些标签，并影响调度程序将工作负载调度到受感染的节点。

在`NodeRestriction`从设置或具有修饰标签插件防止kubelets入场`node-restriction.kubernetes.io/`前缀。要使用该标签前缀进行节点隔离：

1. 确保您使用的节点授权，并已启用了`NodeRestriction`入场插件。
2. 将`node-restriction.kubernetes.io/`前缀下的标签添加到Node对象，然后在节点选择器中使用这些标签。例如，`example.com.node-restriction.kubernetes.io/fips=true`或`example.com.node-restriction.kubernetes.io/pci-dss=true`。

## 亲和力和反亲和力

`nodeSelector`提供了一种非常简单的方法来将pod约束到具有特定标签的节点。相似性/反相似性功能极大地扩展了您可以表达的约束类型。关键的增强是

1. 语言更具表现力（不仅仅是“完全匹配的AND”）
2. 您可以指出规则是“soft（软）”/“preference（偏好）”而不是hard（强制）要求，因此，如果调度程序无法满足该要求，则仍会调度该广告连播
3. 您可以限制节点（或其他拓扑域）上运行的其他Pod上的标签，而不是节点本身上的标签，这允许有关哪些Pod可以和不能共置的规则

亲和性特征包括两种类型的亲和性，即“node亲和性”和“inter-pod 亲和性/反亲和性”。节点亲和力就像现有的一样`nodeSelector`（但具有上面列出的前两个好处），而inter-pod亲和力/反亲和力则约束pod label 而不是node label，如上面列出的第三项中所述，除了具有第一和上面列出的第二个属性。

### 节点亲和力
节点相似性在概念上类似于`nodeSelector`–它使您可以根据节点上的标签来限制Pod可以安排在哪些节点上进行调度。

当前有两种类型的节点关联性，分别称为`requiredDuringSchedulingIgnoredDuringExecution`和 `preferredDuringSchedulingIgnoredDuringExecution`。您可以将它们分别视为“硬”和“软”，在某种意义上，前者指定了将Pod调度到节点上必须满足的规则（就像 `nodeSelector`但使用更具表现力的语法一样）指定调度程序将尝试强制执行但不能保证的首选项。名称的“ `IgnoredDuringExecution`”部分意味着，类似于`nodeSelector`工作原理，如果节点上的标签在运行时发生更改，从而不再满足Pod上的相似性规则，那么Pod仍将继续在该节点上运行。将来我们计划提供 `requiredDuringSchedulingRequiredDuringExecutio`n与`requiredDuringSchedulingIgnoredDuringExecution` 除了它将从不再满足Pod的节点亲和性要求的节点上逐出Pod之外。

因此，一个示例为`requiredDuringSchedulingIgnoredDuringExecution`“仅在具有Intel CPU的节点上运行Pod”，而一个示例`preferredDuringSchedulingIgnoredDuringExecution`为“尝试在故障区域XYZ中运行这组Pod，但如果不可能，则允许其中一些在其他位置运行”。

节点亲和力被指定为场`nodeAffinity`场affinity在`PodSpec`。

这是一个使用节点相似性的pod的示例：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-node-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/e2e-az-name
            operator: In
            values:
            - e2e-az1
            - e2e-az2
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: another-node-label-key
            operator: In
            values:
            - another-node-label-value
  containers:
  - name: with-node-affinity
    image: k8s.gcr.io/pause:2.0
```







参考文档：  
https://kubernetes.io/docs/concepts/configuration/assign-pod-node/
