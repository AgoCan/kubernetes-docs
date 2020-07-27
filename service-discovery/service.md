# service

将运行在一组 Pods 上的应用程序公开为网络服务的抽象方法。

使用Kubernetes，您无需修改应用程序即可使用不熟悉的服务发现机制。 Kubernetes为Pods提供自己的IP地址和一组Pod的单个DNS名称，并且可以在它们之间进行负载平衡。

```
# demo
nginx-service.default.svc.cluster.local
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo
  labels:
    name: demo
spec:
  type: NodePort
  ports:
    - port: 80
      protocol: TCP
      targetPort: 80
      name: http
      nodePort: 30080
  selector:
    app: demo
```

## 动机

Kubernetes Pods 是有生命周期的。他们可以被创建，而且销毁不会再启动。 如果您使用 Deployment 来运行您的应用程序，则它可以动态创建和销毁 Pod。

每个 Pod 都有自己的 IP 地址，但是在 Deployment 中，在同一时刻运行的 Pod 集合可能与稍后运行该应用程序的 Pod 集合不同。

这导致了一个问题： 如果一组 Pod（称为“后端”）为群集内的其他 Pod（称为“前端”）提供功能，那么前端如何找出并跟踪要连接的 IP 地址，以便前端可以使用工作量的后端部分？

进入 \_Services\_。

## Service 资源

Kubernetes Service 定义了这样一种抽象：逻辑上的一组 Pod，一种可以访问它们的策略 —— 通常称为微服务。 这一组 Pod 能够被 Service 访问到，通常是通过 selector （查看下面了解，为什么你可能需要没有 selector 的 Service）实现的。

举个例子，考虑一个图片处理 backend，它运行了3个副本。这些副本是可互换的 —— frontend 不需要关心它们调用了哪个 backend 副本。 然而组成这一组 backend 程序的 Pod 实际上可能会发生变化，frontend 客户端不应该也没必要知道，而且也不需要跟踪这一组 backend 的状态。 Service 定义的抽象能够解耦这种关联。

### 云原生服务发现

如果您想要在应用程序中使用 Kubernetes 接口进行服务发现，则可以查询 API server 的 endpoint 资源，只要服务中的Pod集合发生更改，端点就会更新。

对于非本机应用程序，Kubernetes提供了在应用程序和后端Pod之间放置网络端口或负载均衡器的方法。

## 定义 Service
一个 `Service` 在 Kubernetes 中是一个 REST 对象，和 Pod 类似。 像所有的 `REST` 对象一样， `Service` 定义可以基于 POST 方式，请求 API server 创建新的实例。

例如，假定有一组 Pod，它们对外暴露了 9376 端口，同时还被打上 app=MyApp 标签。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```

上述配置创建一个名称为 “my-service” 的 Service 对象，它会将请求代理到使用 TCP 端口 9376，并且具有标签 "app=MyApp" 的 Pod 上。 Kubernetes 为该服务分配一个 IP 地址（有时称为 “集群IP” ），该 IP 地址由服务代理使用。 (请参见下面的 虚拟 IP 和服务代理). 服务选择器的控制器不断扫描与其选择器匹配的 Pod，然后将所有更新发布到也称为 “my-service” 的Endpoint对象。


- 注意：需要注意的是， Service 能够将一个接收 port 映射到任意的 targetPort。 默认情况下，targetPort 将被设置为与 port 字段相同的值。

Pod中的端口定义具有名称字段，您可以在服务的 targetTarget 属性中引用这些名称。 即使服务中使用单个配置的名称混合使用 Pod，并且通过不同的端口号提供相同的网络协议，此功能也可以使用。 这为部署和发展服务提供了很大的灵活性。 例如，您可以更改Pods在新版本的后端软件中公开的端口号，而不会破坏客户端。

服务的默认协议是TCP。 您还可以使用任何其他 受支持的协议。

由于许多服务需要公开多个端口，因此 Kubernetes 在服务对象上支持多个端口定义。 每个端口定义可以具有相同的 protocol，也可以具有不同的协议。

### 没有 selector 的 Service

服务最常见的是抽象化对 Kubernetes Pod 的访问，但是它们也可以抽象化其他种类的后端。 实例:

- 希望在生产环境中使用外部的数据库集群，但测试环境使用自己的数据库。
- 希望服务指向另一个 命名空间 中或其它集群中的服务。
- 您正在将工作负载迁移到 Kubernetes。 在评估该方法时，您仅在 Kubernetes 中运行一部分后端。

在任何这些场景中，都能够定义没有 selector 的 Service。 实例:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```

由于此服务没有选择器，因此 不会 自动创建相应的 Endpoint 对象。 您可以通过手动添加 Endpoint 对象，将服务手动映射到运行该服务的网络地址和端口：

