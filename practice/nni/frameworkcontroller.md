# 基于 FrameworkController 部署nni

https://nni.readthedocs.io/zh/latest/TrainingService/FrameworkControllerMode.html

## 部署 FrameworkController

https://github.com/Microsoft/frameworkcontroller/tree/master/example/run#run-by-kubernetes-statefulset

### 由Kubernetes StatefulSet运行

- 这种方法对于生产来说更好，因为 `StatefulSet` 本身提供了自我修复功能，并且可以确保在任何时间点最多运行一个 `FrameworkController` 实例。
- 用官方图片来演示这个例子。

#### 先决条件

如果k8s集群强制执行 `Authorization`，则需要首先创建一个具有 `FrameworkController` 授予权限的 `ServiceAccount` 。例如，如果集群强制执行 `RBAC` ：

```bash
kubectl create serviceaccount frameworkcontroller --namespace default
kubectl create clusterrolebinding frameworkcontroller \
  --clusterrole=cluster-admin \
  --user=system:serviceaccount:default:frameworkcontroller
```

#### 启动

使用上面的`ServiceAccount`和`k8s inClusterConfig`运行`FrameworkController` ：

使用默认配置运行

```
kubectl create -f frameworkcontroller-with-default-config.yaml
```

`frameworkcontroller-with-default-config.yaml`:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: frameworkcontroller
  namespace: default
spec:
  serviceName: frameworkcontroller
  selector:
    matchLabels:
      app: frameworkcontroller
  replicas: 1
  template:
    metadata:
      labels:
        app: frameworkcontroller
    spec:
      # Using the ServiceAccount with granted permission
      # if the k8s cluster enforces authorization.
      serviceAccountName: frameworkcontroller
      containers:
      - name: frameworkcontroller
        image: frameworkcontroller/frameworkcontroller
        # Using k8s inClusterConfig, so usually, no need to specify
        # KUBE_APISERVER_ADDRESS or KUBECONFIG
        #env:
        #- name: KUBE_APISERVER_ADDRESS
        #  value: {http[s]://host:port}
        #- name: KUBECONFIG
        #  value: {Pod Local KubeConfig File Path}
```

使用自定义配置运行

```bash
kubectl create -f frameworkcontroller-customized-config.yaml
kubectl create -f frameworkcontroller-with-customized-config.yaml
```

`frameworkcontroller-customized-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frameworkcontroller-config
  namespace: default
data:
  frameworkcontroller.yaml: |
    kubeClientQps: 200
    kubeClientBurst: 300
    workerNumber: 500
    largeFrameworkCompression: true
    frameworkCompletedRetainSec: 2592000
    #podFailureSpec:
    #- code: 221
    #  phrase: ContainerTensorflowOOMKilled
    #  type:
    #    attributes: [Permanent]
    #  podPatterns:
    #  - containers:
    #    - messageRegex: '(?msi)tensorflow.*ResourceExhaustedError.*OOM.*'
    #      codeRange: {min: 1}
    #      nameRegex: '(?ms).*'
    #- {More customized podFailureSpec, better to also include these in the default config}
```

`frameworkcontroller-with-customized-config.yaml`:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: frameworkcontroller
  namespace: default
spec:
  serviceName: frameworkcontroller
  selector:
    matchLabels:
      app: frameworkcontroller
  replicas: 1
  template:
    metadata:
      labels:
        app: frameworkcontroller
    spec:
      # Using the ServiceAccount with granted permission
      # if the k8s cluster enforces authorization.
      serviceAccountName: frameworkcontroller
      containers:
      - name: frameworkcontroller
        image: frameworkcontroller/frameworkcontroller
        # Using k8s inClusterConfig, so usually, no need to specify
        # KUBE_APISERVER_ADDRESS or KUBECONFIG
        #env:
        #- name: KUBE_APISERVER_ADDRESS
        #  value: {http[s]://host:port}
        #- name: KUBECONFIG
        #  value: {Pod Local KubeConfig File Path}
        command: [
          "bash", "-c",
          "cp /frameworkcontroller-config/frameworkcontroller.yaml . &&
          ./start.sh"]
        volumeMounts:
        - name: frameworkcontroller-config
          mountPath: /frameworkcontroller-config
      volumes:
      - name: frameworkcontroller-config
        configMap:
          name: frameworkcontroller-config
```
