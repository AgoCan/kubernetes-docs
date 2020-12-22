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
helm install fluent-bit fluent/fluent-bit
helm show values fluent/fluent-bit
```