```yaml
apiVersion: v1
kind: Endpoints
metadata:
  name: my-service
subsets:
  - addresses:
      - ip: 192.0.2.42
    ports:
      - port: 9376
```

- 注意：端点 IPs 必须不可以 : 环回( IPv4 的 127.0.0.0/8 , IPv6 的 ::1/128 ）或本地链接（IPv4 的 169.254.0.0/16 和 224.0.0.0/24，IPv6 的 fe80::/64)。 端点 IP 地址不能是其他 Kubernetes Services 的群集 IP，因为 kube-proxy 不支持将虚拟 IP 作为目标。

访问没有 selector 的 Service，与有 selector 的 Service 的原理相同。 请求将被路由到用户定义的 Endpoint， YAML中为: 192.0.2.42:9376 (TCP)。

ExternalName Service 是 Service 的特例，它没有 selector，也没有使用 DNS 名称代替。 有关更多信息，请参阅本文档后面的ExternalName。

### Endpoint 切片
***FEATURE STATE: Kubernetes v1.16 alpha***

Endpoint 切片是一种 API 资源，可以为 Endpoint 提供更可扩展的替代方案。 尽管从概念上讲与 Endpoint 非常相似，但 Endpoint 切片允许跨多个资源分布网络端点。 默认情况下，一旦到达100个 Endpoint，该 Endpoint 切片将被视为“已满”，届时将创建其他 Endpoint 切片来存储任何其他 Endpoint。

Endpoint 切片提供了附加的属性和功能，这些属性和功能在 Endpoint 切片中进行了详细描述。

## VIP 和 Service 代理

在 Kubernetes 集群中，每个 Node 运行一个 kube-proxy 进程。kube-proxy 负责为 Service 实现了一种 VIP（虚拟 IP）的形式，而不是 ExternalName 的形式。

### 为什么不使用 DNS 轮询？

时不时会有人问道，就是为什么 Kubernetes 依赖代理将入站流量转发到后端。 那其他方法呢？ 例如，是否可以配置具有多个A值（或IPv6为AAAA）的DNS记录，并依靠轮询名称解析？

使用服务代理有以下几个原因：

- DNS 实现的历史由来已久，它不遵守记录 TTL，并且在名称查找结果到期后对其进行缓存。
- 有些应用程序仅执行一次 DNS 查找，并无限期地缓存结果。
- 即使应用和库进行了适当的重新解析，DNS 记录上的 TTL 值低或为零也可能会给 DNS 带来高负载，从而使管理变得困难。

### 版本兼容性

从Kubernetes v1.0开始，您已经可以使用 用户空间代理模式。 Kubernetes v1.1添加了 iptables 模式代理，在 Kubernetes v1.2 中，kube-proxy 的 iptables 模式成为默认设置。 Kubernetes v1.8添加了 ipvs 代理模式。

### userspace 代理模式

这种模式，kube-proxy 会监视 Kubernetes master 对 Service 对象和 Endpoints 对象的添加和移除。 对每个 Service，它会在本地 Node 上打开一个端口（随机选择）。 任何连接到“代理端口”的请求，都会被代理到 Service 的backend Pods 中的某个上面（如 Endpoints 所报告的一样）。 使用哪个 backend Pod，是 kube-proxy 基于 SessionAffinity 来确定的。

最后，它安装 iptables 规则，捕获到达该 Service 的 clusterIP（是虚拟 IP）和 Port 的请求，并重定向到代理端口，代理端口再代理请求到 backend Pod。

默认情况下，用户空间模式下的kube-proxy通过循环算法选择后端。

默认的策略是，通过 round-robin 算法来选择 backend Pod。

![](/images/service/services-userspace-overview.svg)

### iptables 代理模式

这种模式，kube-proxy 会监视 Kubernetes 控制节点对 Service 对象和 Endpoints 对象的添加和移除。 对每个 Service，它会安装 iptables 规则，从而捕获到达该 Service 的 clusterIP 和端口的请求，进而将请求重定向到 Service 的一组 backend 中的某个上面。 对于每个 Endpoints 对象，它也会安装 iptables 规则，这个规则会选择一个 backend 组合。

默认的策略是，kube-proxy 在 iptables 模式下随机选择一个 backend。

使用 iptables 处理流量具有较低的系统开销，因为流量由 Linux netfilter 处理，而无需在用户空间和内核空间之间切换。 这种方法也可能更可靠。

如果 kube-proxy 在 iptable s模式下运行，并且所选的第一个 Pod 没有响应，则连接失败。 这与用户空间模式不同：在这种情况下，kube-proxy 将检测到与第一个 Pod 的连接已失败，并会自动使用其他后端 Pod 重试。

