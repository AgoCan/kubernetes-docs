# Ingres
```bash
for i in `kubectl get ingress -n default  | grep ingress| awk '{print $1}'`;do kubectl patch ingress -n default $i -p '{"spec": {"rules": [{"host": "new.hankbook.net"}]}}';done
```

Ingress 是对集群中服务的外部访问进行管理的 API 对象，典型的访问方式是 HTTP。

Ingress 可以提供负载均衡、SSL 终结和基于名称的虚拟托管。

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: demo
  labels:
    name: demo
    app: web
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: demo.hankbook.cn
    http:
      paths:
      - path:
        backend:
          serviceName: demo
          servicePort: 80
```

## 专用术语
为了表达更加清晰，本指南定义了以下术语：

节点（Node）:

Kubernetes 集群中其中一台工作机器，是集群的一部分。

集群（Cluster）:

一组运行程序（这些程序是容器化的，被 Kubernetes 管理的）的节点。 在此示例中，和在大多数常见的Kubernetes部署方案，集群中的节点都不会是公共网络。

边缘路由器（Edge router）:

在集群中强制性执行防火墙策略的路由器（router）。可以是由云提供商管理的网关，也可以是物理硬件。

集群网络（Cluster network）:

一组逻辑或物理的链接，根据 Kubernetes 网络模型 在集群内实现通信。

服务（Service）：

Kubernetes Service 使用 标签 选择器（selectors）标识的一组 Pod。除非另有说明，否则假定服务只具有在集群网络中可路由的虚拟 IP。

## Ingress 是什么？

Ingress 公开了从集群外部到集群内 services 的HTTP和HTTPS路由。 流量路由由 Ingress 资源上定义的规则控制。

```
  internet
     |
 [ Ingress ]
--|-----|--
[ Services ]
```

可以将 Ingress 配置为提供服务外部可访问的 URL、负载均衡流量、终止 SSL / TLS 并提供基于名称的虚拟主机。Ingress 控制器通常负责通过负载均衡器来实现 Ingress，尽管它也可以配置边缘路由器或其他前端来帮助处理流量。

`Ingress` 不会公开任意端口或协议。 将 `HTTP` 和 `HTTPS` 以外的服务公开到 `Internet` 时，通常使用 `Service.Type=NodePort` 或者 `Service.Type=LoadBalancer` 类型的服务。

## 环境准备

[部署文档](https://kubernetes.hankbook.cn/service-discovery/ingress/install.html)

您必须具有 ingress 控制器才能满足 Ingress 的要求。仅创建 Ingress 资源无效。

您可能需要部署 Ingress 控制器，例如 ingress-nginx。您可以从许多 Ingress 控制器中进行选择。

- **注意**：确保您查看了 Ingress 控制器的文档，以了解选择它的注意事项。

一定要检查一下这个控制器的 beta 限制。 在 GCE／Google Kubernetes Engine 之外的环境中，需要将控制器部署 为 Pod。


## Ingress 资源

一个最小的 Ingress 资源示例：

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: test-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /testpath
        backend:
          serviceName: test
          servicePort: 80
```

与所有其他 Kubernetes 资源一样，Ingress 需要使用 apiVersion、kind 和 metadata 字段。 有关使用配置文件的一般信息，请参见部署应用、 配置容器、管理资源。 Ingress 经常使用注解（annotations）来配置一些选项，具体取决于 Ingress 控制器，例如 rewrite-target annotation。 不同的 Ingress 控制器支持不同的注解（annotations）。查看文档以供您选择 Ingress 控制器，以了解支持哪些注解（annotations）。

Ingress 规范 具有配置负载均衡器或者代理服务器所需的所有信息。最重要的是，它包含与所有传入请求匹配的规则列表。Ingress 资源仅支持用于定向 HTTP 流量的规则。

### Ingress 规则

每个 HTTP 规则都包含以下信息：

- 可选主机。在此示例中，未指定主机，因此该规则适用于通过指定 IP 地址的所有入站 HTTP 通信。如果提供了主机（例如 foo.bar.com），则规则适用于该主机。
- 路径列表（例如，/testpath）,每个路径都有一个由 serviceName 和 servicePort 定义的关联后端。在负载均衡器将流量定向到引用的服务之前，主机和路径都必须匹配传入请求的内容。
- 后端是服务文档中所述的服务和端口名称的组合。与规则的主机和路径匹配的对 Ingress 的HTTP（和HTTPS）请求将发送到列出的后端。

通常在 Ingress 控制器中配置默认后端，以服务任何不符合规范中路径的请求。

### 默认后端

