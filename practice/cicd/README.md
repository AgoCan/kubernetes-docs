# cicd

[fluxcd-argocd-jenkins-x-gitops-tools](https://blog.container-solutions.com/fluxcd-argocd-jenkins-x-gitops-tools)

## empty

代码上线可以使用一个两个镜像的方式。一个镜像长期不变，而另外一个pod使用set的方式进行替换。
[empty.yaml](https://kubernetes.hankbook.cn/manifests/example/cicd/empty.yaml)此yaml是一个init加上移动代码的逻辑，与上面的说法不符，是另外一种方式，init容器进行构建，而主容器不进行改变

https://docs.docker.com/config/pruning/

```bash
# 删除没有被引用镜像
docker image prune -a --filter "until=24h"
```


官方中文文档： https://jenkins.io/zh/doc/tutorials/

jenkins参考文档 https://www.jianshu.com/p/57977e69613f


# 关于上线的小事
上线遇见的小事记录
## 有些业务，会要长期占有线程，比如3小时，而上线默认的时间是30秒就把pod给删除了。

解决方案：

## 关于替换configmap的热更新问题
configmap除了挂载目录是可以热更新，而环境变量和subpath（挂载单独文件）的方式是不能热更新的

解决方案：

1. 更新完configmap之后，patch更新一下pod(或者其他例如deployment)的annotations字段

##
