# 网络策略
网络策略（NetworkPolicy）是一种关于pod间及pod与其他网络端点间所允许的通信规则的规范。

NetworkPolicy 资源使用标签选择pod，并定义选定pod所允许的通信规则。

## 前提
网络策略通过网络插件来实现，所以用户必须使用支持 NetworkPolicy 的网络解决方案 - 简单地创建资源对象，而没有控制器来使它生效的话，是没有任何作用的。

> 比如部署使用calico。使用flannel是没有网络策略功能的

## 隔离和非隔离的Pod
默认情况下，Pod是非隔离的，它们接受任何来源的流量。

Pod可以通过相关的网络策略进行隔离。一旦命名空间中有网络策略选择了特定的Pod，该Pod会拒绝网络策略所不允许的连接。 (命名空间下其他未被网络策略所选择的Pod会继续接收所有的流量)

## NetworkPolicy 资源
查看 网络策略 来了解资源定义。

下面是一个 NetworkPolicy 的示例:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: 172.17.0.0/16
        except:
        - 172.17.1.0/24
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 6379
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/24
    ports:
    - protocol: TCP
      port: 5978
```
除非选择支持网络策略的网络解决方案，否则将上述示例发送到API服务器没有任何效果。

- **必填字段**: 与所有其他的Kubernetes配置一样，NetworkPolicy 需要 apiVersion、 kind和 metadata 字段。
- spec: NetworkPolicy spec 中包含了在一个命名空间中定义特定网络策略所需的所有信息
- podSelector: 每个 NetworkPolicy 都包括一个 podSelector ，它对该策略所应用的一组Pod进行选择。因为 NetworkPolicy 目前只支持定义 ingress 规则，这里的 podSelector 本质上是为该策略定义 “目标pod” 。示例中的策略选择带有 “role=db” 标签的pod。空的 podSelector 选择命名空间下的所有pod。
- policyTypes: 每个NetworkPolicy都包含一个policyTypes列表，其中可能包括Ingress，Egress或两者。 policyTypes字段指示给定的策略是否适用于到选定Pod的入站流量，来自选定Pod的出站流量，或两者都适用。 如果在NetworkPolicy上未指定任何policyType，则默认情况下将始终设置Ingress，并且如果NetworkPolicy具有任何出口规则，则将设置Egress。
- ingress: 每个 NetworkPolicy 包含一个 ingress 规则的白名单列表。（其中的）规则允许同时匹配 from 和 ports 部分的流量。示例策略中包含一条简单的规则： 它匹配一个单一的端口，来自两个来源中的一个， 第一个通过 namespaceSelector 指定，第二个通过 podSelector 指定。
- egress: 每个 NetworkPolicy 包含一个 egress 规则的白名单列表。每个规则都允许匹配 to 和 port 部分的流量。该示例策略包含一条规则，该规则将单个端口上的流量匹配到 10.0.0.0/24 中的任何目的地。

所以，示例网络策略:

1. 隔离 “default” 命名空间下 “role=db” 的pod (如果它们不是已经被隔离的话)。
2. 允许从 “default” 命名空间下带有 “role=frontend” 标签的pod到 “default” 命名空间下的pod的6379 TCP端口的连接。

  - 标签为 “role=frontend” 的 “default” 名称空间中的任何Pod
  - 名称空间中带有标签 “project=myproject” 的任何pod
  - IP 地址范围为 172.17.0.0–172.17.0.255 和 172.17.2.0–172.17.255.255（即，除了 172.17.1.0/24 之外的所有 172.17.0.0/16）
3. 允许从带有 “project=myproject” 标签的命名空间下的任何 pod 到 “default” 命名空间下的 pod 的6379 TCP端口的连接。

## 选择器 to 和 from 的行为
可以在 ingress from 部分或 egress to 部分中指定四种选择器：

- podSelector: 这将在与 NetworkPolicy 相同的名称空间中选择特定的 Pod，应将其允许作为入口源或出口目的地。

- namespaceSelector: 这将选择特定的名称空间，应将所有 Pod 用作其输入源或输出目的地。

- namespaceSelector 和 podSelector: 一个指定 namespaceSelector 和 podSelector 的 to/from 条目选择特定命名空间中的特定 Pod。注意使用正确的YAML语法；这项策略：

```yaml
...
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        user: alice
    podSelector:
      matchLabels:
        role: client
