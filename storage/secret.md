# Secret
Secret 对象类型用来保存敏感信息，例如密码、OAuth 令牌和 ssh key。 将这些信息放在 secret 中比放在 Pod 的定义或者 容器镜像 中来说更加安全和灵活。 参阅 Secret 设计文档 获取更多详细信息。


```bash
# 创建拉取镜像harbor对应的secret
# kubectl -n 命名空间 create secret docker-registry 名称  --docker-server=harbor地址  --docker-username=harbor用户名 --docker-password=用户名密码 --docker-email=用户名邮箱
kubectl -n default create secret docker-registry registry-key --docker-server=10.10.10.5 --docker-username=admin --docker-password=Harbor12345 --docker-email=admin@admin.com
```

## Secret 概览
Secret 是一种包含少量敏感信息例如密码、token 或 key 的对象。这样的信息可能会被放在 Pod spec 中或者镜像中；将其放在一个 secret 对象中可以更好地控制它的用途，并降低意外暴露的风险。

用户可以创建 secret，同时系统也创建了一些 secret。

要使用 secret，pod 需要引用 secret。Pod 可以用两种方式使用 secret：作为 volume 中的文件被挂载到 pod 中的一个或者多个容器里，或者当 kubelet 为 pod 拉取镜像时使用。

### 内置 secret
#### Service Account 使用 API 凭证自动创建和附加 secret
Kubernetes 自动创建包含访问 API 凭据的 secret，并自动修改您的 pod 以使用此类型的 secret。

如果需要，可以禁用或覆盖自动创建和使用API凭据。但是，如果您需要的只是安全地访问 apiserver，我们推荐这样的工作流程。

参阅 Service Account 文档获取关于 Service Account 如何工作的更多信息。

### 创建您自己的 Secret
#### 使用 kubectl 创建 Secret
假设有些 pod 需要访问数据库。这些 pod 需要使用的用户名和密码在您本地机器的 ./username.txt 和 ./password.txt 文件里。

```yaml
# Create files needed for rest of example.
echo -n 'admin' > ./username.txt
echo -n '1f2d1e2e67df' > ./password.txt
```

kubectl create secret 命令将这些文件打包到一个 Secret 中并在 API server 中创建了一个对象。

```bash
kubectl create secret generic db-user-pass --from-file=./username.txt --from-file=./password.txt
```

secret "db-user-pass" created

> 注意：
特殊字符（例如 $, `\*` 和 ! ）需要转义。 如果您使用的密码具有特殊字符，则需要使用 `\\` 字符对其进行转义。 例如，如果您的实际密码是 `S!B\*d$zDsb` ，则应通过以下方式执行命令： kubectl create secret generic dev-db-secret –from-literal=username=devuser –from-literal=password=`S\!B\\*d\$zDsb` 您无需从文件中转义密码中的特殊字符（ --from-file ）。

您可以这样检查刚创建的 secret：

```
kubectl get secrets
```

```
NAME                  TYPE                                  DATA      AGE
db-user-pass          Opaque                                2         51s
```

```bash
kubectl describe secrets/db-user-pass
```

```
Name:            db-user-pass
Namespace:       default
Labels:          <none>
Annotations:     <none>

Type:            Opaque

Data
====
password.txt:    12 bytes
username.txt:    5 bytes
```

> 注意：
默认情况下，kubectl get和kubectl describe避免显示密码的内容。 这是为了防止机密被意外地暴露给旁观者或存储在终端日志中。

#### 手动创建 Secret
您也可以先以 json 或 yaml 格式在文件中创建一个 secret 对象，然后创建该对象。 密码包含两中类型，数据和字符串数据。 数据字段用于存储使用base64编码的任意数据。 提供stringData字段是为了方便起见，它允许您将机密数据作为未编码的字符串提供。

例如，要使用数据字段将两个字符串存储在 Secret 中，请按如下所示将它们转换为 base64：

```bash
echo -n 'admin' | base64
YWRtaW4=
echo -n '1f2d1e2e67df' | base64
MWYyZDFlMmU2N2Rm
```

现在可以像这样写一个 secret 对象：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: YWRtaW4=
  password: MWYyZDFlMmU2N2Rm
```

使用 kubectl apply 创建 secret

```bash
kubectl apply -f ./secret.yaml
```

```
secret "mysecret" created
```

对于某些情况，您可能希望改用 stringData 字段。 此字段允许您将非 base64 编码的字符串直接放入 Secret 中， 并且在创建或更新 Secret 时将为您编码该字符串。

下面的一个实践示例提供了一个参考，您正在部署使用密钥存储配置文件的应用程序，并希望在部署过程中填补齐配置文件的部分内容。

如果您的应用程序使用以下配置文件：

```yaml
apiUrl: "https://my.api.com/api/v1"
username: "user"
password: "password"
```
您可以使用以下方法将其存储在Secret中：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  config.yaml: |-
    apiUrl: "https://my.api.com/api/v1"
    username: {{username}}
    password: {{password}}
```

