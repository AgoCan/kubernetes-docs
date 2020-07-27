# ingress



## 部署

安装ingress controller
https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md

https://kubernetes.github.io/ingress-nginx/deploy/#prerequisite-generic-deployment-command

### 更新
新的部署，nodeport已经在yaml里面了
```bash
wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/deploy.yaml
kubectl apply -f deploy.yaml
```

### 旧部署内容
复制内容
- [mandatory.yaml](https://kubernetes.hankbook.cn/manifests/example/ingress/mandatory.yaml)
- [service-nodeport.yaml](https://kubernetes.hankbook.cn/manifests/example/ingress/service-nodeport.yaml)

```bash
git clone https://github.com/kubernetes/ingress-nginx.git
# 或者直接去
wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
kubectl apply -f mandatory.yaml
# 增加nodeport的访问，不然外网访问不到
wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/service-nodeport.yaml

kubectl apply -f service-nodeport.yaml
# 可以改变部署方式，不使用deployment的方式，而是使用daemonset的方式不是，然后使用打污点的方式，只让ingress部署在指定机器上面
```

部署web服务

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hank-web01
  labels:
    name: hank-web01
    app: web
spec:
  replicas: 2
  selector:
    matchLabels:
      name: hank-web01
      app: web
  template:
    metadata:
      labels:
        name: hank-web01
        app: web
    spec:
      containers:
      - name: webapp
        image: hank997/webapp:v1
---
apiVersion: v1
kind: Service
metadata:
  name: hank-web-service
  labels:
    app: web-service
spec:
  selector:
    app: web
    name: hank-web01
  ports:
  - name: hank-web-port
    port: 80
    targetPort: 80
```

https://kubernetes.io/zh/docs/concepts/services-networking/ingress/

安装ingress


```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-web
  labels:
    name: ingress-web
    app: web
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
#  backend:
#    serviceName: hank-web-service
#    servicePort: 80
  rules:
  - host: ingress.hankbook.com
    http:
      paths:
      - path:
        backend:
          serviceName: hank-web-service
          servicePort: 80
#  rules:  # 定义规则
```

查看
```bash
kubectl describe ingress
kubectl get pod
kubectl  exec -it -n ingress-nginx nginx-ingress-controller-568867bf56-vp8nj bash
```

访问：
使用域名的方式，就要使用域名的方式进行访问  
因为有nodeport的访问。既需要加上端口号  
直接使用backend的方式就是普通的跳转  
```bash
echo 127.0.0.1 ingress.hankbook.com >> /etc/hosts
curl ingress.hankbook.com:32234
```

## 配置转发规则
### 全局配置
https://kubernetes.github.io/ingress-nginx/examples/rewrite/
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-web
  labels:
    name: ingress-web
    app: web
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - host: ingress.hankbook.com
    http:
      paths:
      - path: /v1(/|$)(.*)
        backend:
          serviceName: hank-web-service
          servicePort: 80
      - path: /v2(/|$)(.*)
        backend:
          serviceName: hank-web-service2
          servicePort: 80
```

## 修改ingress的内置参数

修改configMap，该配置在 文件 `mandatory.yaml` 当中

把nginx的`client_max_body_size`改成 `20m`

`ingress-configmap.yaml`  
```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
data:
  proxy-body-size: “20m”
```

```bash
kubectl apply -f ingress-configmap.yaml
```

查看更多参数的对应关系  https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/  


### 局部配置

`test-ingress.yaml`
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-web
  labels:
    name: ingress-web
    app: web
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/proxy-body-size: "4m"
spec:
  backend:
    serviceName: hank-web-service
    servicePort: 80
```

查看更多参数的对应关系  https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/


进入容器内查看

```bash
kubectl exec -it -n ingress-nginx `kubectl get pod -n ingress-nginx|awk 'NR==2{print $1}'`
# 下面是容器内执行
$ grep client_max_body_size /etc/nginx/nginx.conf
```
