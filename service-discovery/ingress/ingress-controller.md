# Ingress 控制器
为了让 Ingress 资源工作，集群必须有一个正在运行的 Ingress 控制器。

与作为 kube-controller-manager 可执行文件的一部分运行的其他类型的控制器不同，Ingress 控制器不是随集群自动启动的。 基于此页面，您可选择最适合您的集群的 ingress 控制器实现。

Kubernetes 作为一个项目，目前支持和维护 GCE 和 nginx 控制器。


## 其他控制器

- [AKS 应用程序网关 Ingress 控制器]使用 Azure 应用程序网关启用AKS 集群 ingress。
- Ambassador API 网关， 一个基于 Envoy 的 ingress 控制器，有着来自社区 的支持和来自 Datawire 的商业 支持。
- AppsCode Inc. 为最广泛使用的基于 HAProxy 的 ingress 控制器 Voyager 提供支持和维护。
- AWS ALB Ingress 控制器通过 AWS 应用 Load Balancer 启用 ingress。
- Contour 是一个基于 Envoy 的 ingress 控制器，它由 VMware 提供和支持。
- Citrix 为其硬件（MPX），虚拟化（VPX）和 免费容器化 (CPX) ADC 提供了一个 Ingress 控制器，用于裸金属和云部署。
- F5 Networks 为 用于 Kubernetes 的 F5 BIG-IP 控制器提供支持和维护。
- Gloo 是一个开源的基于 Envoy 的 ingress 控制器，它提供了 API 网关功能，有着来自 solo.io 的企业级支持。
- HAProxy Ingress 是 HAProxy 高度可定制的、由社区驱动的 Ingress 控制器。
- HAProxy Technologies 为用于 Kubernetes 的 HAProxy Ingress 控制器 提供支持和维护。具体信息请参考官方文档。
- 基于 Istio 的 ingress 控制器控制 Ingress 流量。
- Kong 为用于 Kubernetes 的 Kong Ingress 控制器 提供社区或商业支持和维护。
- NGINX, Inc. 为用于 Kubernetes 的 NGINX Ingress 控制器提供支持和维护。
- Skipper HTTP 路由器和反向代理，用于服务组合，包括诸如 Kubernetes Ingress 之类的用例，被设计为用于构建自定义代理的库。
- Traefik 是一个全功能的 ingress 控制器 （Let’s Encrypt，secrets，http2，websocket），并且它也有来自 Containous 的商业支持。

## 使用多个 Ingress 控制器

你可以在集群中部署任意数量的 ingress 控制器。 创建 ingress 时，应该使用适当的 ingress.class 注解每个 ingress 以表明在集群中如果有多个 ingress 控制器时，应该使用哪个 ingress 控制器。

如果不定义 ingress.class，云提供商可能使用默认的 ingress 控制器。

理想情况下，所有 ingress 控制器都应满足此规范，但各种 ingress 控制器的操作略有不同。

- **注意**： 确保您查看了 ingress 控制器的文档，以了解选择它的注意事项。


参考文档： https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/
