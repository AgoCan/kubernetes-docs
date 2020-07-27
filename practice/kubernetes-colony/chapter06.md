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
