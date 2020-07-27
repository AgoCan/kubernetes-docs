# 使用RBAC授权
基于角色的访问控制（RBAC）是一种基于企业内各个用户的角色来调节对计算机或网络资源的访问的方法。

RBAC使用rbac.authorization.k8s.io API组 驱动授权决策，从而允许管理员通过Kubernetes API动态配置策略。

从1.8开始，RBAC模式是稳定的，并由`rbac.authorization.k8s.io/v1` API支持。

要启用RBAC，请通过启动`apiserver --authorization-mode=RBAC`。


## API概述
RBAC API声明了四个顶级类型，本节将进行介绍。用户可以与这些资源进行交互，就像与其他任何API资源（通过kubectl，API调用等）进行交互一样。例如， `kubectl apply -f (resource).yml`可以与这些示例中的任何一个一起使用，尽管希望继续阅读的读者应首先阅读有关引导的部分。

### Role(角色)和ClusterRole
在RBAC API中，角色包含代表一组权限的规则。权限纯粹是累加的（没有“拒绝”规则）。可以在名称空间中用`Role`或在群集范围内用定义角色`ClusterRole`。

A Role只能用于授予对单个名称空间内资源的访问权限。这是Role“默认”名称空间中的示例，可用于授予对pod的读取访问权限：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

ClusterRole可以使用A 授予与相同的权限Role，但是由于它们是集群范围的，因此它们还可以用于授予以下权限：

- 集群范围内的资源（如节点）
- 非资源端点（例如“ / healthz”）
- 所有命名空间中的命名空间资源（例如pod）（`kubectl get pods --all-namespaces`例如，需要运行）

以下内容ClusterRole可用于授予对任何特定名称空间或所有名称空间中的secret的读取访问权限（取决于其绑定方式）：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  # "namespace" omitted since ClusterRoles are not namespaced
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
```

### RoleBinding和ClusterRoleBinding

角色绑定向用户或一组用户授予在角色中定义的权限。它包含主题（用户，组或服务帐户）的列表，以及对所授予角色的引用。可以在名称空间内使用`RoleBinding`或在群集范围内使用授予权限`ClusterRoleBinding`。

A `RoleBinding`可以`Role`在同一名称空间中引用a 。以下`RoleBinding`将“ `pod-reader`”角色授予“默认”名称空间中的用户“ `jane`”。这允许“ `jane`”读取“default”名称空间中的pod。

`roleRef`这是您实际创建绑定的方式。该`kind`会无论是`Role`或`ClusterRole`，并且name将引用具体的名字`Role`或`ClusterRole`你想要的。在下面的示例中，此`RoleBinding roleRef`用于将用户“ jane”绑定到Role上面创建的named pod-reader。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
# This role binding allows "jane" to read pods in the "default" namespace.
# 这个RoleBinding允许用户 jane 访问 default 名称空间下的pods
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: jane # 名称区分大小写
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role # 这里必须是 Role 或者 ClusterRole
  name: pod-reader # 该名称必须与您希望绑定到的Role或ClusterRole的名称匹配
  apiGroup: rbac.authorization.k8s.io
```
A `RoleBinding`还可以参考`ClusterRole`授予权限在定义的命名空间的资源`ClusterRole`的范围内`RoleBinding`的命名空间。这使管理员可以为整个集群定义一组通用角色，然后在多个名称空间中重用它们。

例如，即使以下内容`RoleBinding`引用`ClusterRole`，“ dave”（主题，区分大小写）也只能读取“ development”命名空间（RoleBinding的命名空间）中的secret。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
# This role binding allows "dave" to read secrets in the "development" namespace.
kind: RoleBinding
metadata:
  name: read-secrets
  namespace: development # This only grants permissions within the "development" namespace.
subjects:
- kind: User
  name: dave # Name is case sensitive
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

最后，`ClusterRoleBinding`可以使用a 在群集级别和所有名称空间中授予权限。以下内容`ClusterRoleBinding`允许“manager”组中的任何用户读取任何名称空间中的secret。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
# This cluster role binding allows anyone in the "manager" group to read secrets in any namespace.
kind: ClusterRoleBinding
metadata:
  name: read-secrets-global
