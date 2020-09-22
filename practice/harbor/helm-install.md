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

### helm harbor 1.4.1版本之前有权限问题
> 注意： 1.4.2下面的init容器还需要重新修改一下
>       daemon.json，和证书的下载需要匹配一下，其余的跟compose使用类似

redis数据目录，/var/lib/redis，需要设置redis的用户及用户组权限

```yaml
      initContainers:
      - name: "change-permission-of-directory"
        image: {{ .Values.database.internal.initContainerImage.repository }}:{{ .Values.database.internal.initContainerImage.tag }}
        imagePullPolicy: {{ .Values.imagePullPolicy }}
        command: ["/bin/sh"]
        args: ["-c", "chown -R 999:999 /var/lib/redis"]
        volumeMounts:
        - name: data
          mountPath: /var/lib/redis
          subPath: {{ $redis.subPath }}
```

踩坑二：registry组件的镜像存储目录权限导致镜像推送失败

registry的镜像存储目录，需要设置registry用户的用户及用户组，不然镜像推送失败

```yaml
      initContainers:
      - name: "change-permission-of-directory"
        image: {{ .Values.database.internal.initContainerImage.repository }}:{{ .Values.database.internal.initContainerImage.tag }}
        imagePullPolicy: {{ .Values.imagePullPolicy }}
        command: ["/bin/sh"]
        args: ["-c", "chown -R 10000:10000 {{ .Values.persistence.imageChartStorage.filesystem.rootdirectory }}"]
        volumeMounts:
        - name: registry-data
          mountPath: {{ .Values.persistence.imageChartStorage.filesystem.rootdirectory }}
          subPath: {{ .Values.persistence.persistentVolumeClaim.registry.subPath }}
```

踩坑三：chartmuseum存储目录权限，导致chart推送失败

```yaml
      initContainers:
      - name: "change-permission-of-directory"
        image: {{ .Values.database.internal.initContainerImage.repository }}:{{ .Values.database.internal.initContainerImage.tag }}
        imagePullPolicy: {{ .Values.imagePullPolicy }}
        command: ["/bin/sh"]
        args: ["-c", "chown -R 10000:10000 /chart_storage"]
        volumeMounts:
        - name: chartmuseum-data
          mountPath: /chart_storage
          subPath: {{ .Values.persistence.persistentVolumeClaim.chartmuseum.subPath }}
```
