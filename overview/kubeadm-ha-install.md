# kubeadm 高可用部署

前面的部署跟kubeadm的普通部署类似，一直安装到kubeadm，kubectl，kubelet即可，并且启动kubelet

```
systemctl start kubelet
systemctl enable kubelet
```

## 安装keepalived

添加转发
```
cat >> /etc/sysctl.d/k8s.conf <<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf
```
安装keepalived
```
yum install -y keepalived
```

配置文件

配置文件修改虚拟ip即可，虚拟ip应该跟局域网相同， 每一个节点的`priority`应该不一样，尽量数字差别大点
```
vrrp_instance VI_1 {
    # 指定 keepalived 的角色，MASTER 表示此主机是主服务器，BACKUP 表示此主机是备用服务器
    state MASTER

    # 指定网卡
    interface ens33

    # 虚拟路由标识，这个标识是一个数字，同一个vrrp实例使用唯一的标识。
    # 即同一vrrp_instance下，MASTER和BACKUP必须是一致的
    virtual_router_id 51

    # 定义优先级，数字越大，优先级越高（0-255）。
    # 在同一个vrrp_instance下，MASTER 的优先级必须大于 BACKUP 的优先级
    priority 100

    # 设定 MASTER 与 BACKUP 负载均衡器之间同步检查的时间间隔，单位是秒
    advert_int 1

    # 设置验证类型和密码
    authentication {
        #设置验证类型，主要有PASS和AH两种
        auth_type PASS
        #设置验证密码，在同一个vrrp_instance下，MASTER与BACKUP必须使用相同的密码才能正常通信
        auth_pass 1111
    }

    #设置虚拟IP地址，可以设置多个虚拟IP地址，每行一个
    virtual_ipaddress {
        # 虚拟 IP
        192.168.126.41
      }
}
```
启动
```
systemctl start keepalived
systemctl enable keepalived
```

## 安装haproxy


```
yum install -y haproxy
```
配置文件， 注意修改三个`server`
```
cat > /etc/haproxy/haproxy.cfg << EOF
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    # to have these messages end up in /var/log/haproxy.log you will
    # need to:
    # 1) configure syslog to accept network log events.  This is done
    #    by adding the '-r' option to the SYSLOGD_OPTIONS in
    #    /etc/sysconfig/syslog
    # 2) configure local2 events to go to the /var/log/haproxy.log
    #   file. A line like the following can be added to
    #   /etc/sysconfig/syslog
    #
    #    local2.*                       /var/log/haproxy.log
    #
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats
#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000
#---------------------------------------------------------------------
# kubernetes apiserver frontend which proxys to the backends
#---------------------------------------------------------------------
frontend kubernetes-apiserver
    mode                 tcp
    bind                 *:16443
    option               tcplog
    default_backend      kubernetes-apiserver
#---------------------------------------------------------------------
# round robin balancing between the various backends
#---------------------------------------------------------------------
backend kubernetes-apiserver
    mode        tcp
    balance     roundrobin
    server      master01.k8s.io   192.168.9.81:6443 check
    server      master02.k8s.io   192.168.9.82:6443 check
    server      master03.k8s.io   192.168.9.83:6443 check
#---------------------------------------------------------------------
# collection haproxy statistics message
#---------------------------------------------------------------------
listen stats
    bind                 *:1080
    stats auth           admin:awesomePassword
    stats refresh        5s
    stats realm          HAProxy\ Statistics
    stats uri            /admin?stats
EOF
```

启动

```
systemctl enable haproxy
systemctl start haproxy
```

```
systemctl status haproxy
# yum install net-tools -y
netstat -lntup|grep haproxy
```

## kubeadm init master-01

kubeadm 配置文件
> 注意： 修改 `certSANs` 下的证书，并且 `controlPlaneEndpoint`  改成虚拟IP，或者做 `/etc/hosts` 解析
> 版本号： `kubernetesVersion` 根据自己下载的kubeadm和kubelet的版本进行修改
```
mkdir /data/kubernetes/manifests -p
cd /data/kubernetes/manifests
cat >> kubeadm-config.yaml <<EOF
apiServer:
  certSANs:
    - ha1
    - ha2
    - ha3
    - master.k8s.io
    - 192.168.126.44
    - 192.168.126.45
    - 192.168.126.46
    - 192.168.126.41
    - 127.0.0.1
  extraArgs:
    authorization-mode: Node,RBAC
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta1
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: "192.168.126.41:16443"
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.aliyuncs.com/google_containers
kind: ClusterConfiguration
kubernetesVersion: v1.19.0
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.1.0.0/16
scheduler: {}
EOF
```

init kubeadm
```
kubeadm init --config kubeadm-config.yaml
```


分发证书

```
for i in 192.168.126.45 192.168.126.46
do
    ssh root@$i mkdir -p /etc/kubernetes/pki /etc/kubernetes/pki/etcd
    scp /etc/kubernetes/pki/{ca.*,sa.*,front-proxy-ca.*} root@$i:/etc/kubernetes/pki
    scp /etc/kubernetes/pki/etcd/ca.* root@$i:/etc/kubernetes/pki/etcd
    scp /etc/kubernetes/admin.conf root@$i:/etc/kubernetes
done
```

查看kubeadm的节点加入代码

```
kubeadm token create --print-join-command
```

在master02和master03分别执行,以下命令，并且 **`--control-plane`这个参数必须加上**

```
kubeadm join 192.168.126.41:16443 --token mq8toa.3yo9o9125h2suumv     --discovery-token-ca-cert-hash sha256:0916d2179074f549a03100ded6d5f5faa3a0b23e904d8dadcbc2a65264a6808a --control-plane
```

以上，高可用的kubernetes就部署成功了
