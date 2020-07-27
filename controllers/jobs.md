# Jobs - Run to Completion
job会创建一个或多个Pod，并确保指定数量的Pod成功终止。pods成功完成后，工作将跟踪成功完成的情况。当达到指定的成功完成次数时，任务（即Job）就完成了。删除job将清除其创建的Pod。

一个简单的情况是创建一个Job对象，以可靠地运行一个Pod来完成。如果第一个Pod发生故障或被删除（例如，由于节点硬件故障或节点重启），则Job对象将启动一个新的Pod。

您也可以使用Job并行运行多个Pod。

## demo(随时使用)
编写一个demo的job，随时测试使用

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-demo
spec:
  template:
    metadata:
      name: job-demo
    spec:
      restartPolicy: Never
      containers:
      - name: demo
        image: busybox
        command:
        - "bin/sh"
        - "-c"
        - "for i in {1..10}; do echo $i; done"
```

## 运行一个示例 Job
这是一个job配置示例。它计算π到2000个位置并将其打印出来。大约需要10秒钟才能完成。

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
  backoffLimit: 4
```

您可以使用以下命令运行示例：


```bash
kubectl apply -f job.yaml
```

使用以下命令检查job的状态kubectl：

```bash
kubectl describe jobs/pi
```

看job对应的pods是否完成, 使用 `kubectl get pods`.

要以机器可读的形式列出属于job的所有Pod，可以使用如下命令：

```bash
pods=$(kubectl get pods --selector=job-name=pi --output=jsonpath='{.items[*].metadata.name}')
echo $pods
```
在此，选择器与job的选择器相同。该--output=jsonpath选项指定一个表达式，该表达式仅从返回列表中的每个Pod中获取名称。

查看其中一个Pod的标准输出：

```bash
kubectl logs $pods
```
输出类似于以下内容：

```
3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679821480865132823066470938446095505822317253594081284811174502841027019385211055596446229489549303819644288109756659334461284756482337867831652712019091456485669234603486104543266482133936072602491412737245870066063155881748815209209628292540917153643678925903600113305305488204665213841469519415116094330572703657595919530921861173819326117931051185480744623799627495673518857527248912279381830119491298336733624406566430860213949463952247371907021798609437027705392171762931767523846748184676694051320005681271452635608277857713427577896091736371787214684409012249534301465495853710507922796892589235420199561121290219608640344181598136297747713099605187072113499999983729780499510597317328160963185950244594553469083026425223082533446850352619311881710100031378387528865875332083814206171776691473035982534904287554687311595628638823537875937519577818577805321712268066130019278766111959092164201989380952572010654858632788659361533818279682303019520353018529689957736225994138912497217752834791315155748572424541506959508295331168617278558890750983817546374649393192550604009277016711390098488240128583616035637076601047101819429555961989467678374494482553797747268471040475346462080466842590694912933136770289891521047521620569660240580381501935112533824300355876402474964732639141992726042699227967823547816360093417216412199245863150302861829745557067498385054945885869269956909272107975093029553211653449872027559602364806654991198818347977535663698074265425278625518184175746728909777727938000816470600161452491921732172147723501414419735685481613611573525521334757418494684385233239073941433345477624168625189835694855620992192221842725502542568876717904946016534668049886272327917860857843838279679766814541009538837863609506800642251252051173929848960841284886269456042419652850222106611863067442786220391949450471237137869609563643719172874677646575739624138908658326459958133904780275901
```

## 编写工作规范
与所有其他Kubernetes配置，job的需要apiVersion，kind和metadata领域。其名称必须是有效的DNS子域名。

一个Job还需要一个.spec部分。

### Pod Template

该`.spec.template`是唯一需要的领域`.spec`。

这`.spec.template`是一个pod模板。它具有与Pod完全相同的架构，只是它是嵌套的并且没有`apiVersion` 或者 `kind`。

除了Pod的必填字段外，job中的Pod模板还必须指定适当的标签（请参阅Pod选择器）和适当的重新启动策略。

只能RestartPolicy等于Never或OnFailure允许。

### Pod Selector
该`.spec.selector`字段是可选的。在几乎所有情况下，都不应该指定它。请参阅指定您自己的Pod选择器的部分。

### Parallel Jobs(并行jobs)

适合作为jobs运行的三种主要任务类型：

1. 非并行jobs
  - 通常，除非Pod发生故障，否则仅启动一个Pod。
  - 一旦Pod成功终止，job即完成。
