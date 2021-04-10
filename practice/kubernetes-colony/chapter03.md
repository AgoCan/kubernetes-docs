# 创建etcd集群
http://play.etcd.io/

etcd 一致性分布式存储

[CAP原则百度百科](https://baike.baidu.com/item/CAP%E5%8E%9F%E5%88%99/5712863?fr=aladdin)

https://github.com/maemual/raft-zh_cn/blob/master/raft-zh_cn.md

http://thesecretlivesofdata.com/raft/

## TLS 认证文件

ETCD 3.1 之后不支持监听域名，证书需要改成IP形式

需要为 etcd 集群创建加密通信的 TLS 证书，这里使用上次创建的etcd证书

下载二进制文件

https://github.com/coreos/etcd/releases

这里使用的版本是3.2.8

```bash
wget https://github.com/etcd-io/etcd/releases/download/v3.2.28/etcd-v3.2.28-linux-amd64.tar.gz
tar xf etcd-v3.2.28-linux-amd64.tar.gz
mv etcd-v3.2.28-linux-amd64/etcd* /usr/local/bin
# 或者使用yum的方式安装，版本不固定
#yum install etcd
#
scp /usr/local/bin/etcd* ${node02ip}:/usr/local/bin
scp /usr/local/bin/etcd* ${node03ip}:/usr/local/bin

```

## 创建 etcd 的 systemd unit 文件
在/usr/lib/systemd/system/目录下创建文件etcd.service，内容如下。注意替换IP地址为你自己的etcd集群的主机IP。

```bash
cat > etcd.service << \EOF
[Unit]
Description=Etcd Server
After=network.target

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd
EnvironmentFile=-/etc/etcd/etcd.conf
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /usr/local/bin/etcd"

[Install]
WantedBy=multi-user.target
EOF
scp  etcd.service ${node01ip}:/usr/lib/systemd/system/
scp  etcd.service ${node02ip}:/usr/lib/systemd/system/
scp  etcd.service ${node03ip}:/usr/lib/systemd/system/
```
- 指定 etcd 的工作目录为 /var/lib/etcd，数据目录为 /var/lib/etcd，需在启动服务前创建这个目录，否则启动服务的时候会报错“Failed at step CHDIR spawning /usr/bin/etcd: No such file or directory”；
- 为了保证通信安全，需要指定 etcd 的公私钥(cert-file和key-file)、Peers 通信的公私钥和 CA 证书(peer-cert-file、peer-key-file、peer-trusted-ca-file)、客户端的CA证书（trusted-ca-file）；
- 创建 kubernetes.pem 证书时使用的 kubernetes-csr.json 文件的 hosts 字段包含所有 etcd 节点的IP，否则证书校验会出错；
- --initial-cluster-state 值为 new 时，--name 的参数值必须位于 --initial-cluster 列表中；
**需要了解更多的参数使用etcd --help 进行查看**

环境变量配置文件`/etc/etcd/etcd.conf`
```bash
ssh ${node01ip} mkdir -p /etc/etcd/ /var/lib/etcd
ssh ${node02ip} mkdir -p /etc/etcd/ /var/lib/etcd
ssh ${node03ip} mkdir -p /etc/etcd/ /var/lib/etcd

```

```bash
cat > etcd.conf << EOF
#[member]
ETCD_NAME="node-name"
ETCD_DATA_DIR="/var/lib/etcd"
#ETCD_SNAPSHOT_COUNTER="10000"
#ETCD_HEARTBEAT_INTERVAL="100"
#ETCD_ELECTION_TIMEOUT="1000"
ETCD_LISTEN_PEER_URLS="https://node-ip:2380"
ETCD_LISTEN_CLIENT_URLS="https://node-ip:2379,https://127.0.0.1:2379,http://127.0.0.1:4001"
#ETCD_MAX_SNAPSHOTS="5"
#ETCD_MAX_WALS="5"
#ETCD_CORS=""
#[cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://node-ip:2380"
# if you use different ETCD_NAME (e.g. test),
# set ETCD_INITIAL_CLUSTER value for this name, i.e. "test=http://..."
ETCD_INITIAL_CLUSTER="etcd-node01=https://${node01ip}:2380,etcd-node02=https://${node02ip}:2380,etcd-node03=https://${node03ip}:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="k8s-etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="https://node-ip:2379"
#[security]
CLIENT_CERT_AUTH="true"
ETCD_CA_FILE="/etc/kubernetes/ssl/ca.pem"
ETCD_CERT_FILE="/etc/kubernetes/ssl/kubernetes.pem"
ETCD_KEY_FILE="/etc/kubernetes/ssl/kubernetes-key.pem"
PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_CA_FILE="/etc/kubernetes/ssl/ca.pem"
ETCD_PEER_CERT_FILE="/etc/kubernetes/ssl/kubernetes.pem"
ETCD_PEER_KEY_FILE="/etc/kubernetes/ssl/kubernetes-key.pem"
EOF
#修改对应ip地址
name_id=1
for ip in ${node01ip} ${node02ip} ${node03ip}
do
  name=etcd-node0${name_id}
  sed  "s#node-name#${name}#g" etcd.conf > ${name}.conf
  sed -i "s#node-ip#${ip}#g" ${name}.conf
  scp ${name}.conf ${ip}:/etc/etcd/etcd.conf
  ((name_id++))
done
```
**注意**： 监听地址修改成对应主机的`IP`地址,即，此处的`10.10.10.6`和`10.10.10.7`
这是10.10.10.5节点的配置，其他两个etcd节点只要将上面的IP地址改成相应节点的IP地址即可。ETCD_NAME换成对应节点的etcd-node01 etcd-node02 etcd-node03 。

其中 **`ETCD_INITIAL_CLUSTER`** 是指定集群的机器，不能出现空格。不然会抛出异常错误

## 启动 etcd 服务

```bash
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
systemctl status etcd
```

同时操作,由于启动`etcd`需要一起启动，所以，这里的串行暂时不能使用
```bash
for ip in ${node01ip} ${node02ip} ${node03ip}
do
  ssh $ip systemctl daemon-reload
  ssh $ip systemctl enable etcd
  #ssh $ip systemctl start etcd
  #ssh $ip systemctl status etcd
done
```

在所有的 kubernetes master 节点重复上面的步骤，直到所有机器的 etcd 服务都已启动。

如果打开的防火墙，请把2379和2380端口开发，以centos7为例：

```bash
firewall-cmd --zone=public --add-port=2380/tcp --permanent
firewall-cmd --zone=public --add-port=2379/tcp --permanent
firewall-cmd --reload
```

## 验证服务
在任一 kubernetes master 机器上执行如下命令：
```bash
etcdctl \
  --endpoints=https://${node01ip}:2379 \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
  cluster-health
```
结果最后一行为 cluster is healthy 时表示集群服务正常。

其中--endpoints可以不指定，直接在etcd的三台机器中的一台进行执行即可

```bash
etcdctl \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
  cluster-health
```

etcd 3.4版本
```
etcdctl --cacert=/etc/kubernetes/ssl/ca.pem --cert=/etc/kubernetes/ssl/kubernetes.pem --key=/etc/kubernetes/ssl/kubernetes-key.pem  --endpoints="https://192.168.126.31:2379 https://192.168.126.32:2379" endpoint health
```
