# kebe-apiserver部署

## 创建config配置文件

注意：请先参考 安装kubectl命令行工具，先在 master 节点上安装 kubectl 然后再进行下面的操作。

kubelet、kube-proxy 等 Node 机器上的进程与 Master 机器的 kube-apiserver 进程通信时需要认证和授权；

kubernetes 1.4 开始支持由 kube-apiserver 为客户端生成 TLS 证书的 TLS Bootstrapping 功能，这样就不需要为每个客户端生成证书了；该功能当前仅支持为 kubelet 生成证书；

因为我的master节点和node节点复用，所有在这一步其实已经安装了kubectl。参考安装kubectl命令行工具。

以下操作只需要在master节点上执行，生成的*.kubeconfig文件可以直接拷贝到node节点的/etc/kubernetes目录下。

## 创建 TLS Bootstrapping Token
Token可以是任意的包含128 bit的字符串，可以使用安全的随机数发生器生成。

```bash
export BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
cat > bootstrap-token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
mv bootstrap-token.csv /etc/kubernetes/ssl/
scp /etc/kubernetes/ssl/bootstrap-token.csv ${node02ip}:/etc/kubernetes/ssl/
scp /etc/kubernetes/ssl/bootstrap-token.csv ${node03ip}:/etc/kubernetes/ssl/
```


## 创建访问用户
参数`--bacis-auth-file`在16版本已经提示，将被移除
```bash
cat >>  basic-auth.csv  << EOF
admin,admin,1
readonly,readonly,2
# password,usernmae,uid
EOF
mv basic-auth.csv /etc/kubernetes/ssl/
scp /etc/kubernetes/ssl/basic-auth.csv ${node02ip}:/etc/kubernetes/ssl/
scp /etc/kubernetes/ssl/basic-auth.csv ${node03ip}:/etc/kubernetes/ssl/
```
加了参数后测试
```
curl https://${node01ip}:6443/apis/metrics.k8s.io/v1beta1/nodes -k --basic -u admin:admin
```

## 创建kube-apiserver.service

```bash
mkdir -p /var/log/kubernetes/
cat >> kube-apiserver.service << \EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-apiserver   \
--bind-address=0.0.0.0  \
--authorization-mode=Node,RBAC   \
--runtime-config=rbac.authorization.k8s.io/v1   \
--anonymous-auth=false   \
--enable-bootstrap-token-auth   \
--token-auth-file=/etc/kubernetes/ssl/bootstrap-token.csv   \
--service-cluster-ip-range=10.96.0.0/16   \
--tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem   \
--tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem   \
--client-ca-file=/etc/kubernetes/ssl/ca.pem   \
--service-account-key-file=/etc/kubernetes/ssl/ca-key.pem   \
--etcd-cafile=/etc/kubernetes/ssl/ca.pem   \
--etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem   \
--etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem   \
--etcd-servers=https://10.10.10.5:2379,https://10.10.10.6:2379,https://10.10.10.7:2379  \
--allow-privileged=true   \
--audit-log-maxage=30   \
--audit-log-maxbackup=3   \
--audit-log-maxsize=100   \
--audit-log-path=/var/log/kubernetes/api-audit.log   \
--event-ttl=1h   \
--v=0   \
--logtostderr=false   \
--log-dir=/var/log/kubernetes/   \
--proxy-client-cert-file=/etc/kubernetes/ssl/kube-proxy.pem \
--proxy-client-key-file=/etc/kubernetes/ssl/kube-proxy-key.pem \
--requestheader-client-ca-file=/etc/kubernetes/ssl/ca.pem \
--requestheader-allowed-names=front-proxy-client \
--requestheader-group-headers=X-Remote-Group \
--requestheader-extra-headers-prefix=X-Remote-Extra- \
--requestheader-username-headers=X-Remote-User \
--service-node-port-range=30000-32767
Restart=on-failure
RestartSec=5
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
sed -i "s#10.10.10.5#${node01ip}#g" kube-apiserver.service
sed -i "s#10.10.10.6#${node02ip}#g" kube-apiserver.service
sed -i "s#10.10.10.7#${node03ip}#g" kube-apiserver.service
mv kube-apiserver.service /usr/lib/systemd/system/
```

```bash
ssh ${node02ip} mkdir -p /var/log/kubernetes/
ssh ${node03ip} mkdir -p /var/log/kubernetes/
# 如果多个master
scp  /usr/lib/systemd/system/kube-apiserver.service ${node02ip}:/usr/lib/systemd/system/
scp  /usr/lib/systemd/system/kube-apiserver.service ${node03ip}:/usr/lib/systemd/system/
```

**参数解释**
- 注意点，线上的`--bind-address`绑定的必须使用内网ip
- 线上`--v=0` 日志级别根据自己的需求进行修改
- `kubernetes`的`service`的`nodePort`默认使用端口号是`30000-32767`，如果有需要可以自己的需求进行配置指定
- `--etcd-servers`指定`etcd`的服务端，进行访问，其中不能有引号，因为会导致`,`的分隔符不被承认，然后报错，把整个引号当成了一个整体
- `--service-cluster-ip-range`定制`service`的`ip`网段，根据自己网络需求，进行修改


启动kube-apiserver
```bash
systemctl daemon-reload
systemctl enable kube-apiserver
systemctl start kube-apiserver
systemctl status kube-apiserver
```