您可以使用 Pod readiness 探测器 验证后端 Pod 可以正常工作，以便 iptables 模式下的 kube-proxy 仅看到测试正常的后端。 这样做意味着您避免将流量通过 kube-proxy 发送到已知已失败的Pod。

![](/images/service/services-iptables-overview.svg)

### IPVS 代理模式

在 ipvs 模式下，kube-proxy监视Kubernetes服务和端点，调用 netlink 接口相应地创建 IPVS 规则， 并定期将 IPVS 规则与 Kubernetes 服务和端点同步。 该控制循环可确保　IPVS　状态与所需状态匹配。 访问服务时，IPVS　将流量定向到后端Pod之一。

IPVS代理模式基于类似于 iptables 模式的 netfilter 挂钩函数，但是使用哈希表作为基础数据结构，并且在内核空间中工作。 这意味着，与 iptables 模式下的 kube-proxy 相比，IPVS 模式下的 kube-proxy 重定向通信的延迟要短，并且在同步代理规则时具有更好的性能。与其他代理模式相比，IPVS 模式还支持更高的网络流量吞吐量。

IPVS提供了更多选项来平衡后端Pod的流量。 这些是：

- rr: round-robin
- lc: least connection (smallest number of open connections)
- dh: destination hashing
- sh: source hashing
- sed: shortest expected delay
- nq: never queue

- 注意： 要在 IPVS 模式下运行 kube-proxy，必须在启动 kube-proxy 之前使 IPVS Linux 在节点上可用。当 kube-proxy 以 IPVS 代理模式启动时，它将验证 IPVS 内核模块是否可用。 如果未检测到 IPVS 内核模块，则 kube-proxy 将退回到以 iptables 代理模式运行。

![](/images/service/services-ipvs-overview.svg)

在这些代理模型中，绑定到服务IP的流量：在客户端不了解Kubernetes或服务或Pod的任何信息的情况下，将Port代理到适当的后端。 如果要确保每次都将来自特定客户端的连接传递到同一Pod，则可以通过将 service.spec.sessionAffinity 设置为 “ClientIP” (默认值是 “None”)，来基于客户端的IP地址选择会话关联。

您还可以通过适当设置 service.spec.sessionAffinityConfig.clientIP.timeoutSeconds 来设置最大会话停留时间。 （默认值为 10800 秒，即 3 小时）。

## 多端口 Service
对于某些服务，您需要公开多个端口。 Kubernetes允许您在Service对象上配置多个端口定义。 为服务使用多个端口时，必须提供所有端口名称，以使它们无歧义。 例如：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 9376
    - name: https
      protocol: TCP
      port: 443
      targetPort: 9377
