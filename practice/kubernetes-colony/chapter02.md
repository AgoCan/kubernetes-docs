cfssl 二进制下载

证书的方式使用的是 **域名** 的方式。既，/etc/hosts 或者dns服务需要配置好域名的解析  
如有特殊需求，可以在域名的地方改成ip即可

且证书配置是10年期限的，有必要的话，请把证书替换成一年的，替换证书保证线上的安全性  

**生成的 CA 证书和秘钥文件如下：**

```
ca-key.pem
ca.pem
kubernetes-key.pem
kubernetes.pem
kube-proxy.pem
kube-proxy-key.pem
admin.pem
admin-key.pem
```
**使用证书的组件如下：**  


- `etcd`：使用 ca.pem、kubernetes-key.pem、kubernetes.pem；
- `kube-apiserver`：使用 ca.pem、kubernetes-key.pem、kubernetes.pem；
- `kubelet`：使用 ca.pem；
- `kube-proxy`：使用 ca.pem、kube-proxy-key.pem、kube-proxy.pem；
- `kubectl`：使用 ca.pem、admin-key.pem、admin.pem；
- `kube-controller-manager`：使用 ca-key.pem、ca.pem



```bash
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
mv cfssl_linux-amd64 /usr/local/bin/cfssl

wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
chmod +x cfssl-certinfo_linux-amd64
mv cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo

export PATH=/usr/local/bin:$PATH
```

### 创建ca证书
自用证书： https://freessl.cn/  

字段说明

`ca-config.json`：可以定义多个 profiles，分别指定不同的过期时间、使用场景等参数；后续在签名证书时使用某个 profile；  
`signing`：表示该证书可用于签名其它证书；生成的 ca.pem 证书中 CA=TRUE；  
`server auth`：表示client可以用该 CA 对server提供的证书进行验证；  
`client auth`：表示server可以用该CA对client提供的证书进行验证；  

```bash
mkdir /root/ssl
cd /root/ssl
cat >> ca-config.json  << EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF
# 创建 CA 证书签名请求
cat >> ca-csr.json << EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "GuangDong",
      "L": "ShenZhen",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
/usr/local/bin/cfssl gencert -initca ca-csr.json | cfssljson -bare ca
ls ca*
```

### 创建etcd证书

其中本次的`etcd`和下面的`kubernetes`进行通用  

```bash
cat >> etcd-csr.json << EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "${node01ip}",
    "${node02ip}",
    "${node03ip}",
    "k8s01.example.com",
    "k8s02.example.com",
    "k8s03.example.com"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "GuangDong",
      "L": "ShenZhen",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
```
**生成 etcd 证书和私钥**  

```
/usr/local/bin/cfssl gencert -ca=ca.pem \
-ca-key=ca-key.pem \
-config=ca-config.json \
-profile=kubernetes etcd-csr.json | cfssljson -bare etcd
```


### 创建 kubernetes 证书

创建 kubernetes 证书签名请求文件 `kubernetes-csr.json` ：
其中注意`10.96.0.1`与`kube-apiserver`的启动文件的配置参数进行匹配

创建私有证书的时候，需要把虚拟ip也给加上，也就是做请求的ip地址。  如果需要虚拟IP，请加上 `"${master01ip}",`
```bash
cat >> kubernetes-csr.json << EOF
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "10.96.0.1",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local",
    "${master01ip}",
    "${node01ip}",
    "${node02ip}",
    "${node03ip}",
    "k8s01.example.com",
    "k8s02.example.com",
    "k8s03.example.com"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "GuangDong",
      "L": "ShenZhen",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
```
- 如果 hosts 字段不为空则需要指定授权使用该证书的 IP 或域名列表，由于该证书后续被 etcd 集群和 kubernetes master 集群使用，所以上面分别指定了 etcd 集群、kubernetes master 集群的主机 IP 和 kubernetes 服务的服务 IP（一般是 kube-apiserver 指定的 service-cluster-ip-range 网段的第一个IP，如 10.254.0.1）。  
- 这是最小化安装的kubernetes集群，包括一个私有镜像仓库，三个节点的kubernetes集群，以上物理节点的IP也可以更换为主机名。  
**生成 kubernetes 证书和私钥**  

```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
ls kubernetes*
```

### 创建 admin 证书
创建 admin 证书签名请求文件 admin-csr.json：  
```bash
cat >> admin-csr.json << EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "GuangDong",
      "L": "ShenZhen",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF
```
- 后续 kube-apiserver 使用 RBAC 对客户端(如 kubelet、kube-proxy、Pod)请求进行授权；
- kube-apiserver 预定义了一些 RBAC 使用的 RoleBindings，如 cluster-admin 将 Group system:masters 与 Role cluster-admin 绑定，该 Role 授予了调用kube-apiserver 的所有 API的权限；
- O 指定该证书的 Group 为 system:masters，kubelet 使用该证书访问 kube-apiserver 时 ，由于证书被 CA 签名，所以认证通过，同时由于证书用户组为经过预授权的 system:masters，所以被授予访问所有 API 的权限；

**注意** ：这个admin 证书，是将来生成管理员用的kube config 配置文件用的，现在我们一般建议使用RBAC 来对kubernetes 进行角色权限控制， kubernetes 将证书中的CN 字段 作为User， O 字段作为 Group（具体参考 Kubernetes中的用户与身份认证授权中 X509 Client Certs 一段）。

在搭建完 kubernetes 集群后，我们可以通过命令: kubectl get clusterrolebinding cluster-admin -o yaml ,查看到 clusterrolebinding cluster-admin 的 subjects 的 kind 是 Group，name 是 system:masters。 roleRef 对象是 ClusterRole cluster-admin。 意思是凡是 system:masters Group 的 user 或者 serviceAccount 都拥有 cluster-admin 的角色。 因此我们在使用 kubectl 命令时候，才拥有整个集群的管理权限。可以使用 kubectl get clusterrolebinding cluster-admin -o yaml 来查看。

生成证书
```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
ls admin*
```

### 创建 kube-proxy 证书

```bash
cat >> kube-proxy-csr.json << EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "GuangDong",
      "L": "ShenZhen",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
```
- CN 指定该证书的 User 为 system:kube-proxy；
- kube-apiserver 预定义的 RoleBinding system:node-proxier 将User system:kube-proxy 与 Role system:node-proxier 绑定，该 Role 授予了调用 kube-apiserver Proxy 相关 API 的权限；

**生成 kube-proxy 客户端证书和私钥**

```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy
ls kube-proxy*
```

### 分发证书

证书不能三台机器同时生成，只能一个地方进行生成

```bash
mkdir -p /etc/kubernetes/ssl
cp * /etc/kubernetes/ssl
scp -r /etc/kubernetes ${node02ip}:/etc/kubernetes
scp -r /etc/kubernetes ${node03ip}:/etc/kubernetes
cd ..
```
