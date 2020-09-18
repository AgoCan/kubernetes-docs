# cert-manager 自动生成证书/自动更新证书
> 接下来以 helm3的方式安装，如果需要用helm2或者直接安装的方式，可以查看官网

> 如何让网站访问是绿色安全的，还没测试成功。主要是http01和dns01的方式

## 前提
配置部署好了ingress。按照 [文档](/service-discovery/ingress/install.md) 部署的ingress即可。

## 部署

```bash
# 添加源，stable已不维护，转移到新仓库
helm repo add jetstack https://charts.jetstack.io
helm repo update

# 部署
kubectl create ns cert-manager
helm install  cert-manager \
--namespace cert-manager \
--set ingressShim.defaultIssuerName=letsencrypt-prod \
--set ingressShim.defaultIssuerKind=ClusterIssuer \
--set ingressShim.defaultIssuerGroup=cert-manager.io \
--set installCRDs=true \
--version v1.0.1 \
jetstack/cert-manager
```

后续创建Ingress时，配合annotations,如果这里解释不清楚，稍后会有案例直接查看
```
kubernetes.io/tls-acme: "true"
kubernetes.io/ingress.class: "nginx"
```

查看部署情况
```
[root@k8s-01 test]# kubectl get pod  -n cert-manager
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-cainjector-59dc47c7dd-r2rpv   1/1     Running   0          32m
cert-manager-f6645cbd4-47sd6               1/1     Running   0          32m
cert-manager-webhook-795db4b849-4xrx7      1/1     Running   0          32m
```

创建ClusterIssuer,`cluster-issuer.yaml`

```yaml
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: hank@hankbook.cn
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

- metadata.name 是我们创建的签发机构的名称，后面我们创建证书的时候会引用它
- spec.acme.email 是你自己的邮箱，证书快过期的时候会有邮件提醒，不过 cert-manager 会利用 acme 协议自动给我们重新颁发证书来续期
- spec.acme.server 是 acme 协议的服务端，我们这里用 Let’s Encrypt，这个地址就写死成这样就行
- spec.acme.privateKeySecretRef 指示此签发机构的私钥将要存储到哪个 Secret 对象中，名称不重要
- spec.acme.solvers.http01 这里指示签发机构使用 HTTP-01 的方式进行 acme 协议 (还可以用 DNS 方式，acme 协议的目的是证明这台机器和域名都是属于你的，然后才准许给你颁发证书)

```bash
kubectl apply -f cluster-issuer.yaml
```
查看
```
kubectl get clusterissuer
```

## 测试
`pod.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-tls-nginx
  namespace: cert-manager-test
  labels:
    app: nginx-web
spec:
  containers:
  - name: test-nginx
    image: nginx
    ports:
    - containerPort: 80
```

`service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: test-tls-nginx-service
  namespace: cert-manager-test
  labels:
    app: test-tls-nginx-service
spec:
  selector:
    app: nginx-web
  ports:
  - name: test-tls-nginx-port
    port: 80
    targetPort: 80
```

`ingress.yaml`

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test-tls-ingress
  namespace: cert-manager-test
  annotations:
    kubernetes.io/ingress.class: "nginx"
    kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
    - secretName: selfsigned-cert-tls
  rules:
  - host: hankbook.cn
    http:
      paths:
      - path:
        backend:
          serviceName: test-tls-nginx-service
          servicePort: 80
```

创建

```
kubectl create ns cert-manager-test
kubectl apply -f pod.yaml service.yaml ingress.yaml
```

## 检查
根据host设置好dns解析之后，直接访问即可，访问443对应的端口


- 参考文档： https://cert-manager.io/
