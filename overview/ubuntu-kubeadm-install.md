# ubuntu部署k8s

ubuntu 18.04

```bash
apt-get update
apt-get install vim -y

# 关闭防火墙
ufw disable
# 有swap的话
sed -ri 's/.*swap.*/#&/' /etc/fstab
swapoff -a
# 增大文件描述数值 默认1024
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf
echo "* soft nproc 65536"  >> /etc/security/limits.conf
echo "* hard nproc 65536"  >> /etc/security/limits.conf
echo "* soft  memlock  unlimited"  >> /etc/security/limits.conf
echo "* soft  memlock  unlimited"  >> /etc/security/limits.conf
# 修改一些内核
cat >> /etc/sysctl.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

vm.swappiness = 0
net.ipv4.neigh.default.gc_stale_time=120
net.ipv4.ip_forward = 1

# see details in https://help.aliyun.com/knowledge_detail/39428.html
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce=2
net.ipv4.conf.all.arp_announce=2


# see details in https://help.aliyun.com/knowledge_detail/41334.html
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2
kernel.sysrq = 1

# iptables透明网桥的实现
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
EOF
modprobe br_netfilter
sysctl -p /etc/sysctl.conf
# 启用ipvs
apt-get update
apt-get install ipvsadm
# 临时启用
for i in $(ls /lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*");do echo $i; /sbin/modinfo -F filename $i >/dev/null 2>&1 && /sbin/modprobe $i; done
# 永久启用
ls /lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*" >> /etc/modules
```

安装kubernetes

```bash
#参考地址： https://developer.aliyun.com/mirror/kubernetes?spm=a2c6h.13651102.0.0.3e221b11HDNwfS
apt-get update && apt-get install -y apt-transport-https
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
kubeadm config print init-defaults
```

## docker版本

安装docker

```bash
#参考地址：https://docs.docker.com/engine/install/ubuntu/
apt-get remove docker docker-engine docker.io containerd runc
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
# 查看版本
#apt-cache madison docker-ce
```

启动

```bash
# kubelet后版本默认使用 systemd进行管理，所以docker必须修改
cat > /etc/docker/daemon.json  << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

systemctl enable docker
systemctl start docker
systemctl enable kubelet
systemctl start kubelet


# 拉取镜像
for name in `kubeadm config images list 2>/dev/null | awk -F "/" '{print $2}'`
do
    docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/$name
    docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/$name k8s.gcr.io/$name
    docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/$name
done
# 由于网络插件的缘故，pod-network-cidr
kubeadm init --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 部署网络插件
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

## containerd版本

安装containerd

```bash
#参考地址：https://docs.docker.com/engine/install/ubuntu/
apt-get remove docker docker-engine docker.io containerd runc
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y containerd.io
systemctl enable containerd
```

```bash
mkdir -p /opt/cni/bin/ /etc/cni/net.d/
mkdir -p /etc/containerd
echo "runtime-endpoint: unix:///run/containerd/containerd.sock" > /etc/crictl.yaml
containerd config default | sudo tee /etc/containerd/config.toml
# sandbox_image = "registry.cn-hangzhou.aliyuncs.com/google_containers/pause-amd64:3.2"
sed -i 's#k8s.gcr.io/pause:3.2#registry.cn-hangzhou.aliyuncs.com/google_containers/pause-amd64:3.2#g' /etc/containerd/config.toml
systemctl set-property containerd.service TasksMax=35000
systemctl daemon-reload
systemctl restart containerd
```

```bash
# 增加 KUBELET_EXTRA_ARGS 和 注释掉  EnvironmentFile=-/etc/default/kubelet
echo '
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
Environment="KUBELET_EXTRA_ARGS=--runtime-cgroups=/system.slice/containerd.service --container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
#EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS' > /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
```

```bash
mkdir -p /sys/fs/cgroup/hugetlb/system.slice/kubelet.service
mkdir -p /sys/fs/cgroup/cpuset/system.slice/kubelet.service
echo '
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Wants=network-online.target
After=network-online.target

[Service]
ExecStartPre=/bin/mkdir -p /sys/fs/cgroup/cpuset/system.slice/kubelet.service
ExecStartPre=/bin/mkdir -p /sys/fs/cgroup/hugetlb/system.slice/kubelet.service
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target' > /lib/systemd/system/kubelet.service
systemctl daemon-reload
systemctl enable kubelet
systemctl restart kubelet
```

```bash
# 拉取镜像,其中镜像如果有出入，请自己根据需求进行拉取
for name in `kubeadm config images list 2>/dev/null | awk -F "/" '{print $2}'` v1.8.4
do
    ctr --namespace k8s.io images pull registry.cn-hangzhou.aliyuncs.com/google_containers/$name
    ctr --namespace k8s.io images tag registry.cn-hangzhou.aliyuncs.com/google_containers/$name k8s.gcr.io/$name
    ctr --namespace k8s.io images rm registry.cn-hangzhou.aliyuncs.com/google_containers/$name
done
# 查看 ctr --namespace k8s.io images ls
# 由于网络插件的缘故，pod-network-cidr
kubeadm init --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12 --cri-socket=/var/run/containerd/containerd.sock --v=5

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 部署网络插件
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

参考文档： https://kubernetes.io/docs/setup/production-environment/container-runtimes/
