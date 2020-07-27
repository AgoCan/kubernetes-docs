# log-pilot+ES+Kibana环境搭建

## 创建serviceAccount

如果之前没有创建过dashboard-admin 需要先创建serviceAccount

```bash
kubectl create sa dashboard-admin -n kube-system
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin
ADMIN_SECRET=$(kubectl get secrets -n kube-system | grep dashboard-admin | awk '{print $1}')
kubectl describe secret -n kube-system ${ADMIN_SECRET} |grep -E '^token' |awk '{print $2}'
```

## 安装 elasticsearch

```bash
kubectl apply -f elasticsearch_pvc.yaml
```

elasticsearch_pvc.yaml内容

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-api
  namespace: kube-system
  labels:
    name: elasticsearch
spec:
  selector:
    app: es
  ports:
  - name: transport
    port: 9200
    protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-discovery
  namespace: kube-system
  labels:
    name: elasticsearch
spec:
  selector:
    app: es
  ports:
  - name: transport
    port: 9300
    protocol: TCP
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
spec:
# 3个节点满足高可用
  replicas: 3
  serviceName: "elasticsearch-service"
  selector:
    matchLabels:
      app: es
  template:
    metadata:
      labels:
        app: es
    spec:
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
      serviceAccountName: dashboard-admin
      initContainers:
      - name: init-sysctl
        image: busybox:1.27
        command:
        - sysctl
        - -w
        - vm.max_map_count=262144
        securityContext:
          privileged: true
      containers:
      - name: elasticsearch
        image: registry.cn-hangzhou.aliyuncs.com/imooc/elasticsearch:5.5.1
        ports:
        - containerPort: 9200
          protocol: TCP
        - containerPort: 9300
          protocol: TCP
        securityContext:
          capabilities:
            add:
              - IPC_LOCK
              - SYS_RESOURCE
        resources:
          limits:
            memory: 4000Mi
          requests:
            cpu: 100m
            memory: 2000Mi
        env:
          - name: "http.host"
            value: "0.0.0.0"
          - name: "network.host"
            value: "_eth0_"
          - name: "cluster.name"
            value: "docker-cluster"
          - name: "bootstrap.memory_lock"
            value: "false"
          - name: "discovery.zen.ping.unicast.hosts"
            value: "elasticsearch-discovery"
          - name: "discovery.zen.ping.unicast.hosts.resolve_timeout"
            value: "10s"
          - name: "discovery.zen.ping_timeout"
            value: "6s"
          - name: "discovery.zen.minimum_master_nodes"
            value: "2"
          - name: "discovery.zen.fd.ping_interval"
            value: "2s"
          - name: "discovery.zen.no_master_block"
            value: "write"
          - name: "gateway.expected_nodes"
            value: "2"
          - name: "gateway.expected_master_nodes"
            value: "1"
          - name: "transport.tcp.connect_timeout"
            value: "60s"
          - name: "ES_JAVA_OPTS"
            value: "-Xms2g -Xmx2g"
        livenessProbe:
          tcpSocket:
            port: transport
          initialDelaySeconds: 20
          periodSeconds: 10
        volumeMounts:
        - name: es-data
          mountPath: /data
      terminationGracePeriodSeconds: 30
  volumeClaimTemplates:
  - metadata:
      name: es-data
    spec:
      accessModes: ["ReadWriteOnce"]
      volumeMode: Filesystem
      resources:
        requests:
          storage: 20Gi
      storageClassName: managed-nfs-storage
```

## 安装log-pilot

```bash
kubectl apply -f log-pilot.yaml
```

log-pilot.yaml 内容

```yaml
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-pilot
  namespace: kube-system
  labels:
    k8s-app: log-pilot
    kubernetes.io/cluster-service: "true"