没有规则的 Ingress 将所有流量发送到单个默认后端。默认后端通常是 Ingress 控制器的配置选项，并且未在 Ingress 资源中指定。

如果没有主机或路径与 Ingress 对象中的 HTTP 请求匹配，则流量将路由到您的默认后端。

Ingress 类型

### 单服务 Ingress

现有的 Kubernetes 概念允许您暴露单个 Service (查看替代方案)，您也可以通过指定无规则的 默认后端 来对 Ingress 进行此操作。

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test-ingress
spec:
  backend:
    serviceName: testsvc
    servicePort: 80
```

如果使用 kubectl apply -f 创建它，则应该能够查看刚刚添加的 Ingress 的状态：

```bash
kubectl get ingress test-ingress
```

其中 107.178.254.228 是由 Ingress 控制器分配以满足该 Ingress 的 IP。


- **注意**：Ingress 控制器和负载均衡器可能需要一两分钟才能分配 IP 地址。 在此之前，您通常会看到地址为 <pending>。

- **注意**：入口控制器和负载平衡器可能需要一两分钟才能分配IP地址。 在此之前，您通常会看到地址字段的值被设定为 <pending>。

### 简单分列
一个分列配置根据请求的 HTTP URI 将流量从单个 IP 地址路由到多个服务。 Ingress 允许您将负载均衡器的数量降至最低。例如，这样的设置：


```
foo.bar.com -> 178.91.123.132 -> / foo    service1:4200
                                 / bar    service2:8080
```

将需要一个 Ingress，例如：

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: simple-fanout-example
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: foo.bar.com
    http:
      paths:
      - path: /foo
        backend:
          serviceName: service1
          servicePort: 4200
      - path: /bar
        backend:
          serviceName: service2
          servicePort: 8080
```

当您使用 kubectl apply -f 创建 Ingress 时：

```bash
kubectl describe ingress simple-fanout-example
```

```bash
Name:             simple-fanout-example
Namespace:        default
Address:          178.91.123.132
Default backend:  default-http-backend:80 (10.8.2.3:8080)
Rules:
  Host         Path  Backends
  ----         ----  --------
  foo.bar.com
               /foo   service1:4200 (10.8.0.90:4200)
               /bar   service2:8080 (10.8.0.91:8080)
Annotations:
  nginx.ingress.kubernetes.io/rewrite-target:  /
Events:
  Type     Reason  Age                From                     Message
  ----     ------  ----               ----                     -------
  Normal   ADD     22s                loadbalancer-controller  default/test
```

Ingress 控制器将提供实现特定的负载均衡器来满足 Ingress，只要 Service (s1，s2) 存在。 当它这样做了，你会在地址栏看到负载均衡器的地址。


- **注意**：根据您使用的 Ingress 控制器，您可能需要创建默认 HTTP 后端 Service。

### 基于名称的虚拟托管

基于名称的虚拟主机支持将 HTTP 流量路由到同一 IP 地址上的多个主机名。

```
foo.bar.com --|                 |-> foo.bar.com service1:80
              | 178.91.123.132  |
bar.foo.com --|                 |-> bar.foo.com service2:80
```

以下 Ingress 让后台负载均衡器基于主机 header 路由请求。

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: name-virtual-host-ingress
spec:
  rules:
  - host: foo.bar.com
    http:
      paths:
      - backend:
          serviceName: service1
          servicePort: 80
  - host: bar.foo.com
    http:
      paths:
      - backend:
          serviceName: service2
          servicePort: 80
```

如果您创建的 Ingress 资源没有规则中定义的任何主机，则可以匹配到您 Ingress 控制器 IP 地址的任何网络流量，而无需基于名称的虚拟主机。

例如，以下 Ingress 资源会将 first.bar.com 请求的流量路由到 service1，将 second.foo.com 请求的流量路由到 service2，而没有在请求中定义主机名的 IP 地址的流量路由（即，不提供请求标头）到 service3。

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: name-virtual-host-ingress
spec:
  rules:
  - host: first.bar.com
    http:
      paths:
      - backend:
          serviceName: service1
          servicePort: 80
  - host: second.foo.com
    http:
      paths:
      - backend:
          serviceName: service2
          servicePort: 80
  - http:
      paths:
      - backend:
          serviceName: service3
          servicePort: 80
```

### TLS

您可以通过指定包含 TLS 私钥和证书的 secret Secret 来加密 Ingress。 目前，Ingress 只支持单个 TLS 端口 443，并假定 TLS 终止。

