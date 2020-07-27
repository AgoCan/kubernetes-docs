# CronJob(定时任务)
> FEATURE STATE: Kubernetes v1.8 beta

Cron Job 创建基于时间调度的 Jobs。

一个 CronJob 对象就像 crontab (cron table) 文件中的一行。它用 Cron 格式进行编写，并周期性地在给定的调度时间执行 Job。

> 注意： 所有 CronJob 的 schedule: 时间都是基于初始 Job 的主控节点的时区。

为 CronJob 资源创建清单时，请确保创建的名称不超过 52 个字符。这是因为 CronJob 控制器将自动在提供的作业名称后附加 11 个字符，并且存在一个限制，即作业名称的最大长度不能超过 63 个字符。

## demo
编写一个demo的job，随时测试使用


```yaml
apiVersion: batch/v2alpha1
kind: CronJob
metadata:
  name: cronjob-demo
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: demo
            image: busybox
            args:
            - "bin/sh"
            - "-c"
            - "for i in {1..10}; do echo $i; done"
```

## CronJob 限制
CronJob 创建 Job 对象，每个 Job 的执行次数大约为一次。 我们之所以说 “大约”，是因为在某些情况下，可能会创建两个 Job，或者不会创建任何 Job。 我们试图使这些情况尽量少发生，但不能完全杜绝。因此，Job 应该是 \_幂等的_。

如果 `startingDeadlineSeconds` 设置为很大的数值或未设置（默认），并且 `concurrencyPolicy` 设置为 Allow，则作业将始终至少运行一次。

对于每个 CronJob，CronJob 控制器 检查从上一次调度的时间点到现在所错过了调度次数。如果错过的调度次数超过 100 次，那么它就不会启动这个任务，并记录这个错误:

```
Cannot determine if job needs to be started. Too many missed start time (> 100). Set or decrease .spec.startingDeadlineSeconds or check clock skew.
```

需要注意的是，如果 `startingDeadlineSeconds` 字段非空，则控制器会统计从 `startingDeadlineSeconds` 设置的值到现在而不是从上一个计划时间到现在错过了多少次 Job。例如，如果 `startingDeadlineSeconds` 是 200，则控制器会统计在过去 200 秒中错过了多少次 Job。

如果未能在调度时间内创建 CronJob，则计为错过。例如，如果 `concurrencyPolicy` 被设置为 Forbid，并且当前有一个调度仍在运行的情况下，试图调度的 CronJob 将被计算为错过。

例如，假设一个 CronJob 被设置为 `08:30:00` 准时开始，它的 `startingDeadlineSeconds` 字段被设置为 10，如果在 `08:29:00` 时将 CronJob 控制器的时间改为 `08:42:00`，Job 将不会启动。 如果觉得晚些开始比没有启动好，那请设置一个较长的 `startingDeadlineSeconds`。

为了进一步阐述这个概念，假设将 CronJob 设置为从 `08:30:00` 开始每隔一分钟创建一个新的 Job，并将其 `startingDeadlineSeconds` 字段设置为 200 秒。 如果 CronJob 控制器恰好在与上一个示例相同的时间段（`08:29:00` 到 `10:21:00`）停机，则 Job 仍将从 `10:22:00` 开始。造成这种情况的原因是控制器现在检查在最近 200 秒（即 3 个错过的调度）中发生了多少次错过的 Job 调度，而不是从现在为止的最后一个调度时间开始。