然后，您的部署工具可以在执行 kubectl apply 之前替换模板的 {{username}} 和 {{password}} 变量。 stringData 是只写的便利字段。 检索 Secrets 时永远不会被输出。 例如，如果您运行以下命令：

```
kubectl get secret mysecret -o yaml
```

输出将类似于：

```yaml
apiVersion: v1
kind: Secret
metadata:
  creationTimestamp: 2018-11-15T20:40:59Z
  name: mysecret
  namespace: default
  resourceVersion: "7225"
  uid: c280ad2e-e916-11e8-98f2-025000000001
type: Opaque
data:
  config.yaml: YXBpVXJsOiAiaHR0cHM6Ly9teS5hcGkuY29tL2FwaS92MSIKdXNlcm5hbWU6IHt7dXNlcm5hbWV9fQpwYXNzd29yZDoge3twYXNzd29yZH19
```

如果在 data 和 stringData 中都指定了字段，则使用 stringData 中的值。 例如，以下是 Secret 定义：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: YWRtaW4=
stringData:
  username: administrator
```

secret 中的生成结果：

```yaml
apiVersion: v1
kind: Secret
metadata:
  creationTimestamp: 2018-11-15T20:46:46Z
  name: mysecret
  namespace: default
  resourceVersion: "7579"
  uid: 91460ecb-e917-11e8-98f2-025000000001
type: Opaque
data:
  username: YWRtaW5pc3RyYXRvcg==
```

YWRtaW5pc3RyYXRvcg== 转换成了 administrator。

data和stringData的键必须由字母数字字符 ‘-’, ‘\_’ 或者 ‘.’ 组成。

**编码注意：** 秘密数据的序列化 JSON 和 YAML 值被编码为base64字符串。 换行符在这些字符串中无效，因此必须省略。 在 Darwin / macOS 上使用 base64 实用程序时，用户应避免使用 -b 选项来分隔长行。 相反，Linux用户 应该 在 base64 命令中添加选项 -w 0， 或者，如果-w选项不可用的情况下， 执行 base64 | tr -d '\\n'。

#### 从生成器创建 Secret

Kubectl 从1.14版本开始支持 使用 [Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) 管理对象 使用此新功能，您还可以从生成器创建一个 Secret，然后将其应用于在 Apiserver 上创建对象。 生成器应在目录内的“ kustomization.yaml”中指定。

例如，从文件 ./username.txt 和 ./password.txt 生成一个 Secret。

```bash
# Create a kustomization.yaml file with SecretGenerator
cat <<EOF >./kustomization.yaml
secretGenerator:
- name: db-user-pass
  files:
  - username.txt
  - password.txt
EOF
```
应用 kustomization 目录创建 Secret 对象。

```
$ kubectl apply -k .
secret/db-user-pass-96mffmfh4k created
```

您可以检查 secret 是否是这样创建的：

```
$ kubectl get secrets
NAME                             TYPE                                  DATA      AGE
db-user-pass-96mffmfh4k          Opaque                                2         51s

$ kubectl describe secrets/db-user-pass-96mffmfh4k
Name:            db-user-pass
Namespace:       default
Labels:          <none>
Annotations:     <none>

Type:            Opaque

Data
====
password.txt:    12 bytes
username.txt:    5 bytes
```

例如，要从文字 username=admin 和 password=secret 生成秘密，可以在 kustomization.yaml 中将秘密生成器指定为

```
# Create a kustomization.yaml file with SecretGenerator
$ cat <<EOF >./kustomization.yaml
secretGenerator:
- name: db-user-pass
  literals:
  - username=admin
  - password=secret
EOF
```

应用kustomization目录创建Secret对象。

```
$ kubectl apply -k .
secret/db-user-pass-dddghtt9b5 created
```

> 注意：
通过对内容进行序列化后，生成一个后缀作为 Secrets 的名称。 这样可以确保每次修改内容时都会生成一个新的Secret。

#### 解码 Secret
可以使用 kubectl get secret 命令获取 secret。例如，获取在上一节中创建的 secret：

```bash
kubectl get secret mysecret -o yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  creationTimestamp: 2016-01-22T18:41:56Z
  name: mysecret
  namespace: default
  resourceVersion: "164619"
  uid: cfee02d6-c137-11e5-8d73-42010af00002
type: Opaque
data:
  username: YWRtaW4=
  password: MWYyZDFlMmU2N2Rm
```

解码密码字段：

```bash
echo 'MWYyZDFlMmU2N2Rm' | base64 --decode
```

```
1f2d1e2e67df
```

#### 编辑 Secret
可以通过下面的命令编辑一个已经存在的 secret 。

```bash
kubectl edit secrets mysecret
```

这将打开默认配置的编辑器，并允许更新 data 字段中的base64编码的 secret：

```yaml
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
data:
  username: YWRtaW4=
  password: MWYyZDFlMmU2N2Rm
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: { ... }
  creationTimestamp: 2016-01-22T18:41:56Z
  name: mysecret
  namespace: default
  resourceVersion: "164619"
  uid: cfee02d6-c137-11e5-8d73-42010af00002
type: Opaque
```
