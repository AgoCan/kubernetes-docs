# Deployments

一个 Deployment 控制器为 Pods和 ReplicaSets提供描述性的更新方式。

描述 Deployment 中的 \_desired state\_，并且 Deployment 控制器以受控速率更改实际状态，以达到期望状态。可以定义 Deployments 以创建新的 ReplicaSets ，或删除现有 Deployments ，并通过新的 Deployments 使用其所有资源。

- 注意：不要管理 Deployment 拥有的 ReplicaSets 。如果存在下面未介绍的用例，请考虑在主 Kubernetes 仓库中提出 issue。

## 用例

以下是典型的 Deployments 用例：

- 创建 Deployment 以展开 ReplicaSet 。 ReplicaSet 在后台创建 Pods。检查 ReplicaSet 展开的状态，查看其是否成功。
- 声明 Pod 的新状态 通过更新 Deployment 的 PodTemplateSpec。将创建新的 ReplicaSet ，并且 Deployment 管理器以受控速率将 Pod 从旧 ReplicaSet 移动到新 ReplicaSet 。每个新的 ReplicaSet 都会更新 Deployment 的修改历史。
- 回滚到较早的 Deployment 版本，如果 Deployment 的当前状态不稳定。每次回滚都会更新 Deployment 的修改。
- 扩展 Deployment 以承担更多负载.
- 暂停 Deployment 对其 PodTemplateSpec 进行修改，然后恢复它以启动新的展开。
- 使用 Deployment 状态 作为卡住展开的指示器。
- 清理较旧的 ReplicaSets ，那些不在需要的。

## 创建 Deployment

下面是 Deployment 示例。创建一个 ReplicaSet 展开三个 nginx Pods：

`controllers/nginx-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.15.4
        ports:
        - containerPort: 80
```

在该例中：

- 将创建名为 nginx-deployment 的 Deployment ，由 .metadata.name 字段指示。
- Deployment 创建三个复制的 Pods，由 replicas 字段指示。
- selector 字段定义 Deployment 如何查找要管理的 Pods。 在这种情况下，只需选择在 Pod 模板（app: nginx）中定义的标签。但是，更复杂的选择规则是可能的，只要 Pod 模板本身满足规则。

  - 注意：`matchLabels` 字段是 {key,value} 的映射。单个 {key,value}在 `matchLabels` 映射中的值等效于 `matchExpressions` 的元素，其键字段是“key”，运算符为“In”，值数组仅包含“value”。所有要求，从 `matchLabels` 和 `matchExpressions`，必须满足才能匹配。

- template 字段包含以下子字段：
- Pod 标记为app: nginx，使用labels字段。
- Pod 模板规范或 .template.spec 字段指示 Pods 运行一个容器， nginx，运行 nginx Docker Hub版本1.7.9的镜像 。
- 创建一个容器并使用name字段将其命名为 nginx。


按照以下步骤创建上述 Deployment ：

开始之前，请确保的 Kubernetes 集群已启动并运行。

1. 通过运行以下命令创建 Deployment ：

  - 注意：  可以指定 `--record` 标志来写入在资源注释`kubernetes.io/change-cause`中执行的命令。它对以后的检查是有用的。  例如，查看在每个 Deployment 修改中执行的命令。

  ```bash
  kubectl apply -f controllers/nginx-deployment.yaml
  ```

2. 运行 kubectl get deployments 以检查 Deployment 是否已创建。如果仍在创建 Deployment ，则输出以下内容：

  ```
  NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
  nginx-deployment   3         0         0            0           1s
  ```

  检查集群中的 Deployments 时，将显示以下字段：

  * `NAME` 列出了集群中 Deployments 的名称。
  * `DESIRED` 显示应用程序的所需 _副本_ 数，在创建 Deployment 时定义这些副本。这是 _期望状态_。
  * `CURRENT`显示当前正在运行的副本数。
  * `UP-TO-DATE`显示已更新以实现期望状态的副本数。
  * `AVAILABLE`显示应用程序可供用户使用的副本数。
  * `AGE` 显示应用程序运行的时间量。

  请注意，根据`.spec.replicas`副本字段，所需副本的数量为 3。

3. 要查看 Deployment 展开状态，运行 kubectl rollout status deployment.v1.apps/nginx-deployment。输出：

  ```bash
  Waiting for rollout to finish: 2 out of 3 new replicas have been updated...
  deployment.apps/nginx-deployment successfully rolled out
  ```

4. 几秒钟后再次运行 kubectl get deployments。输出：

  ```
  NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
  nginx-deployment   3         3         3            3           18s
  ```
  请注意， Deployment 已创建所有三个副本，并且所有副本都是最新的（它们包含最新的 Pod 模板）并且可用。

5. 要查看 Deployment 创建的 ReplicaSet （rs），运行 kubectl get rs。输出：

  ```
  NAME                          DESIRED   CURRENT   READY   AGE
  nginx-deployment-75675f5897   3         3         3       18s
  ```

  请注意， ReplicaSet 的名称始终被格式化为`[DEPLOYMENT-NAME]-[RANDOM-STRING]`。随机字符串是随机生成并使用 pod-template-hash 作为种子。

6. 要查看每个 Pod 自动生成的标签，运行 kubectl get pods --show-labels。返回以下输出：

  ```
  NAME                                READY     STATUS    RESTARTS   AGE       LABELS
  nginx-deployment-75675f5897-7ci7o   1/1       Running   0          18s       app=nginx,pod-template-hash=3123191453
  nginx-deployment-75675f5897-kzszj   1/1       Running   0          18s       app=nginx,pod-template-hash=3123191453
  nginx-deployment-75675f5897-qqcnn   1/1       Running   0          18s       app=nginx,pod-template-hash=3123191453
  ```

  创建的复制集可确保有三个 `nginx` Pods。

  - 注意： 必须在 Deployment 中指定适当的选择器和 Pod 模板标签（在本例中为app: nginx）。不要与其他控制器（包括其他 Deployments 和状态设置）重叠标签或选择器。Kubernetes 不会阻止重叠，如果多个控制器具有重叠的选择器，这些控制器可能会冲突并运行意外。


### Pod-template-hash 标签
- 注意： 不要更改此标签。

Deployment 控制器将 pod-template-hash 标签添加到 Deployment 创建或使用的每个 ReplicaSet 。

此标签可确保 Deployment 的子 ReplicaSets 不重叠。它通过对 ReplicaSet 的 PodTemplate 进行哈希处理，并使用生成的哈希值添加到 ReplicaSet 选择器、Pod 模板标签,并在 ReplicaSet 可能具有的任何现有 Pod 中。


### 更新 Deployment

未完待续...

https://kubernetes.io/docs/concepts/workloads/controllers/deployment/  