spec:
  selector:
    matchLabels:
      k8s-app: log-pilot
  template:
    metadata:
      labels:
        k8s-app: log-pilot
        kubernetes.io/cluster-service: "true"
        version: v1.22
    spec:
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      serviceAccountName: dashboard-admin
      containers:
      - name: log-pilot
        image: registry.cn-hangzhou.aliyuncs.com/imooc/log-pilot:0.9-filebeat
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        env:
          - name: "FILEBEAT_OUTPUT"
            value: "elasticsearch"
          - name: "ELASTICSEARCH_HOST"
            value: "elasticsearch-api"
          - name: "ELASTICSEARCH_PORT"
            value: "9200"
          - name: "ELASTICSEARCH_USER"
            value: "elastic"
          - name: "ELASTICSEARCH_PASSWORD"
            value: "changeme"
        volumeMounts:
        - name: sock
          mountPath: /var/run/docker.sock
        - name: root
          mountPath: /host
          readOnly: true
        - name: varlib
          mountPath: /var/lib/filebeat
        - name: varlog
          mountPath: /var/log/filebeat
        securityContext:
          capabilities:
            add:
            - SYS_ADMIN
      terminationGracePeriodSeconds: 30
      volumes:
      - name: sock
        hostPath:
          path: /var/run/docker.sock
      - name: root
        hostPath:
          path: /
      - name: varlib
        hostPath:
          path: /var/lib/filebeat
          type: DirectoryOrCreate
      - name: varlog
        hostPath:
          path: /var/log/filebeat
          type: DirectoryOrCreate
```



## 安装kibana

```bash
kubectl apply -f kibana.yml
```

kibana.yml 内容

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: kube-system
  labels:
    component: kibana
spec:
  selector:
    component: kibana
  ports:
  - name: http
    port: 80
    targetPort: http
  type: NodePort
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: kube-system
  labels:
    component: kibana
spec:
  replicas: 1
  selector:
    matchLabels:
     component: kibana
  template:
    metadata:
      labels:
        component: kibana
    spec:
      containers:
      - name: kibana
        image: registry.cn-hangzhou.aliyuncs.com/acs-sample/kibana:5.5.1
        env:
        - name: CLUSTER_NAME
          value: docker-cluster
        - name: ELASTICSEARCH_URL
          value: http://elasticsearch-api:9200/
        resources:
          limits:
            cpu: 1000m
          requests:
            cpu: 100m
        ports:
        - containerPort: 5601
          name: http

```



## 创建测试容器

```bash
kubectl apply -f tomcat-v4.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tomcat-v4
  namespace: default
  labels:
    name: tomcat-v4
spec:
  containers:
  - image: tomcat
    name: tomcat-v4-test
    volumeMounts:
    - mountPath: /usr/local/tomcat-v4/logs
      name: accesslogs
    env:
     - name: aliyun_logs_jsj-stdout
       value: "stdout"
     - name: aliyun_logs_jsj-filelog
       value: "/usr/local/tomcat-v4/logs/catalina.*.log"
     - name: aliyun_logs_access
       value: "/usr/local/tomcat-v4/logs/localhost_access_log.*.txt"
  volumes:
    - name: accesslogs
      emptyDir: {}

```



## 查询es上的日志索引

```bash
 kubectl apply -f elasticsearch_api_nodeport.yaml
```

```
**[terminal]
[root@k8s01 log-pilot]# kubectl get svc -n kube-system
NAME                         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                  AGE
elasticsearch-api            ClusterIP   10.96.7.14     <none>        9200/TCP                 11m
elasticsearch-api-nodeport   NodePort    10.96.62.255   <none>        9200:60461/TCP           28s
elasticsearch-discovery      ClusterIP   10.96.81.3     <none>        9300/TCP                 11m
kibana                       NodePort    10.96.0.67     <none>        80:55820/TCP             8m
kube-dns                     ClusterIP   10.96.0.2      <none>        53/UDP,53/TCP,9153/TCP   29d
metrics-server               ClusterIP   10.96.5.58     <none>        443/TCP                  29d

```

```
**[terminal]
[root@k8s01 log-pilot]# curl http://10.9.0.177:60461/_cat/indices?v
health status index                 uuid                   pri rep docs.count docs.deleted store.size pri.store.size
green  open   .kibana               NZOVkum6Tf-aRtP_Du-Zpg   1   1          1            0      6.4kb          3.2kb
green  open   jsj-stdout-2020.03.20 eETfOcNpR26WE0XtdwmZzQ   5   1         31            0    183.7kb         91.8kb

```