```

- 注意：与一般的Kubernetes名称一样，端口名称只能包含 小写字母数字字符 和 -。 端口名称还必须以字母数字字符开头和结尾。例如，名称 123-abc 和 web 有效，但是 123_abc 和 -web 无效。

## 选择自己的 IP 地址
在 Service 创建的请求中，可以通过设置 `spec.clusterIP` 字段来指定自己的集群 IP 地址。 比如，希望替换一个已经已存在的 DNS 条目，或者遗留系统已经配置了一个固定的 IP 且很难重新配置。

用户选择的 IP 地址必须合法，并且这个 IP 地址在 `service-cluster-ip-range` CIDR 范围内，这对 API Server 来说是通过一个标识来指定的。 如果 IP 地址不合法，API Server 会返回 HTTP 状态码 422，表示值不合法。

## 服务发现
Kubernetes 支持2种基本的服务发现模式 —— 环境变量和 DNS。

### 环境变量
当 Pod 运行在 Node 上，kubelet 会为每个活跃的 Service 添加一组环境变量。 它同时支持 Docker links兼容 变量（查看 makeLinkVariables）、简单的 {SVCNAME}_SERVICE_HOST 和 {SVCNAME}_SERVICE_PORT 变量，这里 Service 的名称需大写，横线被转换成下划线。

举个例子，一个名称为 "redis-master" 的 Service 暴露了 TCP 端口 6379，同时给它分配了 Cluster IP 地址 10.0.0.11，这个 Service 生成了如下环境变量：

```
REDIS_MASTER_SERVICE_HOST=10.0.0.11
REDIS_MASTER_SERVICE_PORT=6379
REDIS_MASTER_PORT=tcp://10.0.0.11:6379
REDIS_MASTER_PORT_6379_TCP=tcp://10.0.0.11:6379
REDIS_MASTER_PORT_6379_TCP_PROTO=tcp
REDIS_MASTER_PORT_6379_TCP_PORT=6379
REDIS_MASTER_PORT_6379_TCP_ADDR=10.0.0.11
```

- 注意：当您具有需要访问服务的Pod时，并且您正在使用环境变量方法将端口和群集IP发布到客户端Pod时，必须在客户端Pod出现 之前 创建服务。 否则，这些客户端Pod将不会设定其环境变量。如果仅使用DNS查找服务的群集IP，则无需担心此设定问题。

### DNS

您可以（几乎总是应该）使用附加组件为Kubernetes集群设置DNS服务。

支持群集的DNS服务器（例如CoreDNS）监视 Kubernetes API 中的新服务，并为每个服务创建一组 DNS 记录。 如果在整个群集中都启用了 DNS，则所有 Pod 都应该能够通过其 DNS 名称自动解析服务。

例如，如果您在 Kubernetes 命名空间 "my-ns" 中有一个名为 "my-service" 的服务， 则控制平面和DNS服务共同为 "my-service.my-ns" 创建 DNS 记录。 "my-ns" 命名空间中的Pod应该能够通过简单地对 my-service 进行名称查找来找到它（ "my-service.my-ns" 也可以工作）。

其他命名空间中的Pod必须将名称限定为 my-service.my-ns 。 这些名称将解析为为服务分配的群集IP。

Kubernetes 还支持命名端口的 DNS SRV（服务）记录。 如果 "my-service.my-ns" 服务具有名为 "http"　的端口，且协议设置为TCP， 则可以对 \_http.\_tcp.my-service.my-ns 执行DNS SRV查询查询以发现该端口号, "http"以及IP地址。

Kubernetes DNS 服务器是唯一的一种能够访问 ExternalName 类型的 Service 的方式。 更多关于 ExternalName 信息可以查看DNS Pod 和 Service。

## Headless Services

有时不需要或不想要负载均衡，以及单独的 Service IP。 遇到这种情况，可以通过指定 Cluster IP（spec.clusterIP）的值为 "None" 来创建 Headless Service。

您可以使用 headless Service 与其他服务发现机制进行接口，而不必与 Kubernetes 的实现捆绑在一起。

对这 headless Service 并不会分配 Cluster IP，kube-proxy 不会处理它们，而且平台也不会为它们进行负载均衡和路由。 DNS 如何实现自动配置，依赖于 Service 是否定义了 selector。

### 配置 Selector
对定义了 selector 的 Headless Service，Endpoint 控制器在 API 中创建了 Endpoints 记录，并且修改 DNS 配置返回 A 记录（地址），通过这个地址直接到达 Service 的后端 Pod 上。

### 不配置 Selector
对没有定义 selector 的 Headless Service，Endpoint 控制器不会创建 Endpoints 记录。 然而 DNS 系统会查找和配置，无论是：

- ExternalName 类型 Service 的 CNAME 记录
- 记录：与 Service 共享一个名称的任何 Endpoints，以及所有其它类型

## 发布服务 —— 服务类型

对一些应用（如 Frontend）的某些部分，可能希望通过外部Kubernetes 集群外部IP 地址暴露 Service。

Kubernetes ServiceTypes 允许指定一个需要的类型的 Service，默认是 ClusterIP 类型。

Type 的取值以及行为如下： * ClusterIP：通过集群的内部 IP 暴露服务，选择该值，服务只能够在集群内部可以访问，这也是默认的 ServiceType。 * NodePort：通过每个 Node 上的 IP 和静态端口（NodePort）暴露服务。NodePort 服务会路由到 ClusterIP 服务，这个 ClusterIP 服务会自动创建。通过请求 <NodeIP>:<NodePort>，可以从集群的外部访问一个 NodePort 服务。 * LoadBalancer：使用云提供商的负载局衡器，可以向外部暴露服务。外部的负载均衡器可以路由到 NodePort 服务和 ClusterIP 服务。 * ExternalName：通过返回 CNAME 和它的值，可以将服务映射到 externalName 字段的内容（例如， foo.bar.example.com）。 没有任何类型代理被创建。

- 注意： 您需要 CoreDNS 1.7 或更高版本才能使用 ExternalName 类型。

您也可以使用 Ingress 来暴露自己的服务。 Ingress 不是服务类型，但它充当集群的入口点。 它可以将路由规则整合到一个资源中，因为它可以在同一IP地址下公开多个服务。

### NodePort 类型

如果将 type 字段设置为 NodePort，则 Kubernetes 控制平面将在 --service-node-port-range 标志指定的范围内分配端口（默认值：30000-32767）。 每个节点将那个端口（每个节点上的相同端口号）代理到您的服务中。 您的服务在其 .spec.ports[\*].nodePort 字段中要求分配的端口。

如果您想指定特定的IP代理端口，则可以将 kube-proxy 中的 --nodeport-addresses 标志设置为特定的IP块。从Kubernetes v1.10开始支持此功能。

该标志采用逗号分隔的IP块列表（例如10.0.0.0/8、192.0.2.0/25）来指定 kube-proxy 应该认为是此节点本地的IP地址范围。

例如，如果您使用 --nodeport-addresses=127.0.0.0/8 标志启动 kube-proxy，则 kube-proxy 仅选择 NodePort Services 的环回接口。 --nodeport-addresses 的默认值是一个空列表。 这意味着 kube-proxy 应该考虑 NodePort 的所有可用网络接口。 （这也与早期的Kubernetes版本兼容）。

如果需要特定的端口号，则可以在 nodePort 字段中指定一个值。 控制平面将为您分配该端口或向API报告事务失败。 这意味着您需要自己注意可能发生的端口冲突。 您还必须使用有效的端口号，该端口号在配置用于NodePort的范围内。

使用 NodePort 可以让您自由设置自己的负载平衡解决方案，配置 Kubernetes 不完全支持的环境，甚至直接暴露一个或多个节点的IP。

需要注意的是，Service 能够通过 <NodeIP>:spec.ports[\*].nodePort 和 spec.clusterIp:spec.ports[\*].port 而对外可见。

### LoadBalancer 类型

使用支持外部负载均衡器的云提供商的服务，设置 type 的值为 "LoadBalancer"，将为 Service 提供负载均衡器。 负载均衡器是异步创建的，关于被提供的负载均衡器的信息将会通过 Service 的 status.loadBalancer 字段被发布出去。 实例:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
  clusterIP: 10.0.171.239
  loadBalancerIP: 78.11.24.19
  type: LoadBalancer
status:
  loadBalancer:
    ingress:
      - ip: 146.148.47.155
```

