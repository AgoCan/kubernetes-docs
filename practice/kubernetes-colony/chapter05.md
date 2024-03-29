# kube-controller-manager部署

kube-controller-manager.service

```bash
cat > kube-controller-manager.service << \EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager   \
--address=0.0.0.0   \
--master=http://127.0.0.1:8080   \
--allocate-node-cidrs=true   \
--service-cluster-ip-range=10.96.0.0/16   \
--cluster-cidr=10.2.0.0/16   \
--cluster-name=kubernetes   \
--cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem   \
--cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem   \
--service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem   \
--root-ca-file=/etc/kubernetes/ssl/ca.pem   \
--leader-elect=true   \
--v=2   \
--logtostderr=false   \
--log-dir=/var/log/kubernetes/

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
mv kube-controller-manager.service /usr/lib/systemd/system/
```
```bash
scp  /usr/lib/systemd/system/kube-controller-manager.service ${node02ip}:/usr/lib/systemd/system/
scp  /usr/lib/systemd/system/kube-controller-manager.service ${node03ip}:/usr/lib/systemd/system/
```

**参数**
- 其中还可以加`--service-cluster-ip-range`必须和`kube-apiserver`一致
- `--cluster-cidr`  指定 pod-dir
> 注意： 1.20 需要搭配rsa私钥 `--service-account-private-key-file=/etc/kubernetes/pki/sa.key`

启动 `kube-controller-manager`

```bash

systemctl daemon-reload
systemctl enable kube-controller-manager
systemctl start kube-controller-manager
systemctl status kube-controller-manager
```

## 检查

```
kubectl get componentstatuses
```

## 1.20

```
export K8S_API_URL=${master01ip}

/usr/local/bin/kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/ssl/ca.pem \
--embed-certs=true \
--server=https://${K8S_API_URL}:6443 \
--kubeconfig=controller-manager.conf


/usr/local/bin/kubectl  config set-credentials system:controller-manager \
--client-certificate=/etc/kubernetes/ssl/kubernetes.pem \
--client-key=/etc/kubernetes/ssl/kubernetes-key.pem \
--embed-certs=true \
--kubeconfig=controller-manager.conf


/usr/local/bin/kubectl  config set-context system:kube-controller-manager@kubernetes \
--cluster=kubernetes \
--user=system:kube-controller-manager \
--kubeconfig=controller-manager.conf

# 设置默认上下文
/usr/local/bin/kubectl  config use-context system:kube-controller-manager@kubernetes --kubeconfig=controller-manager.conf
```

```
 --requestheader-client-ca-file=/etc/kubernetes/ssl/ca.pem
```
