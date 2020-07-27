# 二进制的下载

## 下载kubernetes
kubernetes在内网下载非常慢，不推荐直接下载，我把二进制文件打包在百度云中，方便所有人下载

url: 地址已经替换，可以使用下面的地址直接替换版本号即可使用  

下载地址的查找，请时刻关注kubernetes的github地址: https://github.com/kubernetes  

其中server包含了所有的二进制包，既，可只下载server的包即可
```bash
# 客户端下载
wget https://dl.k8s.io/v1.16.3/kubernetes-client-linux-amd64.tar.gz
# 服务端下载
wget https://dl.k8s.io/v1.16.3/kubernetes-server-linux-amd64.tar.gz
# 节点下载
wget https://dl.k8s.io/v1.16.3/kubernetes-node-linux-amd64.tar.gz
```

```bash
tar xf kubernetes-client-linux-amd64.tar.gz
tar xf kubernetes-server-linux-amd64.tar.gz
tar xf kubernetes-node-linux-amd64.tar.gz

mv kubernetes/client/bin/kubectl /usr/local/bin/
mv kubernetes/node/bin/kubelet kubernetes/node/bin/kube-proxy /usr/local/bin/
mv kubernetes/server/bin/kube-apiserver kubernetes/server/bin/kube-controller-manager kubernetes/server/bin/kube-scheduler /usr/local/bin/
# 多master的方案，需要把所有二进制文件拷贝过去
scp /usr/local/bin/kube* ${node02ip}:/usr/local/bin/
scp /usr/local/bin/kube* ${node03ip}:/usr/local/bin/
```
