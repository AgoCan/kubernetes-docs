# contianerd


部署：
```bash
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 设置必需的 sysctl 参数，这些参数在重新启动后仍然存在。
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
# 安装containerd
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
## 安装 containerd
sudo yum update -y && sudo yum install -y containerd.io
# 配置 containerd
sudo mkdir -p /etc/containerd
sudo containerd config default > /etc/containerd/config.toml
# 重启 containerd
sudo systemctl restart containerd
```

```
ctr -n k8s.io container ls
```

## 下载调试工具
```
VERSION="v1.19.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz
```
```
cat /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
```
命令
```
crictl ps
crictl image
crictl --help
```




参考文档：
- https://kubernetes.io/zh/docs/setup/production-environment/container-runtimes/
- https://github.com/kubernetes-sigs/cri-tools
