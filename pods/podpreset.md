# Pod Preset

本文提供了 PodPreset 的概述。 在 Pod 创建时，用户可以使用 PodPreset 对象将特定信息注入 Pod 中，这些信息可以包括 secret、 卷、卷挂载和环境变量。

## 理解 Pod Preset
Pod Preset 是一种 API 资源，在 Pod 创建时，用户可以用它将额外的运行时需求信息注入 Pod。 使用标签选择器（label selector）来指定 Pod Preset 所适用的 Pod。

使用 Pod Preset 使得 Pod 模板编写者不必显式地为每个 Pod 设置信息。 这样，使用特定服务的 Pod 模板编写者不需要了解该服务的所有细节。

## PodPreset 如何工作
Kubernetes 提供了准入控制器 (PodPreset)，该控制器被启用时，会将 Pod Preset 应用于接收到的 Pod 创建请求中。 当出现 Pod 创建请求时，系统会执行以下操作：

1. 检索所有可用 `PodPresets` 。
2. 检查 `PodPreset` 的标签选择器与要创建的 Pod 的标签是否匹配。
3. 尝试合并 `PodPreset` 中定义的各种资源，并注入要创建的 `Pod`。
4. 发生错误时抛出事件，该事件记录了 `pod` 信息合并错误，同时在 不注入 `PodPreset` 信息的情况下创建 Pod。
5. 为改动的 Pod spec 添加注解，来表明它被 PodPreset 所修改。 注解形如： `podpreset.admission.kubernetes.io/podpreset-<pod-preset name>": "<resource version>"`。

- 注意： 适当时候，Pod Preset 可以修改 Pod 规范中的以下字段： - .spec.containers 字段 - initContainers 字段 (需要 Kubernetes 1.14.0 或更高版本)。

### 为特定 Pod 禁用 Pod Preset

在一些情况下，用户不希望 Pod 被 Pod Preset 所改动，这时，用户可以在 Pod spec 中添加形如 `podpreset.admission.kubernetes.io/exclude: "true"` 的注解。


## 启用 Pod Preset
为了在集群中使用 Pod Preset，必须确保以下几点：

1. 已启用 API 类型 `settings.k8s.io/v1alpha1/podpreset`。 例如，这可以通过在 API 服务器的 `--runtime-config` 配置项中包含 `settings.k8s.io/v1alpha1=true` 来实现。在 minikube 部署的集群中，启动集群时添加此参数 `--extra-config=apiserver.runtime-config=settings.k8s.io/v1alpha1=true`。
2. 已启用准入控制器 `PodPreset`。 启用的一种方式是在 API 服务器的 `--enable-admission-plugins` 配置项中包含 `PodPreset` 。在 `minikube` 部署的集群中，启动集群时添加以下参数：

```
--extra-config=apiserver.enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,PodPreset
```

3. 已经通过在相应的命名空间中创建 `PodPreset` 对象，定义了 `Pod Preset`。

# 使用 PodPreset 将信息注入 Pods

在 pod 创建时，用户可以使用 podpreset 对象将 secrets、卷挂载和环境变量等信息注入其中。 本文展示了一些 PodPreset 资源使用的示例。 用户可以从理解 Pod Presets 中了解 PodPresets 的整体情况。

## 创建 Pod Preset

### 简单的 Pod Spec 示例

这里是一个简单的示例，展示了如何通过 Pod Preset 修改 Pod spec 。

- podpreset/preset.yaml

```yaml

apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-database
spec:
  selector:
    matchLabels:
      role: frontend
  env:
    - name: DB_PORT
      value: "6379"
  volumeMounts:
    - mountPath: /cache
      name: cache-volume
  volumes:
    - name: cache-volume
      emptyDir: {}
```
创建 PodPreset：

```bash
kubectl apply -f podpreset/preset.yaml
```
检查所创建的 PodPreset：

```bash
kubectl get podpreset
```

新的 PodPreset 会对所有具有标签 `role: frontend` 的 Pods 采取行动。

**用户提交的 pod spec：**

- podpreset/pod.yaml
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: website
  labels:
    app: website
    role: frontend
