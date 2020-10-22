# 制作最简单的http服务

## go代码

```go
package main

import (
	"fmt"
	"net/http"
)

func helloHello(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintln(w, "Hello world!")
}

func main() {
	http.HandleFunc("/", helloHello)
	err := http.ListenAndServe(":9090", nil)
	if err != nil {
		fmt.Printf("http server failed, err:%v\n", err)
		return
	}
}
```

## 编译代码

dockerfile的另外一种写法，此方案使用多个`FROM `方便很多编译的做法， 例如在A镜像中编译vue的代码，然后把生成后的镜像文件直接拷贝到新的容器当中，这样能保证镜像的最小化

```
# stage 1: build src code to binary
FROM golang:1.13-alpine3.10 as builder

COPY *.go /app/

RUN cd /app && go build -o helloworld .

# stage 2: use alpine as base image
FROM alpine:3.10

RUN apk update && \
    apk --no-cache add tzdata ca-certificates && \
    cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*
# 使用--from的参数做到拷贝使用
COPY --from=builder /app/helloworld /helloworld

CMD ["/helloworld"]
```

```bash
docker build -t hank997/go-helloworld:v1 .
docker run -it --rm -p 9090:9090 hank997/go-helloworld:v1
```

## 编写yaml

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: test-go-http-pod
spec:
  containers:
  - name: test-go-http-pod
    image: hank997/go-helloworld:v1
    ports:
    - containerPort: 9090

---
# service
apiVersion: v1
kind: Service
metadata:
  name: test-go-http-service
  labels:
    name: go
spec:
  ports:
  - port: 9090
    protocol: TCP
    targetPort: 9090
    name: go-http
    nodePort: 31221
  type: NodePort
  selector:
    name: test-go-http-pod
```

## 制作kubectl命令工具

先出门左拐到官方地址去下载自己所需要的kubectl对应版本的二进制

Dockerfile制作
```
FROM alpine
COPY kubectl /usr/bin
```

```bash
# 我仓库里面暂时只有1.15.9的镜像, 推荐二进制等命令都到官方下载，防止被人串改
docker build -t hank997/kubectl:1.15.9 .

```

kube的 secret 制作

```bash
# key应该跟下面的subpath一致
kubectl -n devops-ns create secret generic kube-config --from-file=config=/root/.kube/config
```

测试demo yaml，此步骤是为了自己测试使用

```yaml
# 此方案还可以使用挂载.kube/config的文件到pod内部，也是可以使用差点
apiVersion: v1
kind: Pod
metadata:
  name: kubectl
  namespace: devops-ns
  labels:
    env: test
spec:
  serviceAccountName: cicd-sa
  containers:
  - name: kubectl
    image: hank997/kubectl:1.15.9
    imagePullPolicy: IfNotPresent
    command: ["sleep"， “3600”]
    resources:
      requests:
        memory: "100Mi"
        cpu: "100m"
      limits:
        memory: "500Mi"
        cpu: "500m"
---
# 创建 ServiceAccount，并且绑定最高权限
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubectl
  name: kubectl
  namespace: devops-ns
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: kubectl-rolebind
  annotations:
    # 查看介绍 https://kubernetes.io/docs/reference/access-authn-authz/rbac/#auto-reconciliation
    rbac.authorization.kubernetes.io/autoupdate: "true"
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: kubectl
  namespace: devops-ns
```
测试`kubectl get pod`命令
```bash
kubectl -n devops-ns exec -it  kubectl kubectl get pod
```


## pipeline
pipeline语法 https://www.w3cschool.cn/jenkins/jenkins-jg9528pb.html

插件地址： https://github.com/jenkinsci/kubernetes-plugin

此处使用了 `docker in docker`的模式操作，所以需要挂载一个socket进行使用

如果使用到了nvidia的话，请加上`environment`指令

在`podTemplate`下面加上使用的`serviceAccount`的名称，`serviceAccount: "kubectl"`，并且，上面使用的是`cluster-admin`的权限，需要自行注意使用`rbac`的方式

`  secretVolume(secretName: 'kube-config',mountPath: "/root/.kube", subPath:"config")`原本volumes是加上这句话，使用挂载的方式，这种不太友好

```
**[terminal]
def label = "worker-${UUID.randomUUID().toString()}"

podTemplate(label: label, serviceAccount: "kubectl",containers: [
  containerTemplate(name: 'docker', image: 'docker', command: 'cat', ttyEnabled: true),
  containerTemplate(name: 'kubectl', image: 'hank997/kubectl:1.15.9', command: 'cat', ttyEnabled: true)
],
volumes: [
  hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock')
]) {
  node(label) {
    stage("check out"){git  credentialsId: '3c210def-c000-5d2a-9b2d-838986a6b1sd', url: 'https://github.com/AgoCan/go-helloworld.git'}
    stage('Create Docker images') {
      container('docker') {
          sh """
            docker login -u admin --password Harbor12345
            docker build -t hank997/hello-go:v2 .
            docker push hank997/hello-go:v2
            """

      }
    }
    stage("kubectl"){
        container('kubectl') {
            sh """
            kubectl set images  pod/test-go-http-pod test-go-http-pod=hank997/hello-go:v2
            """
        }
            //sh "kubectl set images pod/test-go-http-pod test-go-http-pod=hank997/hello-go:v2"
    }
  }
}
```

### 补充

nginx 使用环境变量加入pod当中

```
image: nginx:stable-alpine
env: HANK_HOST
cmd:  /bin/sh -c "envsubst '$$HANK_HOST' < /etc/nginx/conf.d/hank.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
```

配置文件

```
server: {HANK_HOST};
```


## faq
alpine镜像出现下面的问题
```
/bin/sh docker command not found
```

```
apk add --no-cache libc6-compat
```
