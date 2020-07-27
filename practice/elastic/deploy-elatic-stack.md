# 部署efk (elasticsearch部署已经失败，暂时未测试成功)

前提： 部署好helm，并且该项目下的命名空间都一致。不然fluentd和kibana都需要指定以下service

部署`elk`需要空虚的内存准备至少4g,cpu1核以上。
如果是刚好4g的空间，请吧其他的服务都关闭了，


```
git clone https://github.com/helm/charts.git
```

## 部署elasticsearch

```
vim charts/elasticsearch/values.yaml
```

```yaml
master:
  name: master
  exposeHttp: false
  replicas: 3
  heapSize: "512m"
  # additionalJavaOpts: "-XX:MaxRAM=512m"
  persistence:
    # line 178 ,default is true , change it to false,修改此行，不启用pv,178行
    enabled: false
    accessMode: ReadWriteOnce
    name: data
    size: "4Gi"
    # storageClass: "ssd"

...

data:
  name: data
  exposeHttp: false
  replicas: 2
  heapSize: "1536m"
  # additionalJavaOpts: "-XX:MaxRAM=1536m"
  persistence:
    # line 232 ,default is true , change it to false,修改此行，不启用pv，232行
    enabled: false
    accessMode: ReadWriteOnce
    name: data
    size: "30Gi"
    # storageClass: "ssd"
```

部署

```
helm install --name elasticsearch --namespace elastic-ns stable/elasticsearch
```

操作
```
export POD_NAME=$(kubectl get pods --namespace elastic-ns -l "app=elasticsearch,component=client,release=elasticsearch" -o jsonpath="{.items[0].metadata.name}")
echo "Visit http://127.0.0.1:9200 to use Elasticsearch"
kubectl port-forward --namespace elastic-ns $POD_NAME 9200:9200
```
删除

```
helm del elasticsearch --purge
```


## 部署fluentd
fluentd是cncf基金的一个项目,并且是第六个毕业的项目  
[官方地址](https://www.fluentd.org/)  
```
vim stable/fluentd-elasticsearch/values.yaml

```
镜像地址自行替换
```
gcr.io/google-containers/fluentd-elasticsearch:v2.3.2
registry.cn-hangzhou.aliyuncs.com/google_containers/fluentd-elasticsearch:v2.3.2
```
并且根据自己的namespace修改里面url的值
```

```

部署
```
helm install --name fluentd-elasticsearch --namespace elastic-ns stable/elasticsearch
```

删除

```
helm del fluentd-elasticsearch --purge
```


## 部署kibana

`vim stable/kubana/values.yaml`

修改`service`,或者使用ingress的，既打开ingress为`true`

根据namespace修改url的值,其中注释都已经说明，只需要打开注释并且修改值即可

```yaml
# line 14
env:
  ELASTICSEARCH_HOSTS: http://elasticsearch.elastic-ns.svc.cluster.local:9200
# line 41
files:
  kibana.yml:
    ## Default Kibana configuration from kibana-docker.
    server.name: kibana
    server.host: "0"
    ## For kibana < 6.6, use elasticsearch.url instead
    elasticsearch.hosts: http://elasticsearch.elastic-ns.svc.cluster.local:9200
```


部署
```
helm install --name kibana --namespace elastic-ns stable/elasticsearch
```

删除

```
helm del kibana --purge
```
