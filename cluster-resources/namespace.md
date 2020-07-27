# nameSpace 命名空间
Kubernetes支持由同一物理群集支持的多个虚拟群集。这些虚拟集群称为名称空间。

## 何时使用多个命名空间
命名空间旨在用于具有多个用户的环境，这些用户分布在多个团队或项目中。对于只有几到几十个用户的集群，您根本不需要创建或考虑名称空间。当需要名称空间提供的功能时，请开始使用它们。

命名空间提供了名称范围。资源名称在名称空间中必须唯一，但在名称空间之间则必须唯一。命名空间不能相互嵌套，每个Kubernetes资源只能在一个命名空间中。

命名空间是一种在多个用户之间划分群集资源的方式（通过resource quota）。

在将来的Kubernetes版本中，默认情况下，相同名称空间中的对象将具有相同的访问控制策略。

不必仅使用多个名称空间来分隔稍有不同的资源，例如同一软件的不同版本：使用标签来区分同一名称空间中的资源。



## nameSpace 的使用

其中以下指令中的`ns` 是`namespace`的缩写

创建`namespace`
```
kubectl create ns kubernetes-ns
```
查看
```
kubectl get ns
```
删除，删除`namespace`会把该命名空间下的所有的资源全部删除，尽量少操作

```
kubectl get namespace
```

Kubernetes从三个初始名称空间开始：

- `default` 没有其他名称空间的对象的默认名称空间
- `kube-system` `Kubernetes`系统创建的对象的名称空间
- `kube-public`该名称空间是自动创建的，并且对所有用户（包括未经身份验证的用户）可读。此名称空间主要保留给集群使用，以防某些资源在整个集群中公开可见。此名称空间的公共方面仅是约定，不是要求。

## 设置请求的名称空间

要为当前请求设置名称空间，请使用该`--namespace`标志.
例如:

```
kubectl run nginx --image=nginx --namespace=<insert-namespace-name-here>
kubectl get pods --namespace=<insert-namespace-name-here>
```

## 设置名称空间首选项
您可以为该上下文中的所有后续`kubectl`命令永久保存名称空间。  

```
kubectl config set-context --current --namespace=<insert-namespace-name-here>
# Validate it
kubectl config view --minify | grep namespace:
```

## 命名空间和DNS

创建服务时，它会创建一个相应的`DNS条目`。此项的形式为`<service-name>.<namespace-name>.svc.cluster.local`，这意味着如果容器仅使用`<service-name>`，它将解析为名称空间本地的服务。这对于在多个名称空间（例如开发（Development），预生产（Staging ）和生产（Production））中使用相同的配置很有用。如果要跨命名空间访问，则需要使用完全限定的域名（FQDN）。

## 并非所有对象都在命名空间中
大多数`Kubernetes`资源（例如 `pods`, `services`, `replication controllers`, 还有其他）都位于某些命名空间中。但是，名称空间资源本身并不在名称空间中。而且低级资源（例如节点和`persistentVolumes`）不在任何命名空间中。

要查看哪些`Kubernetes`资源在命名空间中和不在其中：

```
# 存在于命名空间
kubectl api-resources --namespaced=true

# 在命名空间之外
kubectl api-resources --namespaced=false
```







## 指定命名空间到指定的节点

[参考文档](https://stackoverflow.com/questions/52487333/how-to-assign-a-namespace-to-certain-nodes)

指定服务器到指定的节点

`ns1.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata
 name: ns1
 annotations:
   scheduler.alpha.kubernetes.io/node-selector: env=test
spec: {}
status: {}
```

```bash
kubectl apply -f ns1.yaml
```

创建之后，在这个命名空间下的所有`pod`会增加一句话

```
nodeSelector
  env: test
```

参考文档：

https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/  
