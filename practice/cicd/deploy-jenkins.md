# 直接裸docker启动

该镜像多了个`sudo`免密的功能和部署了`node`客户端

```bash
docker run -itd --restart always -p 8080:8080 -v /data/hank-jenkins:/var/jenkins_home -v /usr/bin/docker:/usr/bin/docker -v /var/run/docker.sock:/var/run/docker.sock hank997/jenkins:2019.10.24
```

咱们过这种方案，接下来使用`helm`的方式进行部署

# helm部署

```bash
# 克隆helm的官方charts
git clone https://github.com/helm/charts.git
cd charts
# 修改values.yaml
# 自行修改
```

是否使用`pvc`, 测试阶段暂时关闭pvc，会导致安装插件失败（重启后`containerd`重置）

```yaml
# line 479
persistence:
  enabled: false
```

修改`serviceType`

```
serviceType: NodePort
```


部署

```bash
helm install --name jenkins --namespace devops-ns stable/jenkins
```

打印密码

```bash
printf $(kubectl get secret --namespace devops-ns jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```

删除

```bash
helm del jenkins --purge
```


## values部分介绍
默认插件

```yaml
  installPlugins:
    - kubernetes:1.21.2
    - workflow-job:2.36
    - workflow-aggregator:2.6
    - credentials-binding:1.20
    - git:4.0.0
```
`kubernetes cli` 插件的使用  
https://wiki.jenkins.io/display/JENKINS/Kubernetes+CLI+Plugin  
https://plugins.jenkins.io/kubernetes-cli  

`ingress`的`hostname`，可以不配置



```yaml
ingress:
  hostName: jenkins.example.com
```

默认管理员账号密码

```yaml
  adminUser: "admin"
  adminPassword: "admin123"
```

设置`storageClass`

```yaml
persistence:
  storageClass:
```
