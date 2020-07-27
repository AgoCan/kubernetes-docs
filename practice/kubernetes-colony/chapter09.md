# kube-proxy部署

所有节点都需要部署 kube-proxy 和kubelet一起
```bash
# 所有机器都需要下载的依赖
yum install -y conntrack-tools
```

```bash
export K8S_API_URL=${master01ip}
/usr/local/bin/kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/ssl/ca.pem \
--embed-certs=true \
--server=https://${K8S_API_URL}:6443 \
--kubeconfig=kube-proxy.kubeconfig

/usr/local/bin/kubectl  config set-credentials kube-proxy \
--client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
--client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
--embed-certs=true \
--kubeconfig=kube-proxy.kubeconfig

/usr/local/bin/kubectl  config set-context default \
--cluster=kubernetes \
--user=kube-proxy \
--kubeconfig=kube-proxy.kubeconfig

# 设置默认上下文
/usr/local/bin/kubectl  config use-context default --kubeconfig=kube-proxy.kubeconfig

mv kube-proxy.kubeconfig /etc/kubernetes/
scp /etc/kubernetes/kube-proxy.kubeconfig ${node02ip}:/etc/kubernetes/
scp /etc/kubernetes/kube-proxy.kubeconfig ${node03ip}:/etc/kubernetes/
```

```bash
# --hostname-override=k8s-master01 跟kubelet一致
ssh ${node01ip} mkdir -p /var/lib/kube-proxy
ssh ${node02ip} mkdir -p /var/lib/kube-proxy
ssh ${node03ip} mkdir -p /var/lib/kube-proxy
cat > kube-proxy.service << \EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
WorkingDirectory=/var/lib/kube-proxy
ExecStart=/usr/local/bin/kube-proxy   \
        --bind-address=0.0.0.0   \
        --hostname-override=node-name  \
        --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig \
        --masquerade-all   \
        --feature-gates=SupportIPVSProxyMode=true   \
        --proxy-mode=ipvs   \
        --ipvs-min-sync-period=5s   \
        --ipvs-sync-period=5s   \
        --ipvs-scheduler=rr   \
        --logtostderr=true   \
        --v=2   \
        --logtostderr=false   \
        --cluster-cidr=10.2.0.0/16 \
        --log-dir=/var/log/kubernetes

Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
for ip in ${node01ip} ${node02ip} ${node03ip}
do
  sed "s#node-name#${ip}#g" kube-proxy.service > kube-proxy.service.bak
  scp kube-proxy.service.bak ${ip}:/usr/lib/systemd/system/kube-proxy.service
done
```
参数介绍
- `--hostname-override` 参数值必须与 kubelet 的值一致，否则 `kube-proxy` 启动后会找不到该 Node，从而不会创建任何 `iptables` 规则；
- `--cluster-cdir` 上面没有添加(修改后添加上了)，是定义pod的ip地址段的 是否需要跟controller-manager的配置一致，有待考证  


```bash
systemctl daemon-reload
systemctl enable kube-proxy
systemctl start kube-proxy
systemctl status kube-proxy
```