如果 Ingress 中的 TLS 配置部分指定了不同的主机，那么它们将根据通过 SNI TLS 扩展指定的主机名（如果 Ingress 控制器支持 SNI）在同一端口上进行复用。 TLS Secret 必须包含名为 tls.crt 和 tls.key 的密钥，这些密钥包含用于 TLS 的证书和私钥，例如：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: testsecret-tls
  namespace: default
data:
  tls.crt: base64 encoded cert
  tls.key: base64 encoded key
type: kubernetes.io/tls
```

在 Ingress 中引用此 Secret 将会告诉 Ingress 控制器使用 TLS 加密从客户端到负载均衡器的通道。您需要确保创建的 TLS secret 来自包含 sslexample.foo.com 的 CN 的证书。

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: tls-example-ingress
spec:
  tls:
  - hosts:
    - sslexample.foo.com
    secretName: testsecret-tls
  rules:
    - host: sslexample.foo.com
      http:
        paths:
        - path: /
          backend:
            serviceName: service1
            servicePort: 80
```

- **注意**：各种 Ingress 控制器所支持的 TLS 功能之间存在差异。请参阅有关文件 nginx、 GCE 或者任何其他平台特定的 Ingress 控制器，以了解 TLS 如何在您的环境中工作。

### 负载均衡

Ingress 控制器使用一些适用于所有 Ingress 的负载均衡策略设置进行自举，例如负载均衡算法、后端权重方案和其他等。更高级的负载均衡概念（例如，持久会话、动态权重）尚未通过 Ingress 公开。您可以通过用于服务的负载均衡器来获取这些功能。

值得注意的是，即使健康检查不是通过 Ingress 直接暴露的，但是在 Kubernetes 中存在并行概念，比如 就绪检查，它允许您实现相同的最终结果。 请检查控制器特殊说明文档，以了解他们是怎样处理健康检查的 ( nginx， GCE)。

## 更新 Ingress

要更新现有的 Ingress 以添加新的 Host，可以通过编辑资源来对其进行更新：

```bash
kubectl describe ingress test
```

```
**[terminal]
Name:             test
Namespace:        default
Address:          178.91.123.132
Default backend:  default-http-backend:80 (10.8.2.3:8080)
Rules:
  Host         Path  Backends
  ----         ----  --------
  foo.bar.com
               /foo   service1:80 (10.8.0.90:80)
Annotations:
  nginx.ingress.kubernetes.io/rewrite-target:  /
Events:
  Type     Reason  Age                From                     Message
  ----     ------  ----               ----                     -------
  Normal   ADD     35s                loadbalancer-controller  default/test
```

```bash
kubectl edit ingress test
```

这将弹出具有 YAML 格式的现有配置的编辑器。 修改它来增加新的主机：

```yaml
spec:
  rules:
  - host: foo.bar.com
    http:
      paths:
      - backend:
          serviceName: service1
          servicePort: 80
        path: /foo
  - host: bar.baz.com
    http:
      paths:
      - backend:
          serviceName: service2
          servicePort: 80
        path: /foo
..
```

保存更改后，kubectl 将更新 API 服务器中的资源，该资源将告诉 Ingress 控制器重新配置负载均衡器。

```bash
kubectl describe ingress test
```

```
**[terminal]
Name:             test
Namespace:        default
Address:          178.91.123.132
Default backend:  default-http-backend:80 (10.8.2.3:8080)
Rules:
  Host         Path  Backends
  ----         ----  --------
  foo.bar.com
               /foo   service1:80 (10.8.0.90:80)
  bar.baz.com
               /foo   service2:80 (10.8.0.91:80)
Annotations:
  nginx.ingress.kubernetes.io/rewrite-target:  /
Events:
  Type     Reason  Age                From                     Message
  ----     ------  ----               ----                     -------
  Normal   ADD     45s                loadbalancer-controller  default/test
```

您可以通过 kubectl replace -f 命令调用修改后的 Ingress yaml 文件来获得同样的结果。

## 跨可用区失败
用于跨故障域传播流量的技术在云提供商之间是不同的。详情请查阅相关 Ingress 控制器的文档。 请查看相关 Ingress 控制器的文档以了解详细信息。 您还可以参考联邦文档，以获取有关在联合集群中部署Ingress的详细信息。

## 未来工作
跟踪 SIG 网络以获得有关 Ingress 和相关资源演变的更多细节。您还可以跟踪 Ingress 仓库以获取有关各种 Ingress 控制器的更多细节。

## 替代方案
不直接使用 Ingress 资源，也有多种方法暴露 Service：

- 使用 Service.Type=LoadBalancer
- 使用 Service.Type=NodePort

参考资料：https://kubernetes.io/docs/concepts/services-networking/ingress/
