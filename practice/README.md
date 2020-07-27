# 最佳实践概览
**此实践全部使用官方的方式进行部署，如有无意导致侵权行为，请告知**
1. 环境的准备
2. 下载二进制文件，主要使用在云服务器或者物理机上部署
3. 制作二进制文件（证书时长使用10年的）
4. 部署`kubernetes`集群,二进制或kubeadm皆可
5. 测试主要以二进制集群为主要环境

- ansible部署
https://github.com/AgoCan/ansible-kubernetes

- 官方api地址。可以根据版本号修改url进行访问查询
https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.15

- 其他官方推荐部署
https://github.com/kubernetes-sigs

kubespray

## 外网问题
centos 宿主机
```
export http_proxy="http://192.168.201.24:1087/"
export https_proxy="http://192.168.201.24:1087/"
```

容器：

创建一个文件，然后根据自己的代理进行转发

`cat /etc/systemd/system/docker.service.d/http-proxy.conf`

```
[Service]
Environment="HTTP_PROXY=http://192.168.201.24:1087/"
Environment="HTTPS_PROXY=http://192.168.201.24:1087/"
Environment="NO_PROXY=localhost,127.0.0.1,localaddress,.localdomain.com, .aliyuncs.com"
```

```
systemctl daemon-reload;systemctl restart docker
```
