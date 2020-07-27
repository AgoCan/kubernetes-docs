# coredns
官网  https://coredns.io  
github  https://github.com/coredns/coredns  https://github.com/coredns/deployment/tree/master/kubernetes  

```bash
git clone https://github.com/coredns/deployment.git
cd deployment/kubernetes
# 此处ip跟前面的配置文件一致
yum install jq -y
./deploy.sh -i 10.96.0.2 > coredns.yaml
```
- 需要修改clusterIP地址。  
- 10.96.0.2 跟kubelet一致  
- 还需要修改一部分的内容  

完整修改后的 [coredns.yaml](https://kubernetes.hankbook.cn/manifests/example/coredns/coredns.yaml)  

修改完之后，使用 `apply` 执行

```bash
kubectl apply -f coredns.yaml
kubectl patch deployment -n kube-system coredns -p '{"spec":{"replicas":2}}'
# 或者使用
kubectl scale deployment -n kube-system coredns –replicas=5
```

# dashboard

### 5. 部署dashboard

github： https://github.com/kubernetes/dashboard

官网文档： https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/  
这是token账户的地址  
https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md  

```bash
# 提示，版本好选择好，版本号就是tag的值，
# 不能下载的时候可以使用 https://github.com/kubernetes/dashboard/blob/master/aio/deploy/recommended.yaml
# https://github.com/kubernetes/dashboard/blob/v2.0.0-rc5/aio/deploy/recommended.yaml
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta6/aio/deploy/recommended.yaml
# 修改成nodeport的方式，然后使用
kubectl apply -f recommended.yaml

```

修改成nodeport进行访问, 也可以自己修改内容后进行apply的时候使用

```bash
kubectl patch svc -n kubernetes-dashboard kubernetes-dashboard -p '{"spec":{"type":"NodePort"}}'
kubectl patch svc -n kubernetes-dashboard kubernetes-dashboard -p '{"spec":{"ports":[{"nodePort":30001,"port":443}]}}'
```


设置token的账户
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
```
获取token
```bash
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
```



# helm

[helm](/practice/helm/README.md)  

# metrics

[metrics-server](/practice/monitor/metrics-server.md)