spec:
  containers:
    - name: website
      image: nginx
      ports:
        - containerPort: 80
```
创建 Pod：

```bash
kubectl create -f podpreset/pod.yaml
```
列举运行中的 Pods：

```bash
kubectl get pods
```

**通过准入控制器后的 Pod 规约：**

- podpreset/merged.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: website
  labels:
    app: website
    role: frontend
  annotations:
    podpreset.admission.kubernetes.io/podpreset-allow-database: "resource version"
spec:
  containers:
    - name: website
      image: nginx
      volumeMounts:
        - mountPath: /cache
          name: cache-volume
      ports:
        - containerPort: 80
      env:
        - name: DB_PORT
          value: "6379"
  volumes:
    - name: cache-volume
      emptyDir: {}
```

要查看如上输出，运行下面的命令：

```bash
kubectl get pod website -o yaml
```

### 带有 ConfigMap 的 Pod Spec 示例

这里的示例展示了如何通过 PodPreset 修改 Pod 规约，PodPreset 中定义了 ConfigMap 作为环境变量取值来源。

**用户提交的 pod spec：**

- podpreset/pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: website
  labels:
    app: website
    role: frontend
spec:
  containers:
    - name: website
      image: nginx
      ports:
        - containerPort: 80
```
用户提交的 ConfigMap：

- podpreset/configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: etcd-env-config
data:
  number_of_members: "1"
  initial_cluster_state: new
  initial_cluster_token: DUMMY_ETCD_INITIAL_CLUSTER_TOKEN
  discovery_token: DUMMY_ETCD_DISCOVERY_TOKEN
  discovery_url: http://etcd_discovery:2379
  etcdctl_peers: http://etcd:2379
  duplicate_key: FROM_CONFIG_MAP
  REPLACE_ME: "a value"
```

**PodPreset 示例：**
-  podpreset/allow-db.yaml

```yaml
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-database
spec:
  selector:
    matchLabels:
      role: frontend
  env:
    - name: DB_PORT
      value: "6379"
    - name: duplicate_key
      value: FROM_ENV
    - name: expansion
      value: $(REPLACE_ME)
  envFrom:
    - configMapRef:
        name: etcd-env-config
  volumeMounts:
    - mountPath: /cache
      name: cache-volume
    - mountPath: /etc/app/config.json
      readOnly: true
      name: secret-volume
  volumes:
    - name: cache-volume
      emptyDir: {}
    - name: secret-volume
      secret:
        secretName: config-details
```

**通过准入控制器后的 Pod spec：**

- podpreset/allow-db-merged.yaml

### 带有 Pod Spec 的 ReplicaSet 示例

以下示例展示了（通过 ReplicaSet 创建 pod 后）只有 pod spec 会被 Pod Preset 所修改。

**用户提交的 ReplicaSet：**

- podpreset/replicaset.yaml

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      role: frontend
    matchExpressions:
      - {key: role, operator: In, values: [frontend]}
  template:
    metadata:
      labels:
        app: guestbook
        role: frontend
    spec:
      containers:
      - name: php-redis
        image: gcr.io/google_samples/gb-frontend:v3
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        env:
          - name: GET_HOSTS_FROM
            value: dns
        ports:
          - containerPort: 80
```

**PodPreset 示例：**

- podpreset/preset.yaml

```yaml
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-database
spec:
  selector:
    matchLabels:
      role: frontend
  env:
    - name: DB_PORT
      value: "6379"
  volumeMounts:
    - mountPath: /cache
      name: cache-volume
  volumes:
    - name: cache-volume
      emptyDir: {}
```
**通过准入控制器后的 Pod spec：**

注意 ReplicaSet spec 没有改变，用户必须检查单独的 pod 来验证 PodPreset 已被应用。

- podpreset/replicaset-merged.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  labels:
    app: guestbook
    role: frontend
  annotations:
    podpreset.admission.kubernetes.io/podpreset-allow-database: "resource version"
spec:
  containers:
  - name: php-redis
    image: gcr.io/google_samples/gb-frontend:v3
    resources:
      requests:
        cpu: 100m
        memory: 100Mi
    volumeMounts:
    - mountPath: /cache
      name: cache-volume
    env:
    - name: GET_HOSTS_FROM
      value: dns
    - name: DB_PORT
      value: "6379"
    ports:
    - containerPort: 80
  volumes:
  - name: cache-volume
    emptyDir: {}
```

