# 环境准备(务必配置好几个ip的环境变量)
**本次集群使用的是域名的方式进行不部署，所以一定要配置好域名解析**
**不使用域名解析的方式，只需要把对应的域名改成ip即可使用**
**此次测试单节点通过，多master的kube-apiserver部署未成功**
**对应的ansible脚本: https://github.com/AgoCan/ansible-kubernetes  ，脚本的网段为192.168.126.0/24，与文档不符**

由于多次使用ip地址，这里使用环境变量的方式进行配置

```bash
# master01ip 是因为使用keepalived的虚拟ip，没有配置虚拟ip可以直接跟node01一致即可
export master01ip=10.10.10.5
export node01ip=10.10.10.5
export node02ip=10.10.10.6
export node03ip=10.10.10.7
echo export master01ip=10.10.10.5 >> /etc/profile
echo export node01ip=10.10.10.5   >> /etc/profile
echo export node02ip=10.10.10.6   >> /etc/profile
echo export node03ip=10.10.10.7   >> /etc/profile
source /etc/profile
# 创建ssh密钥对
# 更安全 Ed25519 算法
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
# 或者传统 RSA 算法
ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa

# 分发密钥
for i in ${node01ip} ${node02ip} ${node03ip}
do
  ssh-copy-id -o stricthostkeychecking=no $i
done

```


## 基础环境准备
1. 准备三台服务器，一台master，两台node节点
  ```bash
    CentOS7.6.1810
    2核4G内存
    50G硬盘
  ```
2. 配置好`hosts`解析并且分别重命名主机
  ```bash
  echo "${node01ip} k8s01.example.com" >> /etc/hosts
  echo "${node02ip} k8s02.example.com"  >> /etc/hosts
  echo "${node03ip} k8s03.example.com"  >> /etc/hosts
  scp /etc/hosts ${node02ip}:/etc/hosts
  scp /etc/hosts ${node03ip}:/etc/hosts
  ```
  ```bash
  ssh ${node01ip} hostnamectl set-hostname k8s01.example.com
  ssh ${node02ip} hostnamectl set-hostname k8s02.example.com
  ssh ${node03ip} hostnamectl set-hostname k8s03.example.com
  ```
3. 关闭防火墙，selinux

  ```bash
  for ip in ${node01ip} ${node02ip} ${node03ip}
  do
    ssh ${ip} systemctl stop firewalld
    ssh ${ip} systemctl disable firewalld
    ssh ${ip} sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config
  done
  ```
4. 关闭swap
  ```bash
  for ip in ${node01ip} ${node02ip} ${node03ip}
  do
    ssh ${ip} "sed -ri 's/.*swap.*/#&/' /etc/fstab"
    ssh ${ip} swapoff -a
  done
  ```
5. 同步时间
  ```bash
  for ip in ${node01ip} ${node02ip} ${node03ip}
  do
    ssh ${ip} yum install ntpdate -y
    ssh ${ip} ntpdate ntp1.aliyun.com
    ssh ${ip} echo '*/5 * * * * root ntpdate ntp1.aliyun.com > /dev/null 2>&1' >> /etc/crontab
  done
  ```

6. 安装功能包
  ```bash
  for ip in ${node01ip} ${node02ip} ${node03ip}
  do
    ssh ${ip} yum install wget lrzsz bash-completion net-tools epel-release -y
  done
  ```
7. 增加文件描述符
  ```bash
  # 增大文件描述数值 默认1024
  echo "* soft nofile 65536" >> /etc/security/limits.conf
  echo "* hard nofile 65536" >> /etc/security/limits.conf
  echo "* soft nproc 65536"  >> /etc/security/limits.conf
  echo "* hard nproc 65536"  >> /etc/security/limits.conf
  echo "* soft  memlock  unlimited"  >> /etc/security/limits.conf
  echo "* soft  memlock  unlimited"  >> /etc/security/limits.conf
  scp /etc/security/limits.conf ${node02ip}:/etc/security/limits.conf
  scp /etc/security/limits.conf ${node03ip}:/etc/security/limits.conf
  ```

8. 内核参数修改

```bash
cat >> /etc/sysctl.conf << EOF
# 禁止ipv6的监听会导致rpcbind不能启动,因为nfs会监听ipv6
#net.ipv6.conf.all.disable_ipv6 = 1
#net.ipv6.conf.default.disable_ipv6 = 1
#net.ipv6.conf.lo.disable_ipv6 = 1

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
# 允许绑定不存在的ip
net.ipv4.ip_nonlocal_bind = 1
net.ipv6.ip_nonlocal_bind = 1

# 允许转发
net.ipv4.ip_forward = 1
#
# iptables透明网桥的实现
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
EOF
sysctl -p
scp /etc/sysctl.conf ${node02ip}:/etc/sysctl.conf
scp /etc/sysctl.conf ${node03ip}:/etc/sysctl.conf

for ip in ${node01ip} ${node02ip} ${node03ip}
do
  ssh ${ip} sysctl -p
done
```

9. 支持ipvs
不能远程调用命令

```bash
for ip in ${node01ip} ${node02ip} ${node03ip}
do
  ssh ${ip} yum install -y ipvsadm
done
# 增加ipvs
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
```
```bash
for ip in ${node01ip} ${node02ip} ${node03ip}
do
  ssh ${ip} "echo #!/bin/bash >> /etc/sysconfig/modules/ipvs.modules"
  ssh ${ip} "echo modprobe -- ip_vs >> /etc/sysconfig/modules/ipvs.modules"
  ssh ${ip} "echo modprobe -- ip_vs_rr >> /etc/sysconfig/modules/ipvs.modules"
  ssh ${ip} "echo modprobe -- ip_vs_wrr >> /etc/sysconfig/modules/ipvs.modules"
  ssh ${ip} "echo modprobe -- ip_vs_sh >> /etc/sysconfig/modules/ipvs.modules"
  ssh ${ip} "echo modprobe -- nf_conntrack_ipv4 >> /etc/sysconfig/modules/ipvs.modules"
  ssh ${ip} "chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4"

done
# 修改nfs，提高性能， 详细介绍请超看https://yq.aliyun.com/articles/501417
for ip in ${node01ip} ${node02ip} ${node03ip}
do
  ssh ${ip} `echo "options sunrpc tcp_slot_table_entries=128" >> /etc/modprobe.d/sunrpc.conf`
  ssh ${ip} `echo "options sunrpc tcp_max_slot_table_entries=128" >>  /etc/modprobe.d/sunrpc.conf`
  ssh ${ip} `sysctl -w sunrpc.tcp_slot_table_entries=128`
done
```

10. 解释EOF前面加`\`就不会转义例如
  ```bash
  cat > 1.log << \EOF
  \a
  $a
  EOF
  ```
