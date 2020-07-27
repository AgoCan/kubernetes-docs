# 使用 ConfigMap 配置 Pod

ConfigMap 允许您将配置文件与镜像文件分离，以使容器化的应用程序具有可移植性。该页面提供了一系列使用示例，这些示例演示了如何使用存储在 ConfigMap 中的数据创建 ConfigMap 和配置 Pod。

## 准备开始
你必须拥有一个 Kubernetes 的集群，同时你的 Kubernetes 集群必须带有 kubectl 命令行工具。

## 创建 ConfigMap

您可以在 `kustomization.yaml` 中使用 `kubectl create configmap` 或 `ConfigMap` 生成器来创建`ConfigMap`。注意，从 1.14 版本开始， `kubectl` 开始支持 `kustomization.yaml`。

### 使用 kubectl 创建 ConfigMap
在目录, 文件, 或者文字值中使用 kubectl create configmap 命令创建configmap：

```bash
kubectl create configmap <map-name> <data-source>
```

其中， <map-name> 是要分配给 ConfigMap 的名称，<data-source> 是要从中提取数据的目录，文件或者文字值。

数据源对应于 ConfigMap 中的 key-value (键值对)

- key = 您在命令行上提供的文件名或者密钥
- value = 您在命令行上提供的文件内容或者文字值

您可以使用kubectl describe或者 kubectl get检索有关 ConfigMap 的信息。

#### 根据目录创建 ConfigMap
你可以使用 kubectl create configmap 从同一目录中的多个文件创建 ConfigMap。

例如：

```bash
# 创建本地目录
mkdir -p configure-pod-container/configmap/

# 将样本文件下载到 `configure-pod-container/configmap/` 目录
wget https://kubernetes.io/examples/configmap/game.properties -O configure-pod-container/configmap/game.properties
wget https://kubernetes.io/examples/configmap/ui.properties -O configure-pod-container/configmap/ui.properties

# 创建 configmap
kubectl create c game-config --from-file=configure-pod-container/configmap/
```
合并 configure-pod-container/configmap/ 目录的内容

```
game.properties
ui.properties
```

进入以下 ConfigMap 中：

```bash
kubectl describe configmaps game-config
```

输出类似以下内容：

```
Name:           game-config
Namespace:      default
Labels:         <none>
Annotations:    <none>

Data
====
game.properties:        158 bytes
ui.properties:          83 bytes
```

`configure-pod-container/configmap/` 目录中的 `game.properties` 和 `ui.properties` 文件在 `ConfigMap` 的 data 部分中表示。

```bash
kubectl get configmaps game-config -o yaml
```

输出类似以下内容:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: 2016-02-18T18:52:05Z
  name: game-config
  namespace: default
  resourceVersion: "516"
  selfLink: /api/v1/namespaces/default/configmaps/game-config
  uid: b4952dc3-d670-11e5-8cd0-68f728db1985
data:
  game.properties: |
    enemies=aliens
    lives=3
    enemies.cheat=true
    enemies.cheat.level=noGoodRotten
    secret.code.passphrase=UUDDLRLRBABAS
    secret.code.allowed=true
    secret.code.lives=30
  ui.properties: |
    color.good=purple
    color.bad=yellow
    allow.textmode=true
    how.nice.to.look=fairlyNice
```

#### 根据文件创建 ConfigMap

您可以使用 kubectl create configmap 从单个文件或多个文件创建 ConfigMap。

例如

```bash
kubectl create configmap game-config-2 --from-file=configure-pod-container/configmap/game.properties
```
将产生以下 ConfigMap:

```
kubectl describe configmaps game-config-2
```

输出类似以下内容:

```
Name:           game-config-2
Namespace:      default
Labels:         <none>
Annotations:    <none>

Data
====
game.properties:        158 bytes
```

您可以传入多个 --from-file 参数，从多个数据源创建 ConfigMap。

```bash
kubectl create configmap game-config-2 --from-file=configure-pod-container/configmap/game.properties --from-file=configure-pod-container/configmap/ui.properties
```

描述上面创建的 game-config-2 configmap

```bash
kubectl describe configmaps game-config-2
```

输出类似以下内容:

```
Name:           game-config-2
Namespace:      default
Labels:         <none>
Annotations:    <none>