2. 固定完成计数的并行jobs：
  - 为指定非零的正值`.spec.completions`。
  - Job代表整体任务，并且在1到范围内的每个值都有一个成功的Pod时完成`.spec.completions`。
  - 尚未实现：每个Pod传递了1到范围内的不同索引`.spec.completions`。
3. 具有工作队列的并行jobs：
  - 不指定.spec.completions，默认为.spec.parallelism。
  - Pod必须在彼此之间或外部服务之间进行协调，以确定每个Pod应该如何处理。例如，一个Pod可以从工作队列中获取最多N批的批处理。
  - 每个Pod都可以独立地确定其所有对等方是否都已完成，从而确定了整个Job。
  - 当job中的任何 Pod成功终止时，不会创建新的Pod。
  - 一旦至少一个Pod成功终止并且所有Pod都终止，则job成功完成。
  - 一旦Pod成功退出，则其他Pod仍不应为此任务做任何工作或编写任何输出。他们都应该退出。

对于非平行job，你可以离开这两个.spec.completions和.spec.parallelism未设置。两者均未设置时，均默认为1。

对于固定的完成计数job，您应该设置.spec.completions为所需的完成数量。您可以设置.spec.parallelism，或不设置它，默认为1。

对于工作队列 Job，您必须保持未`.spec.completions`设置状态，并将其设置`.spec.parallelism`为非负整数。

## Controlling Parallelism(控制并行)
可以将请求的并行度（.spec.parallelism）设置为任何非负值。如果未指定，则默认为1。如果将其指定为0，则job将有效地暂停直到增加。

出于多种原因，实际的并行性（随时运行的Pod数量）可能大于或小于请求的并行性：

- 对于固定的完成计数作业，并行运行的pods的实际数量不会超过剩余的完成数量。.spec.parallelism有效地忽略的较高值。
- 对于工作队列作业，任何Pod成功后都不会启动新的Pod –但是，其余Pod则可以完成。
- 如果作业控制器是还没来得及反应。
- 如果job控制器由于任何原因（缺少ResourceQuota，缺少权限等）未能创建Pod，则可能是Pod少于请求的数量。
- job控制器可能会由于同一job中先前的过多Pod故障而限制新Pod的创建。
- 如果Pod正常关闭，则需要花费一些时间才能停止。


## 处理Pod和容器故障

Pod中的容器可能由于多种原因而失败，例如，由于该容器中的进程以非零退出代码退出，或者该容器因超出内存限制而被杀死等。如果发生这种情况`.spec.template.spec.restartPolicy = "OnFailure"`，则使用Pod停留在节点上，但是容器重新运行。因此，您的程序需要在本地重新启动时处理该情况，或者指定`.spec.template.spec.restartPolicy = "Never"`。

由于多种原因，整个Pod也可能会失败，例如，当Pod从节点上踢开（节点已升级，重新引导，删除等）时，或者Pod的容器发生故障时，则显示 `.spec.template.spec.restartPolicy = "Never"`。当Pod发生故障时，job控制器将启动一个新Pod。这意味着您的应用程序需要在新的容器中重新启动时处理该情况。特别是，它需要处理由先前运行引起的临时文件，锁，不完整的输出等。

请注意，即使您指定`.spec.parallelism = 1`和`.spec.completions = 1`和 `.spec.template.spec.restartPolicy = "Never"`，同一程序有时也可能启动两次。

如果您指定`.spec.parallelism`并且`.spec.completions`两个都大于1，则可能一次运行多个Pod。因此，您的Pod也必须容忍并发。

### Pod后退失败策略
在某些情况下，由于配置中的逻辑错误等原因，您需要在重试一定次数后使作业失败。为此，请设置.spec.backoffLimit为指定重试次数，然后再将作业视为失败。默认情况下，将退避限制设置为6。与作业相关联的失败Pod由Job控制器重​​新创建，且其指数退避延迟（10s，20s，40s…）限制为六分钟。如果在作业的下一个状态检查之前没有出现新的失败Pod，则会重置退避计数。

> 注意：版本1.12之前的Kubernetes版本仍然存在问题＃54870
> 注意：如果job具有restartPolicy = "OnFailure"，请记住，一旦达到job退避限制，运行job的容器将被终止。这会使调试job的可执行文件更加困难。我们建议restartPolicy = "Never"在调试job或使用日志记录系统时进行设置 ，以确保不会因疏忽而丢失失败的job的输出。

## jobs终止和清理

