# 基于helm3部署方式  
## 部署普罗米修斯  

前提部署好[helm](/practice/helm/README.md)

```bash
# 克隆helm的官方charts
git clone https://github.com/helm/charts.git
# 克隆的仓库主要会出现一些错误
# helm3 添加仓库
helm repo add stable https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
# 直接部署
# 官方仓库站点https://hub.kubeapps.com/charts/stable/prometheus
cd charts
vim stable/prometheus/values.yaml
```

修改`service`类型，使其可以访问，如有`ingress`可自行修改`values.yaml`  
**提示： 使用nodeport的时候，需要把cluster： None 给删掉**    
**请添加的时候使用英文注释**  

修改后`values.yaml`
```yaml
alertmanager:
  persistentVolume:
    # 修改成false，使用empty做测试使用，如有需要长期保存，请使用默认。并且撞见pvc
    enabled: false    # values.yaml 168行左右
  service:
    type: NodePort
    nodePort: 32001  # 300行
server:
  persistentVolume:
    # 修改成false，使用empty做测试使用，如有需要长期保存，请使用默认。并且撞见pvc
    enabled: false   # 764行
  service:
    servicePort: 80
    nodePort: 32002        # 914 行     
    type: NodePort
pushgateway:
  ## If false, pushgateway will not be installed
  ##
  enabled: false      # 936
```

---
> 最新测试
```bash
[root@test15 prometheus]# helm install prometheus --namespace monitor stable/prometheus
Error: found in Chart.yaml, but missing in charts/ directory: kube-state-metrics
```
解决方案就是
cd stable/prometheus
mkdir charts
cp -a ../kube-state-metrics charts
---

```bash
kubectl create ns monitor
# 如有需要可加上 --tls
# helm3
helm install prometheus --namespace monitor stable/prometheus
# helm2
#helm install --name prometheus --namespace prometheus-ns stable/prometheus
```
删除
```bash
# helm3
helm uninstall -n monitor prometheus
# helm2
#helm del prometheus --purge
```

## 部署grafana
前提部署好`helm`
```bash
# 修改values.yaml
vim stable/grafana/values.yaml
```

```yaml
service:
  type: NodePort
  nodePort: 32000   # 120 行

adminUser: admin
adminPassword: admin  # 228行，此处测试，既使用简单密码

```
下载地址模板地址，推荐使用`json`导入 https://grafana.com/grafana/dashboards/8588  
或者直接打开  [下载地址](https://grafana.com/api/dashboards/8588/revisions/1/download)  

```bash
# helm3
helm install grafana -n monitor stable/grafana
# helm2
# 如有需要可加上 --tls
#helm install  --name grafana --namespace prometheus-ns stable/grafana
```

打印密码

```bash
# 要是自定义了密码，就可以不使用下面的命令。虽然它也是能打印出来admin
kubectl get secret --namespace monitor grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```
删除
```bash
# helm3
helm unstall -n monitor grafana
# helm2
helm del grafana --purge
```
