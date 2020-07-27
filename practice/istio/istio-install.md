# Istio部署
使用的是`istioctl`命令进行部署 `Istio`， 官方暂没推荐使用helm部署了
## 搭建平台
在安装Istio之前，您需要一个运行兼容版本的Kubernetes 的集群。Istio 1.4已通过Kubernetes 1.13、1.14、1.15版进行了测试。

通过选择适当的特定于平台的设置说明来创建集群。

**此次部署，使用虚拟机集群部署测试**  

## 下载版本
下载Istio发行版，其中包括安装文件，示例和 [istioctl](https://istio.io/docs/reference/commands/istioctl/)命令行实用程序。

1. 进入Istio发布页面，下载与您的操作系统相对应的安装文件。或者，在macOS或Linux系统上，您可以运行以下命令来自动下载并解压缩最新版本：

  ```bash
    curl -L https://istio.io/downloadIstio | sh -
  ```

2. 移至Istio软件包目录。例如，如果软件包为 istio-1.4.3：

  ```bash
    cd istio-1.4.3
  ```

装目录包含：

- Kubernetes的安装YAML文件在 install/kubernetes中的示例应用程序
- samples/目录中的客户端二进制文件。
- 手动注入Envoy作为Sidecar代理时使用。istioctl/bin/istioctl

3. istioctl在macOS或Linux系统上，将客户端添加到您的路径中：

  ```bash
  export PATH=$PWD/bin:$PATH
  ```

## 安装Istio
这些说明假定您是Istio的新手，它提供了简化的说明来安装Istio的内置demo 配置文件。通过此安装，您可以快速开始评估Istio。如果您已经熟悉Istio或对安装其他配置配置文件或更高级的部署模型感兴趣，请按照istioctl的说明进行安装。

**演示配置概要文件不适用于性能评估。它旨在通过高级别的跟踪和访问日志来展示Istio功能。**

1. 安装demo配置文件
  ```bash
    istioctl manifest apply --set profile=demo
    # 使用清单方式
    #istioctl manifest generate  --set profile=demo > manifest-istio.yaml
    #kubectl create ns istio-system
    #kubectl apply -f manifest-istio.yaml
  ```
2. 通过确保已部署以下Kubernetes服务来验证安装，并确认CLUSTER-IP除了jaeger-agent服务之外，它们均具有合适的服务：

  ```bash
    kubectl get svc -n istio-system
  ```

  **如果您的群集在不支持外部负载均衡器（例如minikube）的环境中运行，则 EXTERNAL-IPof istio-ingressgateway将显示 <pending>。要访问网关，请使用服务的 NodePort，或使用端口转发。**

  此外，还要确保相应Kubernetes pod 部署，并有一个STATUS的Running：

  ```bash
    kubectl get pods -n istio-system
  ```

## 接下来

安装Istio后，您现在可以部署自己的应用程序或安装随附的示例应用程序之一。

**该应用程序必须对所有HTTP通信使用HTTP / 1.1或HTTP / 2.0协议。不支持HTTP / 1.0。**

如果使用部署应用程序kubectl apply，则Istio边车注入器 会自动将Envoy容器注入到您的应用程序容器中，如果它们是在标有的名称空间中启动的istio-injection=enabled：

```bash
kubectl label namespace <namespace> istio-injection=enabled
kubectl create -n <namespace> -f <your-app-spec>.yaml
```

在没有istio-injection标签的名称空间中，您可以 istioctl kube-inject 在部署它们之前在应用程序pod中手动注入Envoy容器：

```bash
istioctl kube-inject -f <your-app-spec>.yaml | kubectl apply -f -
```

## 卸载

卸载会删除RBAC权限，istio-system名称空间以及它下面的层次结构中的所有资源。可以忽略不存在的资源的错误，因为它们可能已被分层删除。

```bash
istioctl manifest generate --set profile=demo | kubectl delete -f -
```








参考文档：
https://istio.io/docs/setup/getting-started/  
https://github.com/istio/installer  