job完成后，不会再创建其他Pod，但是Pod也不会被删除。将它们保持在周围使您仍然可以查看已完成的容器的日志，以检查是否有错误，警告或其他诊断输出。job对象在完成后也将保留下来，以便您查看其状态。用户可以在注意到旧job的状态后删除它们。用kubectl（例如kubectl delete jobs/pi或kubectl delete -f ./job.yaml）删除job。当您使用删除job时kubectl，它创建的所有窗格也将被删除。

默认情况下，除非Pod失败（restartPolicy=Never）或容器错误退出（restartPolicy=OnFailure），否则Job将不间断运行，此时Job遵循 `.spec.backoffLimit`上述说明。一旦.spec.backoffLimit达到，job将被标记为失败，并且所有正在运行的Pod将被终止。


终止工作的另一种方法是设置有效期限。通过将`.spec.activeDeadlineSeconds`作业字段设置为秒数来执行此操作。该activeDeadlineSeconds适用于工作的持续时间，不管有多少豆荚创建。一旦工作到达activeDeadlineSeconds，所有的运行荚的终止和工作状态将成为type: Failed与reason: DeadlineExceeded。

请注意，作业的`.spec.activeDeadlineSeconds`优先于`.spec.backoffLimit`。因此，重试一个或多个失败Pod的Job一旦达到所指定的时间限制activeDeadlineSeconds，就不会部署其他Pod ，即使backoffLimit尚未达到。

示例：

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-with-timeout
spec:
  backoffLimit: 5
  activeDeadlineSeconds: 100
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
```

请注意，“job”中的“job”规范和Pod模板规范都具有一个activeDeadlineSeconds字段。确保将此字段设置为适当的级别。


请记住，该设置restartPolicy适用于Pod，而不适用于Job本身：Job状态为时，不会自动重新启动Job type: Failed。也就是说，激活了作业终止机制.spec.activeDeadlineSeconds，并.spec.backoffLimit在长期的工作失败，需要人工干预来解决结果。

## 自动清理完成的job
系统中通常不再需要完成job。将它们保留在系统中会给API服务器带来压力。如果job由更高级别的控制器（例如CronJobs）直接管理，则 CronJobs可以基于指定的基于容量的清除策略来清除job。

### 完成job的TTL机制
功能状态： Kubernetes v1.12 α

自动清除完成的作业（Complete或Failed）的另一种方法是通过指定job的字段，使用由TTL控制器提供的TTL机制 处理完成的资源`.spec.ttlSecondsAfterFinished`。

当TTL控制器清理作业时，它将级联删除作业，即与作业一起删除其相关对象（例如Pod）。请注意，删除作业后，将兑现其生命周期保证，例如终结剂。

示例：

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-with-ttl
spec:
  ttlSecondsAfterFinished: 100
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
```

job 完成后几秒钟pi-with-ttl便有资格自动删除100。

如果将该字段设置为0，则job完成后将有资格自动被自动删除。如果未设置该字段，则该job完成后将不会被TTL控制器清除。

请注意，此TTL机制是带有功能门的alpha TTLAfterFinished。

## 工作模式

Job对象可用于支持Pods的可靠并行执行。Job对象并非旨在支持紧密通信的并行过程，就像科学计算中常见的那样。它确实支持并行处理一组独立但相关的工作项。这些可能是要发送的电子邮件，要渲染的帧，要进行代码转换的文件，要扫描的NoSQL数据库中的密钥范围等等。


在复杂的系统中，可能会有多个不同的工作项集。在这里，我们仅考虑用户希望一起管理的一组工作项- 批处理工作。

并行计算有几种不同的模式，每种都有优点和缺点。权衡是：

- 每个工作项只有一个Job对象，而所有工作项只有一个Job对象。后者对于大量工作项更好。前者给用户和系统管理大量Job对象带来了一些开销。
- 与每个Pod可以处理多个工作项相比，创建的pod数等于工作项数。前者通常需要对现有代码和容器进行较少的修改。后者与以前的项目符号类似，因此对于大量工作项而言更好。
- 几种方法使用工作队列。这需要运行队列服务，并对现有程序或容器进行修改以使其使用工作队列。其他方法更容易适应现有的容器化应用程序。

这里总结了这些折衷，第2至4列对应于上述折衷。模式名称也是示例和更详细说明的链接。

|Pattern|Single Job object|Fewer pods than work items?|Use app unmodified?|Works in Kube 1.1|
|---|---|---|---|---|
|Job|Template Expansion||✓|✓|
|Queue with Pod Per Work Item|✓||sometimes|✓|
|Queue with Variable Pod Count|✓|✓||✓|
|Single Job with Static Work Assignment|✓||✓|


