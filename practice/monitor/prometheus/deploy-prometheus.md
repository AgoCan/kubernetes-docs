# 基于helm3部署方式
依赖：
Kubernetes 1.16+
Helm 3+

*保证好服务器的时间同步*

## 部署普罗米修斯

前提部署好[helm](/practice/helm/README.md)

### 使用helm部署
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# 官方charts在外网，使用阿里云源
#helm repo add stable https://charts.helm.sh/stable
helm repo add stable https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
helm repo update
# 创建命名空间
kubectl create ns monitor
# 测试使用所以把pvc给关了,并且把pushgateway给关闭了, kube-state-metrics默认打开的
helm install prometheus -n monitor --version 13.0.1 prometheus-community/prometheus \
--set alertmanager.persistentVolume.enabled=false \
--set alertmanager.service.type=NodePort \
--set server.persistentVolume.enabled=false \
--set server.service.type=NodePort \
--set pushgateway.enabled=false \
--set kubeStateMetrics.enabled=true \
--set server.retention=72h
# 卸载
helm uninstall -n monitor prometheus
```

## 部署grafana
前提部署好`helm`
### 使用helm部署
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana -n monitor --version 6.1.16 grafana/grafana \
--set service.type=NodePort \
--set adminUser=admin \
--set adminPassword=admin \
--set persistence.enabled=false
# 卸载
helm uninstall grafana -n monitor
```

下载地址模板地址，推荐使用`json`导入 https://grafana.com/grafana/dashboards/8588
或者直接打开  [下载地址](https://grafana.com/api/dashboards/8588/revisions/1/download)

打印密码
```bash
# 要是自定义了密码，就可以不使用下面的命令。虽然它也是能打印出来admin
kubectl get secret --namespace monitor grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

- https://artifacthub.io/packages/helm/prometheus-community/prometheus
- https://artifacthub.io/packages/helm/grafana/grafana
