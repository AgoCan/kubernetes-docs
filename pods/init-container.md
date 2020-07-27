# Init 容器
本页提供了 Init 容器的概览，它是一种专用的容器，在Pod内的应用容器启动之前运行，并包括一些应用镜像中不存在的实用工具和安装脚本。

## 理解 Init 容器
Pod 可以包含多个容器，应用运行在这些容器里面，同时 Pod 也可以有一个或多个先于应用容器启动的 Init 容器。

Init 容器与普通的容器非常像，除了如下两点：

- 它们总是运行到完成。
- 每个都必须在下一个启动之前成功完成。

如果 Pod 的 Init 容器失败，Kubernetes 会不断地重启该 Pod，直到 Init 容器成功为止。然而，如果 Pod 对应的 restartPolicy 值为 Never，它不会重新启动。

指定容器为 Init 容器，需要在 Pod 的 spec 中添加 initContainers 字段， 该字段內以Container 类型对象数组的形式组织，和应用的 containers 数组同级相邻。 Init 容器的状态在 status.initContainerStatuses 字段中以容器状态数组的格式返回（类似 status.containerStatuses 字段）。

### 与普通容器的不同之处

Init 容器支持应用容器的全部字段和特性，包括资源限制、数据卷和安全设置。 然而，Init 容器对资源请求和限制的处理稍有不同，在下面 资源 处有说明。

同时 Init 容器不支持 Readiness Probe，因为它们必须在 Pod 就绪之前运行完成。

如果为一个 Pod 指定了多个 Init 容器，这些容器会按顺序逐个运行。每个 Init 容器必须运行成功，下一个才能够运行。当所有的 Init 容器运行完成时，Kubernetes 才会为 Pod 初始化应用容器并像平常一样运行。

## Init 容器能做什么？
因为 Init 容器具有与应用容器分离的单独镜像，其启动相关代码具有如下优势：

- Init 容器可以包含一些安装过程中应用容器中不存在的实用工具或个性化代码。例如，没有必要仅为了在安装过程中使用类似 sed、 awk、 python 或 dig 这样的工具而去FROM 一个镜像来生成一个新的镜像。
- Init 容器可以安全地运行这些工具，避免这些工具导致应用镜像的安全性降低。
- 应用镜像的创建者和部署者可以各自独立工作，而没有必要联合构建一个单独的应用镜像。
- Init 容器能以不同于Pod内应用容器的文件系统视图运行。因此，Init容器可具有访问 Secrets 的权限，而应用容器不能够访问。
- 由于 Init 容器必须在应用容器启动之前运行完成，因此 Init 容器提供了一种机制来阻塞或延迟应用容器的启动，直到满足了一组先决条件。一旦前置条件满足，Pod内的所有的应用容器会并行启动。

### 示例

下面是一些如何使用 Init 容器的想法：

- 等待一个 Service 完成创建，通过类似如下 shell 命令：

```
for i in {1..100}; do sleep 1; if dig myservice; then exit 0; fi; exit 1
```

- 注册这个 Pod 到远程服务器，通过在命令中调用 API，类似如下：

```
curl -X POST http://$MANAGEMENT_SERVICE_HOST:$MANAGEMENT_SERVICE_PORT/register -d 'instance=$(<POD_NAME>)&ip=$(<POD_IP>)'

```

- 在启动应用容器之前等一段时间，使用类似命令：

```
`sleep 60`
```

- 克隆 Git 仓库到 Volume。

- 将配置值放到配置文件中，运行模板工具为主应用容器动态地生成配置文件。例如，在配置文件中存放 POD_IP 值，并使用 Jinja 生成主应用配置文件。

### 使用 Init 容器

下面的例子定义了一个具有 2 个 Init 容器的简单 Pod。 第一个等待 myservice 启动，第二个等待 mydb 启动。 一旦这两个 Init容器 都启动完成，Pod 将启动spec区域中的应用容器。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  labels:
    app: myapp
spec:
  containers:
  - name: myapp-container
    image: busybox:1.28
    command: ['sh', '-c', 'echo The app is running! && sleep 3600']
  initContainers:
  - name: init-myservice
    image: busybox:1.28
    command: ['sh', '-c', 'until nslookup myservice; do echo waiting for myservice; sleep 2; done;']
  - name: init-mydb
    image: busybox:1.28
    command: ['sh', '-c', 'until nslookup mydb; do echo waiting for mydb; sleep 2; done;']
```

下面的 yaml 文件展示了 mydb 和 myservice 两个 Service：

```yaml
kind: Service
apiVersion: v1
metadata:
  name: myservice
spec:
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
---
kind: Service
apiVersion: v1
metadata:
  name: mydb
spec:
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9377
```

要启动这个 Pod，可以执行如下命令：

```bash
kubectl apply -f myapp.yaml
```

要检查其状态：

```bash
kubectl get -f myapp.yaml
```

如需更详细的信息：

```bash
kubectl describe -f myapp.yaml
```

如需查看Pod内 Init 容器的日志，请执行:

```bash
kubectl logs myapp-pod -c init-myservice # Inspect the first init container
kubectl logs myapp-pod -c init-mydb      # Inspect the second init container
```

在这一刻，Init 容器将会等待至发现名称为mydb和myservice的 Service。

如下为创建这些 Service 的配置文件：

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: myservice
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 9376
---
apiVersion: v1
kind: Service
metadata:
  name: mydb
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 9377
```

创建mydb和myservice的 service 命令：

```bash
kubectl create -f services.yaml
```

这样你将能看到这些 Init容器 执行完毕，随后my-app的Pod转移进入 Running 状态：

```bash
kubectl get -f myapp.yaml
```

