# Labels and Selectors (标签和选择器)

标签 是附加到 Kubernetes 对象（比如 Pods）上的键值对。 标签旨在用于指定对用户有意义且相关的对象的标识属性，但不直接对核心系统有语义含义。 标签可以用于组织和选择对象的子集。标签可以在创建时附加到对象，随后可以随时添加和修改。 每个对象都可以定义一组键/值标签。每个键对于给定对象必须是唯一的。

```yaml
"metadata": {
  "labels": {
    "key1" : "value1",
    "key2" : "value2"
  }
}
```
我们最终将标签索引和反向索引，用于高效查询和监视，使用它们在 UI 和 CLI 中进行排序和分组等。我们不希望将非标识性的、尤其是大型或结构化数据用作标签，给后者带来污染。应使用 注解 记录非识别信息

## 动机

标签使用户能够以松散耦合的方式将他们自己的组织结构映射到系统对象，而无需客户端存储这些映射。

服务部署和批处理流水线通常是多维实体（例如，多个分区或部署、多个发行序列、多个层，每层多个微服务）。管理通常需要交叉操作，这打破了严格的层次表示的封装，特别是由基础设施而不是用户确定的严格的层次结构。

示例标签：

- `"release" : "stable"`, `"release" : "canary"`
- `"environment" : "dev"`, `"environment" : "qa"`, `"environment" : "production"`
- `"tier" : "frontend"`, `"tier" : "backend"`, `"tier" : "cache"`
- `"partition" : "customerA"`, `"partition" : "customerB"`
- `"track" : "daily"`, `"track" : "weekly"`

这些只是常用标签的例子; 您可以任意制定自己的约定。请记住，对于给定对象标签的键必须是唯一的。

## 语法和字符集

标签 是键值对。有效的标签键有两个段：可选的前缀和名称，用斜杠（/）分隔。名称段是必需的，必须小于等于 63 个字符，以字母数字字符（[a-z0-9A-Z]）开头和结尾，带有破折号（-），下划线（\_），点（ .）和之间的字母数字。前缀是可选的。如果指定，前缀必须是 DNS 子域：由点（.）分隔的一系列 DNS 标签，总共不超过 253 个字符，后跟斜杠（/）。 如果省略前缀，则假定标签键对用户是私有的。 向最终用户对象添加标签的自动系统组件（例如 kube-scheduler，kube-controller-manager，kube-apiserver，kubectl 或其他第三方自动化）必须指定前缀。kubernetes.io/ 前缀是为 Kubernetes 核心组件保留的。

有效标签值必须为 63 个字符或更少，并且必须为空或以字母数字字符（[a-z0-9A-Z]）开头和结尾，中间可以包含破折号（-）、下划线（\_）、点（.）和字母或数字。

## 标签选择器

与 名称和 UID 不同，标签不提供唯一性。通常，我们希望许多对象携带相同的标签。

通过 \_标签选择器_，客户端/用户可以识别一组对象。标签选择器是 Kubernetes 中的核心分组原语。

API 目前支持两种类型的选择器：基于相等性的 和 \_基于集合的_。 标签选择器可以由逗号分隔的多个 需求 组成。在多个需求的情况下，必须满足所有要求，因此逗号分隔符充当逻辑 \_与_（&&）运算符。

空标签选择器（即，需求为零的选择器）选择集合中的每个对象。

null 值的标签选择器（仅可用于可选选择器字段）不选择任何对象

> 注意：两个控制器的标签选择器不得在命名空间内重叠，否则它们将互相冲突。

### 基于相等性的 需求

基于相等性 或 不相等 的需求允许按标签键和值进行过滤。匹配对象必须满足所有指定的标签约束，尽管它们也可能具有其他标签。 可接受的运算符有=、== 和 ！= 三种。 前两个表示 \_相等_（并且只是同义词），而后者表示 \_不相等_。 例如：


```yaml
environment = production
tier != frontend
```

前者选择所有资源，其键名等于 environment，值等于 production。 后者选择所有资源，其键名等于 tier，值不同于 frontend，所有资源都没有带有 tier 键的标签。 可以使用逗号运算符来过滤 production 环境中的非 frontend 层资源：environment=production,tier!=frontend。

