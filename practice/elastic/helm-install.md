# helm3部署
> 前提： 集群内部署好helm3，并且此次测试的k8s版本是1.19.1

## 参考文档
此次放前，因为经常改动，以文档为主
- [github的官方chats](https://github.com/elastic/helm-charts)
- [helm官方文档](https://hub.helm.sh/charts/elastic/elasticsearch)

## 部署

```bash
# 添加源
helm repo add elastic https://helm.elastic.co
helm repo update
# 创建命名空间
kubectl create namespace logging
# 拉取chart查看
#helm pull  --version 7.9.1 elastic/elasticsearch
#tar xf elasticsearch-7.9.1.tgz
#cd elasticsearch/
# 创建需要default的 storageclass
#helm install -n logging elasticsearch .
# 也可以直接创建
helm install -n logging --version 7.9.1 elasticsearch elastic/elasticsearch \
--set esJavaOpts="-Xmx1g -Xms1g" \
--set resources.limits.cpu="1000m" \
--set resources.limits.memory="2Gi" \
--set nodeSelector.type="elk" \
--set volumeClaimTemplate.storageClassName="managed-nfs-storage" \
--set replicas=3

# 卸载
helm uninstall -n logging elasticsearch

```

## 部署kibana

```
helm install -n logging --version 7.9.1 kibana elastic/kibana \
--set resources.requests.memory=2Gi \
--set resources.limits.memory=2Gi \
--set service.type=NodePort
```

## 部署fluent-bit

```
helm repo add fluent https://fluent.github.io/helm-charts
helm install fluent-bit -n logging --version 0.7.13 fluent/fluent-bit
helm show values fluent/fluent-bit
```



## FAQ
如果docker的目录不是默认目录，则需要把相对应的docker目录给挂在到fluent里面去。不然会获取不到日志内容

例如
```
ln -s /data/docker /var/lib/docker
# 就需要把 /data/docker挂在到fluent下面去
```

因为kubernetes的日志是挂载docker的容器信息到
```
/data/docker/containers -> /var/log/pods/  -> /var/log/containers
```
参考文档：

https://docs.fluentbit.io/manual/installation/kubernetes

https://artifacthub.io/packages/helm/elastic/elasticsearch

https://artifacthub.io/packages/helm/bitnami/kibana

https://artifacthub.io/packages/helm/fluent/fluent-bit