一旦我们启动了 mydb 和 myservice 这两个 Service，我们能够看到 Init 容器完成，并且 myapp-pod 被创建：

这个简单的例子应该能为你创建自己的 Init 容器提供一些启发。

## 具体行为

在 Pod 启动过程中，每个Init 容器在网络和数据卷初始化之后会按顺序启动。每个 Init容器 成功退出后才会启动下一个 Init容器。 如果因为运行或退出时失败引发容器启动失败，它会根据 Pod 的 restartPolicy 策略进行重试。 然而，如果 Pod 的 restartPolicy 设置为 Always，Init 容器失败时会使用 restartPolicy 的 OnFailure 策略。

在所有的 Init 容器没有成功之前，Pod 将不会变成 Ready 状态。 Init 容器的端口将不会在 Service 中进行聚集。 正在初始化中的 Pod 处于 Pending 状态，但会将条件 Initializing 设置为 true。

如果 Pod 重启，所有 Init 容器必须重新执行。

对 Init 容器 spec 的修改仅限于容器的 image 字段。 更改 Init 容器的 image 字段，等同于重启该 Pod。

因为 Init 容器可能会被重启、重试或者重新执行，所以 Init 容器的代码应该是幂等的。 特别地，基于 EmptyDirs 写文件的代码，应该对输出文件可能已经存在做好准备。

Init 容器具有应用容器的所有字段。 然而 Kubernetes 禁止使用 readinessProbe，因为 Init 容器不能定义不同于完成（completion）的就绪（readiness）。 这一点会在校验时强制执行。

在 Pod 上使用 activeDeadlineSeconds和在容器上使用 livenessProbe 可以避免 Init 容器一直重复失败。 activeDeadlineSeconds 时间包含了 Init 容器启动的时间。

在 Pod 中的每个应用容器和 Init 容器的名称必须唯一；与任何其它容器共享同一个名称，会在校验时抛出错误。

### 资源
给定Init 容器的执行顺序下，资源使用适用于如下规则：

- 所有 Init 容器上定义的任何特定资源的 limit 或 request 的最大值，作为 Pod 有效初始 request/limit
- Pod 对资源的 *有效 limit/request* 是如下两者的较大者：
  - 所有应用容器对某个资源的 limit/request 之和
  - 对某个资源的有效初始 limit/request
- 基于有效 limit/request 完成调度，这意味着 Init 容器能够为初始化过程预留资源，这些资源在 Pod 生命周期过程中并没有被使用。
- Pod 的 有效 QoS 层 ，与 Init 容器和应用容器的一样。

配额和限制适用于有效 Pod的 limit/request。 Pod 级别的 cgroups 是基于有效 Pod 的 limit/request，和调度器相同。

### Pod 重启的原因
Pod重启导致 Init 容器重新执行，主要有如下几个原因：

- 用户更新 Pod 的 Spec 导致 Init 容器镜像发生改变。Init 容器镜像的变更会引起 Pod 重启. 应用容器镜像的变更仅会重启应用容器。
- Pod 的基础设施容器 (译者注：如 pause 容器) 被重启。 这种情况不多见，必须由具备 root 权限访问 Node 的人员来完成。
- 当 restartPolicy 设置为 Always，Pod 中所有容器会终止而强制重启，由于垃圾收集导致 Init 容器的完成记录丢失。

## 创建一个包含 Init 容器的 Pod

本例中您将创建一个包含一个应用容器和一个 Init 容器的 Pod。Init 容器在应用容器启动前运行完成。

下面是 Pod 的配置文件：

- pods/init-containers.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
    - name: workdir
      mountPath: /usr/share/nginx/html
  # These containers are run during pod initialization
  initContainers:
  - name: install
    image: busybox
    command:
    - wget
    - "-O"
    - "/work-dir/index.html"
    - http://kubernetes.io
    volumeMounts:
    - name: workdir
      mountPath: "/work-dir"
  dnsPolicy: Default
  volumes:
  - name: workdir
    emptyDir: {}
```

配置文件中，您可以看到应用容器和 Init 容器共享了一个卷。

Init 容器将共享卷挂载到了 /work-dir 目录，应用容器将共享卷挂载到了 /usr/share/nginx/html 目录。 Init 容器执行完下面的命令就终止：

```bash
wget -O /work-dir/index.html http://kubernetes.io
```
请注意 Init 容器在 nginx 服务器的根目录写入 index.html。

创建 Pod：

```bash
kubectl create -f pods/init-containers.yaml
```
检查 nginx 容器运行正常：

```bash
kubectl get pod init-demo
```

结果表明 nginx 容器运行正常：

```
NAME        READY     STATUS    RESTARTS   AGE
init-demo   1/1       Running   0          1m
```

通过 shell 进入 init-demo Pod 中的 nginx 容器：

```bash
kubectl exec -it init-demo -- /bin/bash
```

在 shell 中，发送个 GET 请求到 nginx 服务器：

```
root@nginx:~# apt-get update
root@nginx:~# apt-get install curl
root@nginx:~# curl localhost
```

结果表明 nginx 正在为 Init 容器编写的 web 页面服务：

```
<!Doctype html>
<html id="home">

<head>
...
"url": "http://kubernetes.io/"}</script>
</head>
<body>
  ...
  <p>Kubernetes is open source giving you the freedom to take advantage ...</p>
  ...
```


你可以在Pod的规格信息中与containers数组同级的位置指定 Init 容器。





参考文档：  

https://k8smeetup.github.io/docs/tasks/debug-application-cluster/debug-init-containers/  
https://kubernetes.io/docs/concepts/workloads/pods/init-containers/  
https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-initialization/
