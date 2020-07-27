# 安装metrics-server

[sig-GitHub地址](https://github.com/kubernetes-sigs/metrics-server)  
[官方github目录](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/metrics-server)  

由于官方的有些yaml文件使用了模版形式, 仓库把那些模版给注释了  

[auth-delegator.yaml](https://kubernetes.hankbook.cn/manifests/example/metrics-server/auth-delegator.yaml)  
[auth-reader.yaml](https://kubernetes.hankbook.cn/manifests/example/metrics-server/auth-reader.yaml)  
[metrics-server-deployment.yaml](https://kubernetes.hankbook.cn/manifests/example/metrics-server/metrics-server-deployment.yaml)  
[metrics-server-service.yaml](https://kubernetes.hankbook.cn/manifests/example/metrics-server/metrics-server-service.yaml)  
[metrics-apiservice.yaml](https://kubernetes.hankbook.cn/manifests/example/metrics-server/metrics-apiservice.yaml)  
[resource-reader.yaml](https://kubernetes.hankbook.cn/manifests/example/metrics-server/resource-reader.yaml)  

安装
```bash
# 下载所有文件到本地
kubectl -f ./metrics-server/
```
以下是官方
```bash
# 使用官方的，需要自行注释或修改配置文件
git clone https://github.com/kubernetes/kubernetes.git
cd cluster/addons/
# 因为是谷歌镜像， 所以可能被墙，使用阿里云的镜像进行替换
sed -i 's#k8s.gcr.io#registry.cn-hangzhou.aliyuncs.com/google_containers#g' metrics-server/metrics-server-service.yaml
kubectl -f ./metrics-server/
```
下面的请求使用的是basic的方式进行请求，如有必要修改成token或者密钥即可
```bash
# node
curl https://kubernetes.default.svc.cluster.local:6443/apis/metrics.k8s.io/v1beta1/nodes -k --basic -u admin:admin
# pod
curl https://kubernetes.default.svc.cluster.local:6443/apis/metrics.k8s.io/v1beta1/pod -k --basic -u admin:admin
```

## FAQ

执行`kubectl top node`报错权限不够

```
**[terminal]
[root@k8s01 ~]# kubectl top node
Error from server (Forbidden): nodes.metrics.k8s.io is forbidden: User "system:kube-proxy" cannot list resource "nodes" in API group "metrics.k8s.io" at the cluster scope
```

原因1： kubectl 的上下文设置有问题，主要是因为部署`kube-proxy`设置的上下文

```bash
/usr/local/bin/kubectl  config use-context default --kubeconfig=kube-proxy.kubeconfig
```

确认 `config`的配置文件是admin即可，默认查看文件`~/.kube/config`

原因2： `metircs server` 用了`system:kube-proxy`这个 `clusterrole` ，但是没有 `clusterrole`

下面的yaml是创建 `ClusterRoleBinding`，注释的原因是因为权限不足，而 `admin` 的权限太高。需要再优化一下  
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-proxy
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
  #name: system:kube-proxy
subjects:
- kind: User
  name: system:kube-proxy
  namespace: kube-system
```

查看 [rbac文档](https://kubernetes.hankbook.cn/api-overview/rbac.html)  
