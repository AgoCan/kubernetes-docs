# 创建TLS证书
在没有配置任何nginx下，k8s的nginx默认只支持TLS1.2，不支持TLS1.0和TLS1.1


## 直接实战

前提： 部署好ingress

生成证书

```bash
#openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -subj "/CN=${HOST}/O=${HOST}"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout test.key -out test.csr -subj "/CN=test /O=test"
```
创建`secret`
```bash
#kubectl create secret tls ${CERT_NAME} --key ${KEY_FILE} --cert ${CERT_FILE}
kubectl create secret tls test-cert --key test.key --cert test.csr
# 查看证书kubectl get secret -o yaml test-cert
```
产生的秘密将是类型`kubernetes.io/tls`。

可以使用下面的yaml进行创建。  key和crt均为base64的转码
```yaml
apiVersion: v1
data:
  tls.crt: base64 encoded cert
  tls.key: base64 encoded key
kind: Secret
metadata:
  name: testsecret
  namespace: default
type: Opaque
```

创建pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-tls-nginx
  labels:
    app: nginx-web
spec:
  containers:
  - name: test-nginx
    image: nginx
    ports:
    - containerPort: 80
```

创建serivce

```yaml
apiVersion: v1
kind: Service
metadata:
  name: test-tls-nginx-service
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

创建ingress
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test-tls-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  tls:
    - secretName: test-cert
  rules:
  - host: ingress-tls.hankbook.com
    http:
      paths:
      - path:
        backend:
          serviceName: test-tls-nginx-service
          servicePort: 80
```



## 默认SSL证书
NGINX提供了一个选项，用于将服务器配置为具有server_name的包罗万象的功能， 用于与任何已配置的服务器名称都不匹配的请求。此配置无需HTTP流量即可使用。对于HTTPS，自然需要证书。

因此，Ingress控制器提供了flag `--default-ssl-certificate`。此标志引用的机密包含访问全部捕获服务器时要使用的默认证书。如果未提供此标志，NGINX将使用自签名证书。

例如，如果名称空间中包含TLS机密foo-tls，则在部署中default添加。`--default-ssl-certificate=default/foo-tlsnginx-controller`

默认证书还将用于tls:没有secretName选项的入口部分。

## SSL传递

该`--enable-ssl-passthrough`标志启用SSL Passthrough功能，​​该功能默认情况下处于禁用状态。这是启用Ingress对象中的直通后端所必需的。
> 注意： 通过拦截已配置的HTTPS端口（默认值：443）上的所有流量并将其移交给本地TCP代理，可以实现此功能。这完全绕开了NGINX，并引入了不可忽略的性能损失。

SSL Passthrough利用SNI并从TLS协商中读取虚拟域，这需要兼容的客户端。TLS侦听器接受连接后，该连接将由控制器本身处理，并在后端和客户端之间来回传送。

如果没有与请求的主机名匹配的主机名，则请求将在已配置的直通代理端口（默认值：442）上移交给NGINX，该代理端口会将请求代理到默认后端。

## 自动注入tls Kube-Lego