来自外部负载均衡器的流量将直接打到 backend Pod 上，不过实际它们是如何工作的，这要依赖于云提供商。

在这些情况下，将根据用户设置的 loadBalancerIP 来创建负载均衡器。 某些云提供商允许设置 loadBalancerIP。如果没有设置 loadBalancerIP，将会给负载均衡器指派一个临时 IP。 如果设置了 loadBalancerIP，但云提供商并不支持这种特性，那么设置的 loadBalancerIP 值将会被忽略掉。

- 注意：如果您使用的是 SCTP，请参阅下面有关 LoadBalancer 服务类型的 caveat。

- 注意：
  在 Azure 上，如果要使用用户指定的公共类型 loadBalancerIP ，则首先需要创建静态类型的公共IP地址资源。 此公共IP地址资源应与群集中其他自动创建的资源位于同一资源组中。 例如，MC_myResourceGroup_myAKSCluster_eastus。

  将分配的IP地址指定为loadBalancerIP。 确保您已更新云提供程序配置文件中的securityGroupName。 有关对 CreatingLoadBalancerFailed 权限问题进行故障排除的信息， 请参阅 与Azure Kubernetes服务（AKS）负载平衡器一起使用静态IP地址或通过高级网络在AKS群集上创建LoadBalancerFailed。

**内部负载均衡器**

在混合环境中，有时有必要在同一(虚拟)网络地址块内路由来自服务的流量。

在水平分割 DNS 环境中，您需要两个服务才能将内部和外部流量都路由到您的 endpoints。 您可以通过向服务添加以下注释之一来实现此目的。 要添加的注释取决于您使用的云服务提供商。

openstack

```
[...]
metadata:
    name: my-service
    annotations:
        service.beta.kubernetes.io/openstack-internal-load-balancer: "true"
[...]
```

baiduCloud

```
[...]
metadata:
    name: my-service
    annotations:
        service.beta.kubernetes.io/cce-load-balancer-internal-vpc: "true"
[...]
```

Azure

```
[...]
metadata:
    name: my-service
    annotations:
        service.beta.kubernetes.io/azure-load-balancer-internal: "true"
[...]
```

AWS

```
[...]
metadata:
    name: my-service
    annotations:
        service.beta.kubernetes.io/aws-load-balancer-internal: "true"
[...]
```

GCP
```
[...]
metadata:
    name: my-service
    annotations:
        cloud.google.com/load-balancer-type: "Internal"
[...]
```

### AWS TLS 支持

为了对在AWS上运行的集群提供部分TLS / SSL支持，您可以向 LoadBalancer 服务添加三个注释：

```yaml
metadata:
  name: my-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012
```

第一个指定要使用的证书的ARN。 它可以是已上载到 IAM 的第三方颁发者的证书，也可以是在 AWS Certificate Manager 中创建的证书。


