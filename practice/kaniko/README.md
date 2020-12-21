# kaniko

## 利用kaniko构建镜像
### 操作日志
创建dockerfile
```bash
mkdir /data/tmp
cat > /data/tmp/Dockerfile << EOF
FROM busybox
ENV a=123
EOF
```

创建认证信息，该认证信息就是`docker login生成的`
```
kubectl create secret generic regcred --from-file=/root/.docker/config.json
```

创建pv

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: dockerfile
  labels:
    type: local
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  hostPath:
    path: /data/tmp
```

创建pvc
```yaml

kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: dockerfile-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
  storageClassName: local-storage
```

创建pod，pod会直接开始构建镜像

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kaniko
spec:
  containers:
  - name: kaniko
    #image: gcr.io/kaniko-project/executor:latest
    image: hank997/kaniko-executor:latest
    args: ["--dockerfile=/workspace/Dockerfile",
            "--context=dir://workspace",
            "--destination=hank997/busybox:test"] # replace with your dockerhub account
    volumeMounts:
      - name: kaniko-secret
        mountPath: /kaniko/.docker
      - name: dockerfile-storage
        mountPath: /workspace
  restartPolicy: Never
  volumes:
    - name: kaniko-secret
      secret:
        secretName: regcred
        items:
          - key: config.json
            path: config.json
    - name: dockerfile-storage
      persistentVolumeClaim:
        claimName: dockerfile-claim
```
查看日志
```
kubectl logs kaniko
```

### 介绍

- 参考文档： https://github.com/GoogleContainerTools/kaniko