...
```
在 from 数组中仅包含一个元素，只允许来自标有 role = client 的 Pod 且该 Pod 所在的名称空间中标有user=alice的连接。这项策略：

```yaml
...
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        user: alice
  - podSelector:
      matchLabels:
        role: client
...
```

在 from 数组中包含两个元素，允许来自本地命名空间中标有 role = client 的 Pod 的连接，\*或\*来自任何名称空间中标有user = alice的任何Pod的连接。

如有疑问，请使用 kubectl describe 查看 Kubernetes 如何解释该策略。

ipBlock: 这将选择特定的 IP CIDR 范围以用作入口源或出口目的地。 这些应该是群集外部 IP，因为 Pod IP 存在时间短暂的且随机产生。

群集的入口和出口机制通常需要重写数据包的源 IP 或目标 IP。在发生这种情况的情况下，不确定在 NetworkPolicy 处理之前还是之后发生，并且对于网络插件，云提供商，Service 实现等的不同组合，其行为可能会有所不同。

在进入的情况下，这意味着在某些情况下，您可以根据实际的原始源 IP 过滤传入的数据包，而在其他情况下，NetworkPolicy 所作用的 源IP 则可能是 LoadBalancer 或 Pod的节点等。

对于出口，这意味着从 Pod 到被重写为集群外部 IP 的 Service IP 的连接可能会或可能不会受到基于 ipBlock 的策略的约束。

## 默认策略
默认情况下，如果名称空间中不存在任何策略，则所有进出该名称空间中的Pod的流量都被允许。以下示例使您可以更改该名称空间中的默认行为。

### 默认拒绝所有入口流量
您可以通过创建选择所有容器但不允许任何进入这些容器的入口流量的 NetworkPolicy 来为名称空间创建 “default” 隔离策略。

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```
这样可以确保即使容器没有选择其他任何 NetworkPolicy，也仍然可以被隔离。此策略不会更改默认的出口隔离行为。

### 默认允许所有入口流量
如果要允许所有流量进入某个命名空间中的所有 Pod（即使添加了导致某些 Pod 被视为“隔离”的策略），则可以创建一个策略来明确允许该命名空间中的所有流量。

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all
spec:
  podSelector: {}
  ingress:
  - {}
  policyTypes:
  - Ingress
```
### 默认拒绝所有出口流量
您可以通过创建选择所有容器但不允许来自这些容器的任何出口流量的 NetworkPolicy 来为名称空间创建 “default” egress 隔离策略。

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Egress
```
这样可以确保即使没有被其他任何 NetworkPolicy 选择的 Pod 也不会被允许流出流量。此策略不会更改默认的 ingress 隔离行为。

## 默认允许所有出口流量
如果要允许来自命名空间中所有 Pod 的所有流量（即使添加了导致某些 Pod 被视为“隔离”的策略），则可以创建一个策略，该策略明确允许该命名空间中的所有出口流量。

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all
spec:
  podSelector: {}
  egress:
  - {}
  policyTypes:
  - Egress
```
### 默认拒绝所有入口和所有出口流量
您可以为名称空间创建 “default” 策略，以通过在该名称空间中创建以下 NetworkPolicy 来阻止所有入站和出站流量。

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```
这样可以确保即使没有被其他任何 NetworkPolicy 选择的 Pod 也不会被允许进入或流出流量。

## SCTP 支持
FEATURE STATE: Kubernetes v1.12 alpha

Kubernetes 支持 SCTP 作为 NetworkPolicy 定义中的协议值作为 alpha 功能提供。要启用此功能，集群管理员需要在 apiserver 上启用 SCTPSupport 功能门，例如 “--feature-gates=SCTPSupport=true,...”。启用功能门后，用户可以将 NetworkPolicy 的 protocol 字段设置为 SCTP。 Kubernetes 相应地为 SCTP 关联设置网络，就像为 TCP 连接一样。

CNI插件必须在 NetworkPolicy 中将 SCTP 作为 protocol 值支持。

参考文档： https://kubernetes.io/docs/concepts/services-networking/network-policies/