subjects:
- kind: Group
  name: manager # Name is case sensitive
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```
您不能修改引用哪个对象`Role`或`ClusterRole`绑定对象。尝试更改roleRef绑定对象的字段将导致验证错误。要更改`roleRef`现有绑定对象上的字段，必须删除并重新创建绑定对象。此限制有两个主要原因：
- 对不同角色的绑定是根本不同的绑定。要求删除/重新创建绑定以进行更改，以`roleRef` 确保打算将绑定中的主题的完整列表授予新角色（而不是仅在不验证所有现有主题的情况下允许意外地修改`roleRef`，这是相对的）新角色的权限）。
- 使之成为roleRef不可变的允许update将对现有绑定对象的许可授予用户，这使他们可以管理主题列表，而无需更改授予这些主题的角色。

该`kubectl auth reconcile`命令行实用程序创建或更新包含RBAC对象清单文件，并删除句柄，如果需要改变他们指的是重新创建角色绑定对象。有关更多信息，请参见命令用法和示例。


### Referring to Resources
大多数资源都由其名称的字符串表示形式表示，例如“ `pods`”，就像它出现在相关API端点的URL中一样。但是，某些`Kubernetes API`涉及“子资源”，例如Pod的日志。Pod日志端点的URL为：

```
GET /api/v1/namespaces/{namespace}/pods/{name}/log
```

在这种情况下，“ pods”是命名空间资源，而“ log”是pod的子资源。为了以RBAC角色表示，请使用斜杠分隔资源和子资源。要允许主题同时阅读Pod和Pod日志，您可以编写：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-and-pod-logs-reader
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
```

对于`resourceNames`列表中的某些请求，资源也可以按名称引用。指定后，可以将请求限制为资源的各个实例。要将主题限制为仅“get”和“update”单个configmap，应编写：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: configmap-updater
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["my-configmap"]
  verbs: ["update", "get"]
```

Note that `create` requests cannot be restricted by resourceName, as the object name is not known at authorization time. The other exception is `deletecollection`.

### Aggregated ClusterRoles(聚集的ClusterRoles)

从1.9开始，可以通过使用组合其他`ClusterRoles`来创建`ClusterRoles aggregationRule`。聚合`ClusterRoles`的权限由控制器管理，并通过合并与提供的标签选择器匹配的任何`ClusterRole`的规则来填充。汇总的`ClusterRole`示例：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-monitoring: "true"
rules: [] # Rules are automatically filled in by the controller manager.
```

创建与标签选择器匹配的`ClusterRole`会将规则添加到聚合的`ClusterRole`。在这种情况下，可以通过创建另一个具有标签的`ClusterRole`将规则添加到“monitoring” `ClusterRole rbac.example.com/aggregate-to-monitoring: true`。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-endpoints
  labels:
    rbac.example.com/aggregate-to-monitoring: "true"
