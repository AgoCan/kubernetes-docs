# kube-scheduler部署

kube-scheduler.service
```bash
cat >  kube-scheduler.service << \EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler   \
--address=0.0.0.0   \
--master=http://127.0.0.1:8080   \
--leader-elect=true   \
--v=2   \
--logtostderr=false   \
--log-dir=/var/log/kubernetes/

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
mv kube-scheduler.service /usr/lib/systemd/system/
```

```bash
scp  /usr/lib/systemd/system/kube-scheduler.service ${node02ip}:/usr/lib/systemd/system/
scp  /usr/lib/systemd/system/kube-scheduler.service ${node03ip}:/usr/lib/systemd/system/
```

启动 `kube-scheduler`

```bash

systemctl daemon-reload
systemctl enable kube-scheduler
systemctl start kube-scheduler
systemctl status kube-scheduler
```

## 1.20

```
export K8S_API_URL=${master01ip}

/usr/local/bin/kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/ssl/ca.pem \
--embed-certs=true \
--server=https://${K8S_API_URL}:6443 \
--kubeconfig=scheduler.conf


/usr/local/bin/kubectl  config set-credentials system:kube-scheduler \
--client-certificate=/etc/kubernetes/ssl/kubernetes.pem \
--client-key=/etc/kubernetes/ssl/kubernetes-key.pem \
--embed-certs=true \
--kubeconfig=scheduler.conf


/usr/local/bin/kubectl  config set-context system:kube-scheduler@kubernetes \
--cluster=kubernetes \
--user=system:kube-scheduler \
--kubeconfig=scheduler.conf

# 设置默认上下文
/usr/local/bin/kubectl  config use-context system:kube-scheduler@kubernetes --kubeconfig=scheduler.conf
```

```
--authentication-kubeconfig=/etc/kubernetes/scheduler.conf
--authorization-kubeconfig=/etc/kubernetes/scheduler.conf
--kubeconfig=/etc/kubernetes/scheduler.conf
```