### 多 PodPreset 示例
这里的示例展示了如何通过多个 Pod 注入策略修改 Pod spec。

**用户提交的 Pod 规约：**

- podpreset/pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: website
  labels:
    app: website
    role: frontend
spec:
  containers:
    - name: website
      image: nginx
      ports:
        - containerPort: 80
```

**PodPreset 示例：**

- podpreset/preset.yaml

```yaml
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-database
spec:
  selector:
    matchLabels:
      role: frontend
  env:
    - name: DB_PORT
      value: "6379"
  volumeMounts:
    - mountPath: /cache
      name: cache-volume
  volumes:
    - name: cache-volume
      emptyDir: {}
```

**另一个 Pod Preset 示例：**

- podpreset/proxy.yaml

```yaml
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: proxy
spec:
  selector:
    matchLabels:
      role: frontend
  volumeMounts:
    - mountPath: /etc/proxy/configs
      name: proxy-volume
  volumes:
    - name: proxy-volume
      emptyDir: {}
```
**通过准入控制器后的 Pod 规约：**

- podpreset/multi-merged.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: website
  labels:
    app: website
    role: frontend
  annotations:
    podpreset.admission.kubernetes.io/podpreset-allow-database: "resource version"
    podpreset.admission.kubernetes.io/podpreset-proxy: "resource version"
spec:
  containers:
    - name: website
      image: nginx
      volumeMounts:
        - mountPath: /cache
          name: cache-volume
        - mountPath: /etc/proxy/configs
          name: proxy-volume
      ports:
        - containerPort: 80
      env:
        - name: DB_PORT
          value: "6379"
  volumes:
    - name: cache-volume
      emptyDir: {}
    - name: proxy-volume
      emptyDir: {}
```

### 冲突示例

这里的示例展示了 PodPreset 与原 Pod 存在冲突时，Pod spec 不会被修改。

**用户提交的 Pod 规约：**

- podpreset/conflict-pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: website
  labels:
    app: website
    role: frontend
spec:
  containers:
    - name: website
      image: nginx
      volumeMounts:
        - mountPath: /cache
          name: cache-volume
      ports:
        - containerPort: 80
  volumes:
    - name: cache-volume
      emptyDir: {}
```

**PodPreset 示例：**

- podpreset/conflict-preset.yaml

```yaml
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-database
spec:
  selector:
    matchLabels:
      role: frontend
  env:
    - name: DB_PORT
      value: "6379"
  volumeMounts:
    - mountPath: /cache
      name: other-volume
  volumes:
    - name: other-volume
      emptyDir: {}
```
**因存在冲突，通过准入控制器后的 Pod spec 不会改变：**

- podpreset/conflict-pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: website
  labels:
    app: website
    role: frontend
spec:
  containers:
    - name: website
      image: nginx
      volumeMounts:
        - mountPath: /cache
          name: cache-volume
      ports:
        - containerPort: 80
  volumes:
    - name: cache-volume
      emptyDir: {}
```

**如果运行 `kubectl describe...` 用户会看到以下事件：**

```
$ kubectl describe ...
....
Events:
  FirstSeen             LastSeen            Count   From                    SubobjectPath               Reason      Message
  Tue, 07 Feb 2017 16:56:12 -0700   Tue, 07 Feb 2017 16:56:12 -0700 1   {podpreset.admission.kubernetes.io/podpreset-allow-database }    conflict  Conflict on pod preset. Duplicate mountPath /cache.
```

## 删除 Pod Preset

一旦用户不再需要 pod preset，可以使用 kubectl 进行删除：

```bash
kubectl delete podpreset allow-database
```


参考文档：

https://kubernetes.io/docs/concepts/workloads/pods/podpreset/
https://kubernetes.io/docs/tasks/inject-data-application/podpreset/
