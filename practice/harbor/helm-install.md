# helm部署harbor
> 注意： 测试不成功，并且文档比较乱

github： https://github.com/goharbor

此处利用helm进行部署

```bash
# helm repo add harbor https://helm.goharbor.io

git  clone https://github.com/goharbor/harbor-helm.git
# 切换到包分支
git checkout chart-repository
# 找到自己想要的版本，并且进行解压
```

解压之后，记得创建`pv`和修改`pvc`。`vim values.yaml`,使用"storageclass"


**前提使用storageclass，出门左拐找文档**

```bash
# 注释掉pvc名称existingClaim
#sed -i 's@existingClaim:@#existingClaim:@g' values.yaml
# 设置storageclass的默认
kubectl patch storageclass managed-nfs-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
# 不设置默认，获取storageclass
kubectl get storageclass
# 并且修改values.yaml
```

**使用静态pvc**
创建静态pvc对应的nfs目录，配置好`values.yaml`下的`existingClaim`配置文件
```bash
mkdir -p /data/harbor/chartmuseum
mkdir -p /data/harbor/registry
mkdir -p /data/harbor/jobservice
mkdir -p /data/harbor/database
mkdir -p /data/harbor/redis
cat >> /etc/exports << EOF
/data/harbor/chartmuseum  10.10.10.0/24(rw,sync,no_root_squash)
/data/harbor/database     10.10.10.0/24(rw,sync,no_root_squash)
/data/harbor/jobsservice  10.10.10.0/24(rw,sync,no_root_squash)
/data/harbor/redis        10.10.10.0/24(rw,sync,no_root_squash)
/data/harbor/register     10.10.10.0/24(rw,sync,no_root_squash)
EOF
```
需要手动创建pvc
```yaml
persistence:
  persistentVolumeClaim:
    registry:
      existingClaim: "harbor-chartmuseum"
# 剩下的配置想都是一样的。
```

`helm` 默认使用的是 `ingress` ，如果不使用，或者使用 `nodeport` 的方式，请在一开始修改 `expose`

[ingress文档](/service-discovery/chapter02.md)

```bash
kubectl create ns harbor
#helm2
helm install --name=harbor  .
#helm3
helm install harbor -n harbor .
```

删除
```bash
#helm2
helm delete --purge harbor
#helm3
helm uninstall -n harbor harbor
kubectl delete pvc data-harbor-harbor-redis-0
kubectl delete pvc harbor-harbor-chartmuseum
kubectl delete pvc harbor-harbor-jobservice
kubectl delete pvc harbor-harbor-registry
kubectl delete pvc database-data-harbor-harbor-database-0
```