```yaml
metadata:
  name: my-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: (https|http|ssl|tcp)
```

第二个注释指定 Pod 使用哪种协议。 对于 HTTPS 和 SSL，ELB 希望 Pod 使用证书通过加密连接对自己进行身份验证。

HTTP 和 HTTPS 选择第7层代理：ELB 终止与用户的连接，解析标头，并在转发请求时向 X-Forwarded-For 标头注入用户的 IP 地址（Pod 仅在连接的另一端看到 ELB 的 IP 地址）。

TCP 和 SSL 选择第4层代理：ELB 转发流量而不修改报头。

在某些端口处于安全状态而其他端口未加密的混合使用环境中，可以使用以下注释：

```yaml
metadata:
  name: my-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443,8443"
```

从Kubernetes v1.9起可以使用 预定义的 AWS SSL 策略 为您的服务使用HTTPS或SSL侦听器。 要查看可以使用哪些策略，可以使用 aws 命令行工具：

```bash
aws elb describe-load-balancer-policies --query 'PolicyDescriptions[].PolicyName'
```

然后，您可以使用 “service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy“ 注解; 例如：

```yaml
metadata:
   name: my-service
   annotations:
     service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: "ELBSecurityPolicy-TLS-1-2-2017-01"
```

***AWS上的PROXY协议支持***

为了支持在AWS上运行的集群，启用 PROXY协议, 您可以使用以下服务注释：

```yaml
metadata:
  name: my-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"
```

从1.3.0版开始，此注释的使用适用于 ELB 代理的所有端口，并且不能进行其他配置。

***AWS上的ELB访问日志***

有几个注释可用于管理AWS上ELB服务的访问日志。

注释 `service.beta.kubernetes.io/aws-load-balancer-access-log-enabled` 控制是否启用访问日志。

注解 `service.beta.kubernetes.io/aws-load-balancer-access-log-emit-interval` 控制发布访问日志的时间间隔（以分钟为单位）。 您可以指定5分钟或60分钟的间隔。

注释 `service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name` 控制存储负载均衡器访问日志的Amazon S3存储桶的名称。

注释 `service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-prefix` 指定为Amazon S3存储桶创建的逻辑层次结构。

```yaml
metadata:
  name: my-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-access-log-enabled: "true"
    # Specifies whether access logs are enabled for the load balancer
    service.beta.kubernetes.io/aws-load-balancer-access-log-emit-interval: "60"
    # The interval for publishing the access logs. You can specify an interval of either 5 or 60 (minutes).
    service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name: "my-bucket"
    # The name of the Amazon S3 bucket where the access logs are stored
    service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-prefix: "my-bucket-prefix/prod"
    # The logical hierarchy you created for your Amazon S3 bucket, for example `my-bucket-prefix/prod`
```

***AWS上的连接排空***

可以将注释 `service.beta.kubernetes.io/aws-load-balancer-connection-draining-enabled` 设置为 "true" 的值来管理 ELB 的连接消耗。 注释 `service.beta.kubernetes.io/aws-load-balancer-connection-draining-timeout` 也可以用于设置最大时间（以秒为单位），以保持现有连接在注销实例之前保持打开状态。

```yaml
metadata:
  name: my-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-connection-draining-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-connection-draining-timeout: "60"
```


***其他ELB注释***

还有其他一些注释，用于管理经典弹性负载均衡器，如下所述。

```yaml
metadata:
  name: my-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "60"
    # The time, in seconds, that the connection is allowed to be idle (no data has been sent over the connection) before it is closed by the load balancer

    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    # Specifies whether cross-zone load balancing is enabled for the load balancer

    service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: "environment=prod,owner=devops"
    # A comma-separated list of key-value pairs which will be recorded as
    # additional tags in the ELB.

    service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: ""
    # The number of successive successful health checks required for a backend to
    # be considered healthy for traffic. Defaults to 2, must be between 2 and 10

    service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "3"
    # The number of unsuccessful health checks required for a backend to be
    # considered unhealthy for traffic. Defaults to 6, must be between 2 and 10

    service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "20"
    # The approximate interval, in seconds, between health checks of an
    # individual instance. Defaults to 10, must be between 5 and 300
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "5"
    # The amount of time, in seconds, during which no response means a failed
    # health check. This value must be less than the service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval
    # value. Defaults to 5, must be between 2 and 60

    service.beta.kubernetes.io/aws-load-balancer-extra-security-groups: "sg-53fae93f,sg-42efd82e"
    # A list of additional security groups to be added to the ELB
```

- FEATURE STATE: Kubernetes v1.15 beta