# These rules will be added to the "monitoring" role.
rules:
- apiGroups: [""]
  resources: ["services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
```

默认的面向用户的角色（如下所述）使用ClusterRole聚合。这使管理员可以在默认角色上包括自定义资源的规则，例如CustomResourceDefinitions或Aggregated API服务器提供的规则。

例如，以下ClusterRoles使“ admin”和“ edit”默认角色管理自定义资源“ CronTabs”，而“ view”角色对资源执行只读操作。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: aggregate-cron-tabs-edit
  labels:
    # Add these permissions to the "admin" and "edit" default roles.
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
rules:
- apiGroups: ["stable.example.com"]
  resources: ["crontabs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: aggregate-cron-tabs-view
  labels:
    # Add these permissions to the "view" default role.
    rbac.authorization.k8s.io/aggregate-to-view: "true"
rules:
- apiGroups: ["stable.example.com"]
  resources: ["crontabs"]
  verbs: ["get", "list", "watch"]
```

#### 角色实例
rules在以下示例中仅显示该部分。

允许读取核心API组中的资源“ pods” ：

```yaml
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```
允许在“扩展”和“应用” API组中读取/编写“deployments”：

```yaml
rules:
- apiGroups: ["extensions", "apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

允许阅读“ pods”和阅读/撰写“ jobs”：

```yaml
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch", "extensions"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

允许读取一个ConfigMap名为“ my-config”（必须与绑定RoleBinding以限制ConfigMap单个名称空间中的单个名称）：

```yaml
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["my-config"]
  verbs: ["get"]
```

允许读取核心组中的资源“节点”（由于a Node是集群范围的，因此必须与a ClusterRole绑定ClusterRoleBinding才能生效）：

```yaml
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
```

允许对非资源端点“/healthz”和所有子路径的“ GET”和“ POST”请求（必须`ClusterRole`与绑定以`ClusterRoleBinding`生效）：

```yaml
rules:
- nonResourceURLs: ["/healthz", "/healthz/*"] # '*' in a nonResourceURL is a suffix glob match
  verbs: ["get", "post"]
```

### Referring to Subjects

一个`RoleBinding`或`ClusterRoleBinding`结合一个角色对象。主题可以是组，用户或服务帐户。

用户由字符串表示。这些可以是简单的用户名（例如“ alice”），电子邮件样式的名称（例如“ bob@example.com”）或表示为字符串的数字ID。由Kubernetes管理员来配置身份验证模块以生成所需格式的用户名。RBAC授权系统不需要任何特定格式。但是，该前缀 **system:** 保留给Kubernetes系统使用，因此管理员应确保用户名偶然不包含该前缀。

身份验证器模块当前提供Kubernetes中的组信息。像用户一样，组用字符串表示，并且该字符串没有格式要求，除了前缀 **system:** 是保留的。

[服务帐户](https://kubernetes.hankbook.cn/configure-pod-container/configure-service-account.html)的用户名带有  **system:serviceaccount:**  前缀，并且属于带有 **system:serviceaccounts:** 前缀的组。

#### 角色绑定示例

在以下示例中，仅显示`subjects`a 的部分`RoleBinding`。

对于名为“ alice@example.com”的用户：

```yaml
subjects:
- kind: User
  name: "alice@example.com"
  apiGroup: rbac.authorization.k8s.io
```

对于名为“ frontend-admins”的组：

```yaml
subjects:
- kind: Group
  name: "frontend-admins"
  apiGroup: rbac.authorization.k8s.io
```

对于kube-system命名空间中的默认服务帐户：

```yaml
subjects:
- kind: ServiceAccount
  name: default
  namespace: kube-system
```

对于“ qa”命名空间中的所有服务帐户：

```yaml
subjects:
- kind: Group
  name: system:serviceaccounts:qa
  apiGroup: rbac.authorization.k8s.io
```

对于世界各地的所有服务帐户：

```yaml
subjects:
- kind: Group
  name: system:serviceaccounts
  apiGroup: rbac.authorization.k8s.io
```

对于所有经过身份验证的用户（1.5版或更高版本）：

```yaml
subjects:
- kind: Group
  name: system:authenticated
  apiGroup: rbac.authorization.k8s.io
```

对于所有未经身份验证的用户（1.5及更高版本）：

```yaml
subjects:
- kind: Group
  name: system:unauthenticated
  apiGroup: rbac.authorization.k8s.io
```

对于所有用户（1.5及更高版本）：

```yaml
subjects:
- kind: Group
  name: system:authenticated
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: system:unauthenticated
  apiGroup: rbac.authorization.k8s.io
```

## 默认角色和角色绑定

API服务器创建一组默认值`ClusterRole`和`ClusterRoleBinding`对象。其中许多带有`system:`前缀，表示资源由基础架构“拥有”。修改这些资源可能会导致群集无法正常运行。一个示例是system:nodeClusterRole。该角色定义kubelet的权限。如果角色被修改，则它可能会阻止kubelet工作。

所有默认集群角色和角色绑定均标记为`kubernetes.io/bootstrapping=rbac-defaults`。

### Auto-reconciliation（自动对帐）

在每次启动时，API服务器都会使用缺少的任何权限来更新默认集群角色，并使用任何缺少的主题来更新默认集群角色绑定。这使群集可以修复意外的修改，并在权限和主题在新版本中发生更改时使角色和角色绑定保持最新。

要选择退出此对帐，请将`rbac.authorization.kubernetes.io/autoupdate` 默认群集角色或角色绑定上的注释设置为false。请注意，缺少默认权限和主题可能会导致群集无法正常运行。

当RBAC授权者处于活动状态时，在Kubernetes 1.6+版本中启用了`Auto-reconciliation`。


### Discovery Roles(发现角色)

默认角色绑定授权未经身份验证和身份验证的用户读取被认为可安全公开访问的API信息（包括CustomResourceDefinitions）。要禁用匿名未经`--anonymous-auth=false`身份验证的访问，请添加到API服务器配置。

要通过kubectl运行查看这些角色的配置：

```bash
kubectl get clusterroles system:discovery -o yaml
```

注意：不建议编辑角色，因为更改将在API服务器通过自动对帐重新启动时被覆盖（请参见上文）。

|默认ClusterRole|默认的ClusterRoleBinding|描述|
|---|---|---|
| **system:basic-user** | **system:authenticated** group|允许用户以只读方式访问有关自己的基本信息。在1.14之前，默认情况下，此角色还绑定到`system：unauthenticated`。|
| **system:discovery** | **system:authenticated** group|允许对发现和协商API级别所需的API发现端点的只读访问。在1.14之前，默认情况下，此角色还绑定到`system：unauthenticated`。|
| **system:public-info-viewer**	| **system:authenticated** and **system:unauthenticated** groups|允许以只读方式访问有关群集的非敏感信息。在1.14版中引入。|


### User-facing Roles(面向用户的角色)

一些默认角色没有`system:`前缀。这些旨在用作面向用户的角色。它们包括超级用户角色（`cluster-admin`），角色旨在利用`ClusterRoleBindings`（被授予群集范围`cluster-status`），和角色打算使用`RoleBindings`特定命名空间内提供的（`admin`，`edit`，`view`）。

从1.9开始，面向用户的角色使用`ClusterRole Aggregation`允许管理员在这些角色上包括自定义资源的规则。要将规则添加到“admin”，“edit”或“view”角色，请创建具有以下一个或多个标签的ClusterRole：

```yaml
metadata:
  labels:
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
    rbac.authorization.k8s.io/aggregate-to-view: "true"
```

|默认ClusterRole|默认的ClusterRoleBinding|描述|
|---|---|---|
| **cluster-admin** | **system:masters**  group|	允许超级用户访问权对任何资源执行任何操作。在ClusterRoleBinding中使用时，它可以完全控制集群中所有名称空间中的每个资源。在RoleBinding中使用时，它可以完全控制角色绑定的名称空间中的每个资源，包括名称空间本身。|
| ***admin* | None |允许管理员访问，该访问旨在使用RoleBinding在名称空间中授予。如果在RoleBinding中使用，则允许对命名空间中的大多数资源进行读/写访问，包括在命名空间中创建角色和角色绑定的能力。它不允许对资源配额或名称空间本身进行写访问。|
| **edit** | None |允许对命名空间中的大多数对象进行读/写访问。它不允许查看或修改角色或角色绑定。|
| **view** | None |允许只读访问以查看名称空间中的大多数对象。它不允许查看角色或角色绑定。它不允许查看秘密，因为这些秘密正在升级。|

### Core Component Roles(核心组件角色)

|默认ClusterRole|默认的ClusterRoleBinding|描述|
|---|---|---|
| **system:kube-scheduler** | **system:kube-scheduler** user|允许访问kube-scheduler组件所需的资源。|
| **system:volume-scheduler** | **system:kube-scheduler** user|	允许访问kube-scheduler组件所需的卷资源。|
| **system:kube-controller-manager** |	**system:kube-controller-manager** user|允许访问kube-controller-manager组件所需的资源。各个控制循环所需的权限包含在控制器角色中。|
| **system:node** | 	None in 1.8+ |允许访问kubelet组件所需的资源，包括对所有secret的读访问和对所有pod状态对象的写访问。从1.7开始，建议使用Node Authorizer和NodeRestriction接纳插件而不是此角色，并允许根据计划在其上运行的Pod向Kubelet授予API访问权限。在1.7之前，此角色已自动绑定到`system：nodes`组。在1.7中，如果未启用“节点”授权模式，则此角色自动绑定到“系统：节点”组。在1.8+中，不会自动创建绑定。|
| **system:node-proxier** |	**system:kube-proxy** user | 允许访问kube-proxy组件所需的资源。|

### Other Component Roles(其他组件角色)

|默认ClusterRole|默认的ClusterRoleBinding|描述|
|---|---|---|
| **system:auth-delegator** |	None |允许委托的身份验证和授权检查。附加API服务器通常将其用于统一身份验证和授权。|
| **system:heapster** |	None |Heapster组件的角色。|
| **system:kube-aggregator** | None |	kube-aggregator组件的角色。|
| **system:kube-dns** |	kube-dns service account in the kube-system namespace |	kube-dns组件的角色。|
| **system:kubelet-api-admin** | None |允许完全访问kubelet API。|
| **system:node-bootstrapper** | None |允许访问执行Kubelet TLS引导所需的资源 。|
| **system:node-problem-detector** | None |节点问题检测器组件的角色。|
| **system:persistent-volume-provisioner** | None |允许访问大多数动态卷配置程序所需的资源。|

### Controller Roles(控制器角色)

该Kubernetes控制器管理运行的核心控制回路。当使用调用时`--use-service-account-credentials`，每个控制循环都使用一个单独的服务帐户启动。每个控制循环都有对应的角色，并带有`system:controller:`。如果控制器管理器不是以开头的`--use-service-account-credentials`，则它将使用自己的凭证运行所有控制循环，必须授予其所有相关角色。这些角色包括：

- system:controller:attachdetach-controller
- system:controller:certificate-controller
- system:controller:clusterrole-aggregation-controller
- system:controller:cronjob-controller
- system:controller:daemon-set-controller
- system:controller:deployment-controller
- system:controller:disruption-controller
- system:controller:endpoint-controller
- system:controller:expand-controller
- system:controller:generic-garbage-collector
- system:controller:horizontal-pod-autoscaler
- system:controller:job-controller
- system:controller:namespace-controller
- system:controller:node-controller
- system:controller:persistent-volume-binder
- system:controller:pod-garbage-collector
- system:controller:pv-protection-controller
- system:controller:pvc-protection-controller
- system:controller:replicaset-controller
- system:controller:replication-controller
- system:controller:resourcequota-controller
- system:controller:root-ca-cert-publisher
- system:controller:route-controller
- system:controller:service-account-controller
- system:controller:service-controller
- system:controller:statefulset-controller
- system:controller:ttl-controller

## Privilege Escalation Prevention and Bootstrapping(特权升级的预防和引导)

`RBAC API`通过编辑角色或角色绑定来防止用户提升特权。因为这是在API级别强制执行的，所以即使不使用RBAC授权者，它也适用。

如果满足以下至少一项条件，则用户只能创建/更新角色：

1. 他们已经拥有角色中包含的所有权限，与正在修改的对象的作用域相同（对于`ClusterRole`，在群集范围内为，在同一名称空间内，在群集范围内Role）。

2. 他们被明确授予在API组中`escalate`对`roles`或`clusterroles`资源执行动词的权限`rbac.authorization.k8s.io`（Kubernetes 1.12及更高版本）

例如，如果“用户1”不具有在群集范围内列出机密的功能，则他们无法创建`ClusterRole` 包含该权限的机密。要允许用户创建/更新角色：

1. 授予他们一个角色，使他们可以根据需要创建/更新`Role`或`ClusterRole`对象。

2. 授予他们权限以在创建/更新角色中包括特定权限：
  - 隐式地，通过向他们授予这些权限（如果他们尝试创建或修改Role或未ClusterRole授予自己的权限，则将禁止API请求）
  - 或明确允许在中指定任何权限，Role或ClusterRole通过向其授予对API组中的escalate动词roles或clusterroles资源执行动词的权限rbac.authorization.k8s.io（Kubernetes 1.12及更高版本）

如果用户已经具有引用角色中包含的所有权限（与角色绑定处于相同范围），或者已被授予显式权限以bind对引用角色执行动词，则用户只能创建/更新角色绑定。例如，如果“用户1”没有能力在整个群集范围内列出机密，则他们无法ClusterRoleBinding 为授予该权限的角色创建。要允许用户创建/更新角色绑定：

1. 授予他们一个角色，使他们可以根据需要创建/更新RoleBinding或ClusterRoleBinding对象。
2. 向他们授予绑定特定角色所需的权限：
  - 通过隐式地授予他们角色中包含的权限。
  - 明确地授予他们bind在特定角色（或群集角色）上执行动词的权限。

例如，结合这组角色和角色将允许“用户1”授予其他用户admin，`edit`和`view`角色中的“用户1 -命名空间”的命名空间：


```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: role-grantor
rules:
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["rolebindings"]
  verbs: ["create"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterroles"]
  verbs: ["bind"]
  resourceNames: ["admin","edit","view"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: role-grantor-binding
  namespace: user-1-namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: role-grantor
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: user-1
```

当引导第一个角色和角色绑定时，初始用户必须授予他们尚不具有的权限。要引导初始角色和角色绑定：

- 对`system:masters`组使用凭据，该凭据`cluster-admin`通过默认绑定绑定到超级用户角色。
- 如果您的API服务器在启用了不安全端口（`--insecure-port`）的情况下运行，则您也可以通过该端口进行API调用，这不会强制执行身份验证或授权。

## 命令行实用程序

### kubectl create role

Role在单个名称空间中创建定义权限的对象。例子：

- 创建一个Role名为“ pod-reader”的文件，该文件允许用户在pod上执行“ get”，“ watch”和“ list”：

  ```bash
  kubectl create role pod-reader --verb=get --verb=list --verb=watch --resource=pods
  ```

- Role使用指定的resourceNames 创建一个名为“ pod-reader”的名称：

  ```bash
  kubectl create role pod-reader --verb=get --resource=pods --resource-name=readablepod --resource-name=anotherpod
  ```
- Role使用指定的apiGroup 创建一个名为“ foo”的名称：

  ```bash
  kubectl create role foo --verb=get,list,watch --resource=replicasets.apps
  ```

- 创建一个Role具有子资源权限的名为“ foo” 的名称：

  ```bash
  kubectl create role foo --verb=get,list,watch --resource=pods,pods/status
  ```

- 创建一个Role名为“ my-component-lease-holder”的权限，该权限具有获取/更新具有特定名称的资源的权限：

  ```bash
  kubectl create role my-component-lease-holder --verb=get,list,watch,update --resource=lease --resource-name=my-component
  ```

### kubectl create clusterrole

创建一个ClusterRole对象。例子：

- 创建一个ClusterRole名为“ pod-reader”的文件，该文件允许用户在pod上执行“ get”，“ watch”和“ list”：

  ```bash
  kubectl create clusterrole pod-reader --verb=get,list,watch --resource=pods
  ```

- ClusterRole使用指定的resourceNames 创建一个名为“ pod-reader”的名称：

  ```bash
  kubectl create clusterrole pod-reader --verb=get --resource=pods --resource-name=readablepod --resource-name=anotherpod
  ```

- ClusterRole使用指定的apiGroup 创建一个名为“ foo”的名称：

  ```bash
  kubectl create clusterrole foo --verb=get,list,watch --resource=replicasets.apps
  ```

- 创建一个ClusterRole具有子资源权限的名为“ foo” 的名称：

  ```bash
  kubectl create clusterrole foo --verb=get,list,watch --resource=pods,pods/status
  ```

- ClusterRole使用指定的nonResourceURL 创建名称“ foo”：

  ```bash
  kubectl create clusterrole "foo" --verb=get --non-resource-url=/logs/*
  ```

- ClusterRole使用指定的aggregationRule 创建名称“ monitoring”：

  ```bash
  kubectl create clusterrole monitoring --aggregation-rule="rbac.example.com/aggregate-to-monitoring=true"
  ```

### kubectl create rolebinding
在特定名称空间中授予Role或ClusterRole。例子：

- 在名称空间“ acme”内，将中的权限授予admin ClusterRole名为“ bob”的用户：

  ```bash
  kubectl create rolebinding bob-admin-binding --clusterrole=admin --user=bob --namespace=acme
  ```

- 在名称空间“ acme”中，将的权限授予view ClusterRole名称空间“ acme”中名为“ myapp”的服务帐户：

  ```bash
  kubectl create rolebinding myapp-view-binding --clusterrole=view --serviceaccount=acme:myapp --namespace=acme
  ```

- 在名称空间“ acme”中，将的权限授予view ClusterRole名称空间“ myappnamespace”中名为“ myapp”的服务帐户：

  ```bash
  kubectl create rolebinding myappnamespace-myapp-view-binding --clusterrole=view --serviceaccount=myappnamespace:myapp --namespace=acme
  ```

### kubectl create clusterrolebinding
ClusterRole在整个群集（包括所有名称空间）中授予。例子：

- 在整个群集中，将中的权限授予cluster-admin ClusterRole名为“ root”的用户：

  ```bash
  kubectl create clusterrolebinding root-cluster-admin-binding --clusterrole=cluster-admin --user=root
  ```

- 在整个集群中，将中的权限授予system:node-proxier ClusterRole名为“ system：kube-proxy”的用户：

  ```bash
  kubectl create clusterrolebinding kube-proxy-binding --clusterrole=system:node-proxier --user=system:kube-proxy
  ```

- 在整个群集中，将的权限授予view ClusterRole名称空间“ acme”中名为“ myapp”的服务帐户：

  ```bash
  kubectl create clusterrolebinding myapp-view-binding --clusterrole=view --serviceaccount=acme:myapp
  ```

### kubectl auth reconcile

`rbac.authorization.k8s.io/v1`从清单文件创建或更新API对象。  

如果需要，将创建丢失的对象，并为命名空间的对象创建包含名称空间。

现有角色将更新为在输入对象中包括权限，并删除多余的权限（如果--remove-extra-permissions已指定）。

现有绑定将更新为将主题包含在输入对象中，并删除多余的主题（如果--remove-extra-subjects已指定）。

- 测试应用RBAC对象的清单文件，显示将要进行的更改：

  ```bash
  kubectl auth reconcile -f my-rbac-rules.yaml --dry-run
  ```

- 应用RBAC对象的清单文件，保留任何额外的权限（在角色中）和所有额外的主题（在绑定中）：

  ```bash
  kubectl auth reconcile -f my-rbac-rules.yaml
  ```

- 应用RBAC对象的清单文件，删除任何额外的权限（在角色中）和所有额外的主题（在绑定中）：

  ```bash
  kubectl auth reconcile -f my-rbac-rules.yaml --remove-extra-subjects --remove-extra-permissions
  ```

有关详细用法，请参见CLI帮助。

## 服务帐户权限

默认的RBAC策略向控制平面组件，节点和控制器授予范围内的权限，但不授予`kube-system`名称空间之外的服务帐户的权限（除了授予所有已验证用户的发现权限之外）。

这使您可以根据需要向特定的服务帐户授予特定的角色。细粒度的角色绑定提供了更高的安全性，但是需要更多的精力来进行管理。范围更广的授权可以为服务帐户提供不必要（且可能不断升级）的API访问权限，但更易于管理。

按照从最安全到最不安全的顺序，这些方法是：

1. 将角色授予特定于应用程序的服务帐户（最佳做法）

  这要求应用程序serviceAccountName在其pod规范中指定一个，并为要创建的服务帐户（通过API，应用程序清单kubectl create serviceaccount等）指定一个。

  例如，将“ my-namespace”内的只读权限授予“ my-sa”服务帐户：

  ```bash
  kubectl create rolebinding my-sa-view \
  --clusterrole=view \
  --serviceaccount=my-namespace:my-sa \
  --namespace=my-namespace
  ```

2. 将角色授予名称空间中的“默认”服务帐户

  如果应用程序未指定serviceAccountName，它将使用“默认”服务帐户。

  - **注意**：授予“默认”服务帐户的权限可用于名称空间中未指定的任何Pod serviceAccountName。

  例如，将“我的名称空间”内的只读权限授予“默认”服务帐户：

  ```bash
  kubectl create rolebinding default-view \
    --clusterrole=view \
    --serviceaccount=my-namespace:default \
    --namespace=my-namespace
  ```
  当前，许多加载项在kube-system名称空间中作为“默认”服务帐户运行。要允许这些加载项以超级用户访问权限运行，请将集群管理员权限授予kube-system名称空间中的“默认”服务帐户。

  - **注意**：启用此选项意味着kube-system 名称空间包含用于授予超级用户访问API权限的机密。

  ```bash
  kubectl create clusterrolebinding add-on-cluster-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:default
  ```

3. 向名称空间中的所有服务帐户授予角色

  如果要使名称空间中的所有应用程序都具有角色，无论它们使用什么服务帐户，都可以为该名称空间的服务帐户组授予角色。

  例如，将“ my-namespace”内的只读权限授予该命名空间中的所有服务帐户：

  ```bash
  kubectl create rolebinding serviceaccounts-view \
  --clusterrole=view \
  --group=system:serviceaccounts:my-namespace \
  --namespace=my-namespace
  ```

4. 对群集范围内的所有服务帐户（有限）授予有限的角色

  如果您不想按名称空间管理权限，则可以为所有服务帐户授予群集范围的角色。

  例如，将所有名称空间的只读权限授予群集中的所有服务帐户

  ```bash
  kubectl create clusterrolebinding serviceaccounts-view \
  --clusterrole=view \
  --group=system:serviceaccounts
  ```

5. 授予超级用户访问群集范围内所有服务帐户的权限（强烈建议）

  如果您根本不关心分区权限，则可以授予超级用户对所有服务帐户的访问权限。

  - **警告**：这将允许任何具有机密访问权限的用户或能够创建pod来访问超级用户凭据的用户。

  ```bash
  kubectl create clusterrolebinding serviceaccounts-cluster-admin \
  --clusterrole=cluster-admin \
  --group=system:serviceaccounts
  ```


## 从1.5升级

在Kubernetes 1.6之前，许多部署都使用非常宽松的ABAC策略，包括向所有服务帐户授予完全API访问权限。

默认的RBAC策略向控制平面组件，节点和控制器授予范围内的权限，但不授予kube-system名称空间之外的服务帐户的权限（除了授予所有已验证用户的发现权限之外）。

尽管安全性要高得多，但是这可能会破坏希望自动获得API权限的现有工作负载。这是管理此过渡的两种方法：

### 平行授权者

运行RBAC和ABAC授权者，并指定一个包含旧式ABAC策略的策略文件 ：

```
--authorization-mode=RBAC,ABAC --authorization-policy-file=mypolicy.json
```

RBAC授权者将首先尝试授权请求。如果拒绝API请求，则运行ABAC授权者。这意味着，通过允许任何请求任一的RBAC或ABAC策略是允许的。

当apiserver以RBAC组件（--vmodule=rbac*=5或--v=5）的日志级别为5或更高运行时，您可以在apiserver日志（带有前缀RBAC DENY:）中看到RBAC拒绝。您可以使用该信息来确定需要授予哪些用户，组或服务帐户哪些角色。一旦你已经授予的角色服务帐户和工作负载在服务器日志中没有RBAC拒绝的消息正在运行，可以删除ABAC授权。

## 允许的RBAC权限

您可以使用RBAC角色绑定复制许可策略。

**警告：**

以下策略允许所有服务帐户充当群集管理员。容器中运行的任何应用程序都会自动接收服务帐户凭据，并且可以针对API执行任何操作，包括查看机密和修改权限。这不是推荐的策略。

```bash
kubectl create clusterrolebinding permissive-binding \
  --clusterrole=cluster-admin \
  --user=admin \
  --user=kubelet \
  --group=system:serviceaccounts
```




参考文档： https://kubernetes.io/docs/reference/access-authn-authz/rbac/