基于相等性的标签要求的一种使用场景是 Pods 要指定节点选择标准。例如，下面的示例 Pod 选择带有标签 “accelerator=nvidia-tesla-p100“。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cuda-test
spec:
  containers:
    - name: cuda-test
      image: "k8s.gcr.io/cuda-vector-add:v0.1"
      resources:
        limits:
          nvidia.com/gpu: 1
  nodeSelector:
    accelerator: nvidia-tesla-p100
```

### 基于集合 的需求
基于集合 的标签需求允许您通过一组值来过滤键。支持三种操作符：in,notin and exists (只可以用在键标识符上)。例如：

```
environment in (production, qa)
tier notin (frontend, backend)
partition
!partition
```

第一个示例选择了所有键等于 environment 并且值等于 production 或者 qa 的资源。

第二个示例选择了所有键等于 tier 并且值不等于 frontend 或者 backend 的资源，以及所有没有 tier 键标签的资源。

第三个示例选择了所有包含了有 partition 标签的资源；没有校验它的值。

第四个示例选择了所有没有 partition 标签的资源；没有校验它的值。

类似地，逗号分隔符充当 AND 运算符。因此，使用 partition 键（无论为何值）和 environment 不同于 qa 来过滤资源可以使用 partition，environment notin（qa) 来实现。

基于集合 的标签选择器是相等标签选择器的一般形式，因为 environment = production 等同于 environment in（production）;！= 和 notin 也是类似的。

基于集合 的要求可以与基于 相等 的要求混合使用。例如：partition in (customerA, customerB),environment!=qa。


## API
### LIST 和 WATCH 过滤
LIST and WATCH 操作可以使用查询参数指定标签选择器过滤一组对象。两种需求都是允许的。（这里显示的是它们出现在 URL 查询字符串中）

- 基于相等性 的需求: `?labelSelector=environment%3Dproduction,tier%3Dfrontend`
- 基于集合 的需求: `?labelSelector=environment+in+%28production%2Cqa%29%2Ctier+in+%28frontend%29`

两种标签选择器都可以通过 REST 客户端用于 list 或者 watch 资源。例如，使用 kubectl 定位 apiserver，可以使用 基于相等性 的标签选择器可以这么写：

```bash
$ kubectl get pods -l environment=production,tier=frontend
```

或者使用 基于集合的 需求：

```bash
$ kubectl get pods -l 'environment in (production),tier in (frontend)'
```

正如刚才提到的，基于集合 的需求更具有表达力。例如，它们可以实现值的 或 操作：

```bash
$ kubectl get pods -l 'environment in (production, qa)'
```

或者通过 exists 运算符限制不匹配：

```bash

$ kubectl get pods -l 'environment,environment notin (frontend)'
```

### 在 API 对象上设置引用

一些 Kubernetes 对象，例如 services 和 replicationcontrollers ，也使用了标签选择器去指定了其他资源的集合，例如 pods。

#### Service 和 ReplicationController

一个 Service 指向的一组 pods 是由标签选择器定义的。同样，一个 ReplicationController 应该管理的 pods 的数量也是由标签选择器定义的。

两个对象的标签选择器都是在 json 或者 yaml 文件中使用映射定义的，并且只支持 基于相等性 需求的选择器：

```json
"selector": {
    "component" : "redis",
}
```
或者
```yaml
selector:
    component: redis
```

这个选择器(分别在 json 或者 yaml 格式中) 等价于 component=redis 或 component in (redis) 。

#### 支持基于集合需求的资源
比较新的资源，例如 Job、Deployment、Replica Set 和Daemon Set ,也支持 基于集合的 需求。

```yaml
selector:
  matchLabels:
    component: redis
  matchExpressions:
    - {key: tier, operator: In, values: [cache]}
    - {key: environment, operator: NotIn, values: [dev]}
```
matchLabels 是由 {key，value} 对组成的映射。matchLabels 映射中的单个 {key，value } 等同于 matchExpressions 的元素，其 key字段为 “key”，operator 为 “In”，而 values 数组仅包含 “value”。matchExpressions 是 pod 选择器要求的列表。有效的运算符包括 In，NotIn，Exists 和 DoesNotExist。在 In 和 NotIn 的情况下，设置的值必须是非空的。来自 matchLabels 和 matchExpressions 的所有要求都是合在一起 – 它们必须都满足才能匹配。

#### 选择节点集
通过标签进行选择的一个用例是确定节点集，方便 pod 调度。 



参考文档：  
https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/  