Data
====
game.properties:        158 bytes
ui.properties:          83 bytes
```

使用 --from-env-file 选项从环境文件创建 ConfigMap，例如：

```bash
# 环境文件包含环境变量列表。
# 语法规则:
#   env 文件中的每一行必须为 VAR = VAL 格式。
#   以＃开头的行(即注释)将被忽略。
#   空行将被忽略。
#   引号没有特殊处理(即它们将成为 ConfigMap 值的一部分)。

# 将样本文件下载到 `configure-pod-container/configmap/` 目录
wget https://kubernetes.io/examples/configmap/game-env-file.properties -O configure-pod-container/configmap/game-env-file.properties

# env文件 `game-env-file.properties` 如下所示
cat configure-pod-container/configmap/game-env-file.properties
enemies=aliens
lives=3
allowed="true"

# 注释及其上方的空行将被忽略
```

```bash
kubectl create configmap game-config-env-file \
       --from-env-file=configure-pod-container/configmap/game-env-file.properties
```
将产生以下 ConfigMap:

```bash
kubectl get configmap game-config-env-file -o yaml
```

输出类似以下内容:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: 2017-12-27T18:36:28Z
  name: game-config-env-file
  namespace: default
  resourceVersion: "809965"
  selfLink: /api/v1/namespaces/default/configmaps/game-config-env-file
  uid: d9d1ca5b-eb34-11e7-887b-42010a8002b8
data:
  allowed: '"true"'
  enemies: aliens
  lives: "3"
```
当使用多个 --from-env-file 来从多个数据源创建 ConfigMap 时，仅仅最后一个 env 文件有效:

```bash
# 将样本文件下载到 `configure-pod-container/configmap/` 目录
wget https://k8s.io/examples/configmap/ui-env-file.properties -O configure-pod-container/configmap/ui-env-file.properties

# 创建 configmap
kubectl create configmap config-multi-env-files \
        --from-env-file=configure-pod-container/configmap/game-env-file.properties \
        --from-env-file=configure-pod-container/configmap/ui-env-file.properties
```

将产生以下 ConfigMap:

```bash
kubectl get configmap config-multi-env-files -o yaml
```

输出类似以下内容:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: 2017-12-27T18:38:34Z
  name: config-multi-env-files
  namespace: default
  resourceVersion: "810136"
  selfLink: /api/v1/namespaces/default/configmaps/config-multi-env-files
  uid: 252c4572-eb35-11e7-887b-42010a8002b8
data:
  color: purple
  how: fairlyNice
  textmode: "true"
```
定义从文件创建 ConfigMap 时要使用的密钥

您可以在使用 --from-file 参数时,在 ConfigMap 的 data 部分中定义除文件名以外的其他键:

```bash
kubectl create configmap game-config-3 --from-file=<my-key-name>=<path-to-file>
```

<my-key-name> 是您要在 ConfigMap 中使用的密钥， <path-to-file> 是您想要键表示数据源文件的位置。

例如:

```bash
kubectl create configmap game-config-3 --from-file=game-special-key=configure-pod-container/configmap/game.properties
```
将产生以下 ConfigMap:

```bash
kubectl get configmaps game-config-3 -o yaml
```
输出类似以下内容:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: 2016-02-18T18:54:22Z
  name: game-config-3
  namespace: default
  resourceVersion: "530"
  selfLink: /api/v1/namespaces/default/configmaps/game-config-3
  uid: 05f8da22-d671-11e5-8cd0-68f728db1985
data:
  game-special-key: |
    enemies=aliens
    lives=3
    enemies.cheat=true
    enemies.cheat.level=noGoodRotten
    secret.code.passphrase=UUDDLRLRBABAS
    secret.code.allowed=true
    secret.code.lives=30
```

#### 根据文字值创建 ConfigMap
您可以将 kubectl create configmap 与 --from-literal 参数一起使用，从命令行定义文字值:

```bash
kubectl create configmap special-config --from-literal=special.how=very --from-literal=special.type=charm
```

您可以传入多个键值对。命令行中提供的每对在 ConfigMap 的 data 部分中均表示为单独的条目。

```bash
kubectl get configmaps special-config -o yaml
```

输出类似以下内容:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: 2016-02-18T19:14:38Z
  name: special-config
  namespace: default
  resourceVersion: "651"
  selfLink: /api/v1/namespaces/default/configmaps/special-config
  uid: dadce046-d673-11e5-8cd0-68f728db1985
data:
  special.how: very
  special.type: charm
