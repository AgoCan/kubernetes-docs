# 临时容器

Kubernetes v1.16 alpha

此页面概述了临时容器：一种特殊的容器，该容器在现有 Pod 中临时运行，为了完成用户启动的操作，例如故障排查。使用临时容器来检查服务，而不是构建应用程序。

- 警告： 临时容器处于早期的 alpha 阶段，不适用于生产环境集群。应该预料到临时容器在某些情况下不起作用，例如在定位容器的命名空间时。根据 Kubernetes 弃用政策，该 alpha 功能将来可能发生重大变化或完全删除。

## 了解临时容器

Pods 是 Kubernetes 应用程序的基本构建块。由于 pod 是一次性且可替换的，因此一旦 Pod 创建，就无法将容器加入到 Pod 中。取而代之的是，通常使用 deployments 以受控的方式来删除并替换 Pod。

有时有必要检查现有 Pod 的状态，例如，对于难以复现的故障进行排查。在这些场景中，可以在现有 Pod 中运行临时容器来检查其状态并运行任意命令。

### 什么是临时容器？
临时容器与其他容器的不同之处在于，它们缺少对资源或执行的保证，并且永远不会自动重启，因此不适用于构建应用程序。临时容器使用与常规容器相同的 `ContainerSpec` 段进行描述，但许多字段是不相容且不允许的。

- 临时容器没有端口配置，因此像 ports，livenessProbe，readinessProbe 这样的字段是不允许的。

- Pod 资源分配是不可变的，因此 resources 配置是不允许的。

- 有关允许字段的完整列表，请参见[临时容器参考文档](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.17/#ephemeralcontainer-v1-core)。

临时容器是使用 API 中的一种特殊的 `ephemeralcontainers` 处理器进行创建的，而不是直接添加到 `pod.spec` 段，因此无法使用 `kubectl edit` 来添加一个临时容器。

与常规容器一样，将临时容器添加到 Pod 后，将不能更改或删除临时容器。

## 临时容器的用途

当由于容器崩溃或容器镜像不包含调试实用程序而导致 kubectl exec 无用时，临时容器对于交互式故障排查很有用。

尤其是，distroless 镜像能够使得部署最小的容器镜像，从而减少攻击面并减少故障和漏洞的暴露。由于 distroless 镜像不包含 shell 或任何的调试工具，因此很难单独使用 kubectl exec 命令进行故障排查。

使用临时容器时，启用进程命名空间共享很有帮助，可以查看其他容器中的进程。

### 示例

- 注意： 本节中的示例要求启用 EphemeralContainers 特性，并且 kubernetes 客户端和服务端版本要求为 v1.16 或更高版本。

本节中的示例演示了临时容器如何出现在 API 中。 通常，您可以使用 kubectl 插件进行故障排查，从而自动化执行这些步骤。

临时容器是使用 Pod 的 ephemeralcontainers 子资源创建的，可以使用 kubectl --raw 命令进行显示。首先描述临时容器被添加为一个 EphemeralContainers 列表：

```json
{
    "apiVersion": "v1",
    "kind": "EphemeralContainers",
    "metadata": {
            "name": "example-pod"
    },
    "ephemeralContainers": [{
        "command": [
            "sh"
        ],
        "image": "busybox",
        "imagePullPolicy": "IfNotPresent",
        "name": "debugger",
        "stdin": true,
        "tty": true,
        "terminationMessagePolicy": "File"
    }]
}
```

使用如下命令更新已运行的临时容器 example-pod：

kubectl replace --raw /api/v1/namespaces/default/pods/example-pod/ephemeralcontainers  -f ec.json

这将返回临时容器的新列表：

```json
{
   "kind":"EphemeralContainers",
   "apiVersion":"v1",
   "metadata":{
      "name":"example-pod",
      "namespace":"default",
      "selfLink":"/api/v1/namespaces/default/pods/example-pod/ephemeralcontainers",
      "uid":"a14a6d9b-62f2-4119-9d8e-e2ed6bc3a47c",
      "resourceVersion":"15886",
      "creationTimestamp":"2019-08-29T06:41:42Z"
   },
   "ephemeralContainers":[
      {
         "name":"debugger",
         "image":"busybox",
         "command":[
            "sh"
         ],
         "resources":{

         },
         "terminationMessagePolicy":"File",
         "imagePullPolicy":"IfNotPresent",
         "stdin":true,
         "tty":true
      }
   ]
}

```

可以使用以下命令查看新创建的临时容器的状态：

```bash
kubectl describe pod example-pod
```

```
...
Ephemeral Containers:
  debugger:
    Container ID:  docker://cf81908f149e7e9213d3c3644eda55c72efaff67652a2685c1146f0ce151e80f
    Image:         busybox
    Image ID:      docker-pullable://busybox@sha256:9f1003c480699be56815db0f8146ad2e22efea85129b5b5983d0e0fb52d9ab70
    Port:          <none>
    Host Port:     <none>
    Command:
      sh
    State:          Running
      Started:      Thu, 29 Aug 2019 06:42:21 +0000
    Ready:          False
    Restart Count:  0
    Environment:    <none>
    Mounts:         <none>
...
```

可以使用以下命令连接到新的临时容器：

```bash
kubectl attach -it example-pod -c debugger
```

如果启用了进程命名空间共享，则可以查看该 Pod 所有容器中的进程。 例如，运行上述 attach 操作后，在调试器容器中运行 ps 操作：

```bash
# 在 "debugger" 临时容器内中运行此 shell 命令
ps auxww
```

运行命令后，输出类似于：

```bash
PID   USER     TIME  COMMAND
    1 root      0:00 /pause
    6 root      0:00 nginx: master process nginx -g daemon off;
   11 101       0:00 nginx: worker process
   12 101       0:00 nginx: worker process
   13 101       0:00 nginx: worker process
   14 101       0:00 nginx: worker process
   15 101       0:00 nginx: worker process
   16 101       0:00 nginx: worker process
   17 101       0:00 nginx: worker process
   18 101       0:00 nginx: worker process
   19 root      0:00 /pause
   24 root      0:00 sh
   29 root      0:00 ps auxww
```
