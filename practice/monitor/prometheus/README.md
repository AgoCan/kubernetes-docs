# prometheus

>  需要非常注意时间同步问题，会导致取不到数据


[官网](https://prometheus.io/)
[coreos/kube-prometheus:github](https://github.com/coreos/kube-prometheus)
[coreos/prometheus-operator:github](https://github.com/coreos/prometheus-operator)

```bash
# 安装prometheus-operator
git clone https://github.com/coreos/prometheus-operator.git
# 创建prometheus-operator的pod
cd prometheus-operator
kubectl apply -f bundle.yaml
# 确认pod运行，以及我们可以发现operator的pod在有RBAC下创建了一个APIService
kubectl get pod
# 查看service
kubectl get --raw /apis/monitoring.coreos.com/v1
# 这个是因为bundle.yml里有如下的CLusterRole和对应的ClusterRoleBinding来让prometheus-operator有权限对monitoring.coreos.com这个apiGroup里的这些CRD进行所有操作

```


[参考文档](servicemesher.com/blog/prometheus-operator-manual/)


https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config