```

#### 根据生成器创建 ConfigMap
自 1.14 开始， kubectl 开始支持 kustomization.yaml。 您还可以从生成器创建 ConfigMap，然后将其应用于 Apiserver 创建对象。生成器应在目录内的 kustomization.yaml 中指定。

#### 根据文件生成 ConfigMap
例如，要从 configure-pod-container/configmap/kubectl/game.properties 文件生成一个 ConfigMap

```yaml
# 使用 ConfigMapGenerator 创建 kustomization.yaml 文件
cat <<EOF >./kustomization.yaml
configMapGenerator:
- name: game-config-4
  files:
  - configure-pod-container/configmap/kubectl/game.properties
EOF
```

使用 kustomization 目录创建 ConfigMap 对象

```bash
kubectl apply -k .
configmap/game-config-4-m9dm2f92bt created
```

您可以检查 ConfigMap 是这样创建的:

```
kubectl get configmap
NAME                       DATA   AGE
game-config-4-m9dm2f92bt   1      37s


kubectl describe configmaps/game-config-4-m9dm2f92bt
Name:         game-config-4-m9dm2f92bt
Namespace:    default
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"v1","data":{"game.properties":"enemies=aliens\nlives=3\nenemies.cheat=true\nenemies.cheat.level=noGoodRotten\nsecret.code.p...

Data
====
game.properties:
----
enemies=aliens
lives=3
enemies.cheat=true
enemies.cheat.level=noGoodRotten
secret.code.passphrase=UUDDLRLRBABAS
secret.code.allowed=true
secret.code.lives=30
Events:  <none>
```

请注意，生成的 ConfigMap 名称具有通过对内容进行散列而附加的后缀，这样可以确保每次修改内容时都会生成新的 ConfigMap。

#### 定义从文件生成 ConfigMap 时要使用的密钥

您可以定义一个非文件名的键，在 ConfigMap 生成器中使用。例如，使用 game-special-key 从 configure-pod-container / configmap / kubectl / game.properties 文件生成 ConfigMap。

```bash
# 使用 ConfigMapGenerator 创建 kustomization.yaml 文件
cat <<EOF >./kustomization.yaml
configMapGenerator:
- name: game-config-5
  files:
  - game-special-key=configure-pod-container/configmap/kubectl/game.properties
EOF
```

使用 Kustomization 目录创建 ConfigMap 对象。

```
kubectl apply -k .
configmap/game-config-5-m67dt67794 created
```
#### 从文字值生成 ConfigMap
要从文字 special.type=charm 和 special.how=very 生成 ConfigMap，可以在 kusotmization.yaml 中将 ConfigMap 生成器指定。

```bash
# 使用 ConfigMapGenerator 创建 kustomization.yaml 文件
cat <<EOF >./kustomization.yaml
configMapGenerator:
- name: special-config-2
  literals:
  - special.how=very
  - special.type=charm
EOF
```
使用 Kustomization 目录创建 ConfigMap 对象。

```
kubectl apply -k .
configmap/special-config-2-c92b5mmcf2 created
```

## 使用 ConfigMap 数据定义容器环境变量

### 使用单个 ConfigMap 中的数据定义容器环境变量

1. 在 ConfigMap 中将环境变量定义为键值对:

  ```bash
  kubectl create configmap special-config --from-literal=special.how=very
  ```

2. 将 ConfigMap 中定义的 special.how 值分配给 Pod 规范中的 SPECIAL_LEVEL_KEY 环境变量。
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: dapi-test-pod
  spec:
    containers:
      - name: test-container
        image: k8s.gcr.io/busybox
        command: [ "/bin/sh", "-c", "env" ]
        env:
          # Define the environment variable
          - name: SPECIAL_LEVEL_KEY
            valueFrom:
              configMapKeyRef:
                # The ConfigMap containing the value you want to assign to SPECIAL_LEVEL_KEY
                name: special-config
                # Specify the key associated with the value
                key: special.how
    restartPolicy: Never
  ```

创建 Pod:

```bash
kubectl create -f https://kubernetes.io/examples/pods/pod-single-configmap-env-variable.yaml
```
现在，Pod 的输出包含环境变量 SPECIAL_LEVEL_KEY=very。

### 使用来自多个 ConfigMap 的数据定义容器环境变量

- 与前面的示例一样，首先创建 ConfigMap。

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: special-config
  namespace: default
data:
  special.how: very
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: env-config
  namespace: default
data:
  log_level: INFO
```

创建 ConfigMap:

```bash
kubectl create -f https://kubernetes.io/examples/configmap/configmaps.yaml
```

- 在 Pod 规范中定义环境变量。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: k8s.gcr.io/busybox
      command: [ "/bin/sh", "-c", "env" ]
      env:
        - name: SPECIAL_LEVEL_KEY
          valueFrom:
            configMapKeyRef:
              name: special-config
              key: special.how
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: env-config
              key: log_level
  restartPolicy: Never
```

创建 Pod:

```bash
kubectl create -f https://kubernetes.io/examples/pods/pod-multiple-configmap-env-variable.yaml
```

现在，Pod 的输出包含环境变量 SPECIAL_LEVEL_KEY=very 和 LOG_LEVEL=INFO。

## 将 ConfigMap 中的所有键值对配置为容器环境变量
> 注意：
Kubernetes v1.6 和更高版本提供了此功能。

- 创建一个包含多个键值对的 ConfigMap。

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: special-config
  namespace: default
data:
  SPECIAL_LEVEL: very
  SPECIAL_TYPE: charm
```

创建 ConfigMap:

```bash
kubectl create -f https://kubernetes.io/examples/configmap/configmap-multikeys.yaml
```

- 使用 envFrom 将所有 ConfigMap 的数据定义为容器环境变量，ConfigMap 中的键成为 Pod 中的环境变量名称。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: k8s.gcr.io/busybox
      command: [ "/bin/sh", "-c", "env" ]
      envFrom:
      - configMapRef:
          name: special-config
  restartPolicy: Never
```

创建 Pod:

```bash
kubectl create -f https://kubernetes.io/examples/pods/pod-configmap-envFrom.yaml
```

现在，Pod 的输出包含环境变量 SPECIAL_LEVEL=very 和 SPECIAL_TYPE=charm。


## 在 Pod 命令中使用 ConfigMap 定义的环境变量

您可以使用 $(VAR_NAME) Kubernetes 替换语法在 Pod 规范的 command 部分中使用 ConfigMap 定义的环境变量。

例如，以下 Pod 规范

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: k8s.gcr.io/busybox
      command: [ "/bin/sh", "-c", "echo $(SPECIAL_LEVEL_KEY) $(SPECIAL_TYPE_KEY)" ]
      env:
        - name: SPECIAL_LEVEL_KEY
          valueFrom:
            configMapKeyRef:
              name: special-config
              key: SPECIAL_LEVEL
        - name: SPECIAL_TYPE_KEY
          valueFrom:
            configMapKeyRef:
              name: special-config
              key: SPECIAL_TYPE
  restartPolicy: Never
```

通过运行创建

```bash
kubectl create -f https://kubernetes.io/examples/pods/pod-configmap-env-var-valueFrom.yaml
```

在 test-container 容器中产生以下输出:

```
very charm
```

## 将 ConfigMap 数据添加到一个容器中

如根据文件创建ConfigMap中所述，当您使用 --from-file 创建 ConfigMap 时，文件名成为存储在 ConfigMap 的 data 部分中的密钥，文件内容成为密钥的值。

本节中的示例引用了一个名为 special-config 的 ConfigMap，如下所示：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: special-config
  namespace: default
data:
  SPECIAL_LEVEL: very
  SPECIAL_TYPE: charm
```

创建 ConfigMap:

```bash
kubectl create -f https://kubernetes.io/examples/configmap/configmap-multikeys.yaml
```

### 使用存储在 ConfigMap 中的数据填充容器
在 Pod 规范的 volumes 部分下添加 ConfigMap 名称。 这会将 ConfigMap 数据添加到指定为 volumeMounts.mountPath 的目录(在本例中为/etc/config)。 command 引用存储在 ConfigMap 中的 special.level。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: k8s.gcr.io/busybox
      command: [ "/bin/sh", "-c", "ls /etc/config/" ]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config
  volumes:
    - name: config-volume
      configMap:
        # Provide the name of the ConfigMap containing the files you want
        # to add to the container
        name: special-config
  restartPolicy: Never
```

创建Pod:

```bash
kubectl create -f https://kubernetes.io/examples/pods/pod-configmap-volume.yaml
```

运行命令 ls /etc/config/ 产生下面的输出:

```
SPECIAL_LEVEL
SPECIAL_TYPE
```

> 警告:
如果在 /etc/config/ 目录中有一些文件，它们将被删除。

### 将 ConfigMap 数据添加到容器中的特定路径
使用 path 字段为特定的 ConfigMap 项目指定所需的文件路径。 在这种情况下, SPECIAL_LEVEL 将安装在 /etc/config/keys 目录下的 config-volume 容器中。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-test-pod
spec:
  containers:
    - name: test-container
      image: k8s.gcr.io/busybox
      command: [ "/bin/sh","-c","cat /etc/config/keys" ]
      volumeMounts:
      - name: config-volume
        mountPath: /etc/config
  volumes:
    - name: config-volume
      configMap:
        name: special-config
        items:
        - key: SPECIAL_LEVEL
          path: keys
  restartPolicy: Never
```

创建Pod:

```bash
kubectl create -f https://kubernetes.io/examples/pods/pod-configmap-volume-specific-key.yaml
```

当 pod 运行时，命令 cat /etc/config/keys 产生以下输出:

```
very
```

> 警告:
和以前一样，/etc/config/ 目录中的所有先前文件都将被删除。

### 项目密钥以指定路径和文件权限
您可以将密钥映射到每个文件的特定路径和特定权限。Secrets 用户指南说明了语法。

### 挂载的 ConfigMap 将自动更新
更新已经在容器中使用的 ConfigMap 时，最终也会更新映射键。Kubelet 实时检查是否在每个定期同步中都更新已安装的 ConfigMap。它使用其基于本地 ttl 的缓存来获取 ConfigMap 的当前值。结果，从更新 ConfigMap 到将新密钥映射到 Pod 的总延迟可以与 ConfigMap 在 kubelet 中缓存的 kubelet 同步周期 ttl 一样长。

> 注意：
使用 ConfigMap 作为子路径subPath的容器将不会收到 ConfigMap 更新。

## 了解 ConfigMap 和 Pod

ConfigMap API 资源将配置数据存储为键值对。数据可以在 Pod 中使用，也可以提供系统组件(如控制器)的配置。ConfigMap 与 Secrets类似，但是提供了一种使用不包含敏感信息的字符串的方法。用户和系统组件都可以在 ConfigMap 中存储配置数据。

> 注意：
ConfigMap 应该引用属性文件，而不是替换它们。可以将 ConfigMap 表示为类似于 Linux /etc 目录及其内容的东西。例如，如果您从 ConfigMap 创建Kubernetes Volume，则 ConfigMap 中的每个数据项都由该容器中的单个文件表示。

ConfigMap 的 data 字段包含配置数据。如下例所示，它可以很简单 – 就像使用 --from-literal – 定义的单个属性一样，也可以很复杂 – 例如使用 --from-file 定义的配置文件或 JSON blob。

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: 2016-02-18T19:14:38Z
  name: example-config
  namespace: default
data:
  # example of a simple property defined using --from-literal
  example.property.1: hello
  example.property.2: world
  # example of a complex property defined using --from-file
  example.property.file: |-
    property.1=value-1
    property.2=value-2
    property.3=value-3
```

### 限制规定
- 在 Pod 规范中引用它之前，必须先创建一个 ConfigMap(除非将 ConfigMap 标记为”可选”)。如果引用的 ConfigMap 不存在，则 Pod 将不会启动。同样，对 ConfigMap 中不存在的键的引用将阻止容器启动。
- 如果您使用 envFrom 从 ConfigMap 中定义环境变量，那么将忽略被认为无效的键。可以启动 Pod，但无效名称将记录在事件日志中(InvalidVariableNames)。日志消息列出了每个跳过的键。例如:

```
kubectl get events
```

输出与此类似:

```
LASTSEEN FIRSTSEEN COUNT NAME          KIND  SUBOBJECT  TYPE      REASON                            SOURCE                MESSAGE
  0s       0s        1     dapi-test-pod Pod              Warning   InvalidEnvironmentVariableNames   {kubelet, 127.0.0.1}  Keys [1badkey, 2alsobad] from the EnvFrom configMap default/myconfig were skipped since they are considered invalid environment variable names.
```

- ConfigMap 驻留在特定的命令空间中。ConfigMap 只能由位于相同命令空间中的 Pod 引用。
- Kubelet 不支持将 ConfigMap 用于未在 API 服务器上找到的 Pod。这包括通过 Kubelet 的 --manifest-url 参数，--config 参数或者 Kubelet REST API 创建的容器。

> 注意：
这些不是创建 pods 的常用方法。




参考文档：

https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/