```yaml
metadata:
  name: my-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

- 注意：
  NLB 仅适用于某些实例类。 有关受支持的实例类型的列表，请参见 Elastic Load Balancing 上的 AWS文档。

与经典弹性负载平衡器不同，网络负载平衡器（NLB）将客户端的 IP 地址转发到该节点。 如果服务的 `.spec.externalTrafficPolicy` 设置为 Cluster ，则客户端的IP地址不会传达到终端 Pod。

通过将 `.spec.externalTrafficPolicy` 设置为 Local，客户端IP地址将传播到终端 Pod，但这可能导致流量分配不均。 没有针对特定 LoadBalancer 服务的任何 Pod 的节点将无法通过自动分配的 `.spec.healthCheckNodePort` 进行 NLB 目标组的运行状况检查，并且不会收到任何流量。

为了获得平均流量，请使用DaemonSet或指定 pod anti-affinity使其不在同一节点上。

您还可以将NLB服务与 内部负载平衡器批注一起使用。

为了使客户端流量能够到达 NLB 后面的实例，使用以下 IP 规则修改了节点安全组：

|Rule|Protocol|Port(s)|IpRange(s)|IpRange Description|
|---|---|---|---|---|
|Health Check|TCP|NodePort(s) (.spec.healthCheckNodePort for .spec.externalTrafficPolicy = Local)|VPC CIDR|kubernetes.io/rule/nlb/health=<loadBalancerName>|
|Client Traffic|TCP|NodePort(s)|.spec.loadBalancerSourceRanges (defaults to 0.0.0.0/0)|kubernetes.io/rule/nlb/client=<loadBalancerName>|
|MTU Discovery|ICMP|3,4|.spec.loadBalancerSourceRanges (defaults to 0.0.0.0/0)|	kubernetes.io/rule/nlb/mtu=<loadBalancerName>|

为了限制哪些客户端IP可以访问网络负载平衡器，请指定 loadBalancerSourceRanges。

```yaml
spec:
  loadBalancerSourceRanges:
    - "143.231.0.0/16"
```

- 注意：
  如果未设置 .spec.loadBalancerSourceRanges ，则 Kubernetes 允许从 0.0.0.0/0 到节点安全组的流量。 如果节点具有公共 IP 地址，请注意，非 NLB 流量也可以到达那些修改后的安全组中的所有实例。

### 类型ExternalName

类型为 ExternalName 的服务将服务映射到 DNS 名称，而不是典型的选择器，例如 my-service 或者 cassandra。 您可以使用 spec.externalName 参数指定这些服务。

例如，以下 Service 定义将 `prod` 名称空间中的 `my-service` 服务映射到 `my.database.example.com`：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: prod
spec:
  type: ExternalName
  externalName: my.database.example.com
```

- 注意：
  ExternalName 接受 IPv4 地址字符串，但作为包含数字的 DNS 名称，而不是 IP 地址。 类似于 IPv4 地址的外部名称不能由 CoreDNS 或 ingress-nginx 解析，因为外部名称旨在指定规范的 DNS 名称。 要对 IP 地址进行硬编码，请考虑使用 headless Services。

当查找主机 `my-service.prod.svc.cluster.local` 时，群集DNS服务返回 CNAME 记录，其值为 `my.database.example.com`。 访问 `my-service` 的方式与其他服务的方式相同，但主要区别在于重定向发生在 DNS 级别，而不是通过代理或转发。 如果以后您决定将数据库移到群集中，则可以启动其 Pod，添加适当的选择器或端点以及更改服务的类型。

### 外部 IP

如果外部的 IP 路由到集群中一个或多个 Node 上，Kubernetes Service 会被暴露给这些 externalIPs。 通过外部 IP（作为目的 IP 地址）进入到集群，打到 Service 的端口上的流量，将会被路由到 Service 的 Endpoint 上。 externalIPs 不会被 Kubernetes 管理，它属于集群管理员的职责范畴。

根据 Service 的规定，externalIPs 可以同任意的 ServiceType 来一起指定。 在上面的例子中，my-service 可以在 “80.11.12.10:80”(externalIP:port) 上被客户端访问。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 9376
  externalIPs:
    - 80.11.12.10