当使用指定完成时.spec.completions，由作业控制器创建的每个Pod都具有相同的名称spec。这意味着一个任务的所有Pod将具有相同的命令行和相同的映像，相同的卷以及（几乎）相同的环境变量。这些模式是安排pod在不同事物上工作的不同方法。

下表列出了所需的设置.spec.parallelism，并.spec.completions为每个模式。这W是工作项的数量。


|Pattern|	.spec.completions	|.spec.parallelism|
|---|---|---|
|Job Template Expansion	|1|	should be 1|
|Queue with Pod Per Work Item	|W|	any|
|Queue with Variable Pod Count|	1	|any|
|Single Job with Static Work Assignment|	W|	any|

## 高级用法
### 指定自己的Pod选择器
通常，在创建Job对象时，不指定.spec.selector。创建job时，系统默认逻辑会添加此字段。它选择不会与任何其他job重叠的选择器值。

但是，在某些情况下，您可能需要覆盖此自动设置的选择器。为此，您可以指定.spec.selector job的。

这样做时要非常小心。如果您指定的标签选择器不是该job的广告连播的唯一标签，并且与不相关的广告连播匹配，则该不相关的广告连播的广告连播可能会被删除，或者此job可能会将其他广告连播视为已完成，或者一个或两个job可能拒绝创建Pod或运行完成。如果选择了非唯一选择器，则其他控制器（例如ReplicationController）及其Pod的行为也可能会以不可预测的方式发生。指定时，Kubernetes不会阻止您犯错误.spec.selector。

这是您可能要使用此功能时的示例。

说Job old已经在运行。您希望现有的Pod继续运行，但是您希望它创建的其余Pod使用不同的Pod模板并使Job具有新的名称。您无法更新作业，因为这些字段不可更新。因此，您删除工作old，但离开它的pods运行，使用`kubectl delete jobs/old --cascade=false`。删除它之前，请记下它使用的选择器：

```bash
kubectl get job old -o yaml
```

```yaml
kind: Job
metadata:
  name: old
  ...
spec:
  selector:
    matchLabels:
      controller-uid: a8f3d00d-c6d2-11e5-9f87-42010af00002
  ...
```

然后，使用名称创建一个新的Job，new并显式指定相同的选择器。由于现有的Pod具有标签controller-uid=a8f3d00d-c6d2-11e5-9f87-42010af00002，因此它们也受Job控制new。

您需要manualSelector: true在新作业中指定，因为您没有使用系统通常为您自动生成的选择器。

```yaml
kind: Job
metadata:
  name: new
  ...
spec:
  manualSelector: true
  selector:
    matchLabels:
      controller-uid: a8f3d00d-c6d2-11e5-9f87-42010af00002
  ...
```


新Job本身将具有与uid不同的uid a8f3d00d-c6d2-11e5-9f87-42010af00002。设置 manualSelector: true告诉系统您知道自己在做什么并允许这种不匹配。

## 备择方案
### Pods

当Pod在其上运行的节点重新启动或发生故障时，该Pod将终止并且不会重新启动。但是，一个Job将创建新的Pod来替换终止的Pod。因此，即使您的应用程序只需要一个Pod，我们还是建议您使用Job而不是裸Pod。

### Replication Controller
作业是复制控制器的补充。复制控制器管理预期不会终止的Pod（例如Web服务器），而作业管理预期不会终止的Pod（例如批处理任务）。

### 单个job启动Controller Pod
另一种模式是由单个Job创建一个Pod，然后再创建其他Pod，充当这些Pod的自定义控制器。这样可以提供最大的灵活性，但是入门起来可能有些复杂，并且与Kubernetes的集成较少。

这种模式的一个示例是Job，它启动一个Pod，该Pod运行一个脚本，该脚本依次启动一个Spark主控制器（请参见spark示例），运行一个spark驱动程序，然后进行清理。

这种方法的优点是，整个过程可以保证Job对象的完成，但是可以完全控制创建哪些Pod以及如何将工作分配给它们。




## 注意
`.spec.selector` 一般情况是不添加了，容易报错。[参考文档](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/)  


设置 `ttlSecondsAfterFinished` 参数，可以在执行成功后自动删除, [点击查看官方文档](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/#clean-up-finished-jobs-automatically)

```bash
# 查看帮助
kubectl explain job.spec.ttlSecondsAfterFinished
```

```
kubectl delete job $(kubectl get job -o=jsonpath='{.items[?(@.status.succeeded==1)].metadata.name}')
```