```

## 不足之处

为 VIP 使用 userspace 代理，将只适合小型到中型规模的集群，不能够扩展到上千 Service 的大型集群。 查看 最初设计方案 获取更多细节。

使用 userspace 代理，隐藏了访问 Service 的数据包的源 IP 地址。 这使得一些类型的防火墙无法起作用。 iptables 代理不会隐藏 Kubernetes 集群内部的 IP 地址，但却要求客户端请求必须通过一个负载均衡器或 Node 端口。

Type 字段支持嵌套功能 —— 每一层需要添加到上一层里面。 不会严格要求所有云提供商（例如，GCE 就没必要为了使一个 LoadBalancer 能工作而分配一个 NodePort，但是 AWS 需要 ），但当前 API 是强制要求的。

## 虚拟IP实施

对很多想使用 Service 的人来说，前面的信息应该足够了。 然而，有很多内部原理性的内容，还是值去理解的。

### 避免冲突

Kubernetes 最主要的哲学之一，是用户不应该暴露那些能够导致他们操作失败、但又不是他们的过错的场景。 这种场景下，让我们来看一下网络端口 —— 用户不应该必须选择一个端口号，而且该端口还有可能与其他用户的冲突。 这就是说，在彼此隔离状态下仍然会出现失败。

为了使用户能够为他们的 Service 选择一个端口号，我们必须确保不能有2个 Service 发生冲突。 我们可以通过为每个 Service 分配它们自己的 IP 地址来实现。

为了保证每个 Service 被分配到一个唯一的 IP，需要一个内部的分配器能够原子地更新 etcd 中的一个全局分配映射表，这个更新操作要先于创建每一个 Service。 为了使 Service 能够获取到 IP，这个映射表对象必须在注册中心存在，否则创建 Service 将会失败，指示一个 IP 不能被分配。 一个后台 Controller 的职责是创建映射表（从 Kubernetes 的旧版本迁移过来，旧版本中是通过在内存中加锁的方式实现），并检查由于管理员干预和清除任意 IP 造成的不合理分配，这些 IP 被分配了但当前没有 Service 使用它们。

### Service IP 地址

不像 Pod 的 IP 地址，它实际路由到一个固定的目的地，Service 的 IP 实际上不能通过单个主机来进行应答。 相反，我们使用 iptables（Linux 中的数据包处理逻辑）来定义一个虚拟IP地址（VIP），它可以根据需要透明地进行重定向。 当客户端连接到 VIP 时，它们的流量会自动地传输到一个合适的 Endpoint。 环境变量和 DNS，实际上会根据 Service 的 VIP 和端口来进行填充。

kube-proxy支持三种代理模式: 用户空间，iptables和IPVS；它们各自的操作略有不同。

***Userspace***

作为一个例子，考虑前面提到的图片处理应用程序。 当创建 backend Service 时，Kubernetes master 会给它指派一个虚拟 IP 地址，比如 10.0.0.1。 假设 Service 的端口是 1234，该 Service 会被集群中所有的 kube-proxy 实例观察到。 当代理看到一个新的 Service， 它会打开一个新的端口，建立一个从该 VIP 重定向到新端口的 iptables，并开始接收请求连接。

当一个客户端连接到一个 VIP，iptables 规则开始起作用，它会重定向该数据包到 Service代理 的端口。 Service代理 选择一个 backend，并将客户端的流量代理到 backend 上。

这意味着 Service 的所有者能够选择任何他们想使用的端口，而不存在冲突的风险。 客户端可以简单地连接到一个 IP 和端口，而不需要知道实际访问了哪些 Pod。

***iptables***

再次考虑前面提到的图片处理应用程序。 当创建 backend Service 时，Kubernetes 控制面板会给它指派一个虚拟 IP 地址，比如 10.0.0.1。 假设 Service 的端口是 1234，该 Service 会被集群中所有的 kube-proxy 实例观察到。 当代理看到一个新的 Service， 它会安装一系列的 iptables 规则，从 VIP 重定向到 per-Service 规则。 该 per-Service 规则连接到 per-Endpoint 规则，该 per-Endpoint 规则会重定向（目标 NAT）到 backend。

当一个客户端连接到一个 VIP，iptables 规则开始起作用。一个 backend 会被选择（或者根据会话亲和性，或者随机），数据包被重定向到这个 backend。 不像 userspace 代理，数据包从来不拷贝到用户空间，kube-proxy 不是必须为该 VIP 工作而运行，并且客户端 IP 是不可更改的。 当流量打到 Node 的端口上，或通过负载均衡器，会执行相同的基本流程，但是在那些案例中客户端 IP 是可以更改的。

***IPVS***

在大规模集群（例如10,000个服务）中，iptables 操作会显着降低速度。 IPVS 专为负载平衡而设计，并基于内核内哈希表。 因此，您可以通过基于 IPVS 的 kube-proxy 在大量服务中实现性能一致性。 同时，基于 IPVS 的 kube-proxy 具有更复杂的负载平衡算法（最小连接，局部性，加权，持久性）。

##  API Object

Service 是Kubernetes REST API中的顶级资源。 您可以在以下位置找到有关API对象的更多详细信息： Service 对象 API.





参考资料： https://kubernetes.io/docs/concepts/services-networking/service/
