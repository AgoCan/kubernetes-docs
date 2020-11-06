# kubelet部署
**已经修复，不需要下面的参数了**
开机自启会失败，有待考察，请使用监控脚本进行监控启动

```bash

mkdir /k8s-scripts
cat >> /k8s-scripts/monitor-kubelet.sh << \EOF
systemctl status kubelet > /dev/null 2>&1
if [[ $? != 0 ]]
then
  systemctl start kubelet
fi
EOF
chmod +x /etc/rc.d/rc.local
echo sh /k8s-scripts/monitor-kubelet.sh >> /etc/rc.d/rc.local
```

## 部署docker

docker 属于节点，需要把所有机器都部署上
```bash
wget -O /etc/yum.repos.d/docker-ce.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 查看docker-ce版本
yum --showduplicates list docker-ce

# 安装docker-ce
yum -y install docker-ce
# 启动服务
systemctl enable docker
systemctl start docker

# 参考文档 http://mirrors.ustc.edu.cn/help/dockerhub.html
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn/"]
}
EOF
systemctl restart docker
```

## 部署kubelet

> bootstrap: 使用谷歌翻译会得到:"引导程序"，它是一种**技术**， 一种通过一些初始指令将程序加载到计算机中的技术，该初始指令允许从输入设备中引入其余程序。
> TLS: 安全传输层协议.
> TLS bootstrap: 在Kubernetes集群中，工作程序节点上的组件（kubelet和kube-proxy）需要与Kubernetes主组件（特别是kube-apiserver）通信。为了确保通信保持私密，不受干扰，并确保群集的每个组件都在与另一个受信任的组件通信。

*上面都是官话，个人理解就是： 它是一种技术，解决链接的初始化问题*

都在master执行，除了 `kubelet.service`这个文件，这个文件注意配置好即可，主要是节点名称

文档： https://kubernetes.io/docs/reference/access-authn-authz/rbac/

```bash
/usr/local/bin/kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap

```

```bash
export K8S_API_URL=${master01ip}
/usr/local/bin/kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/ssl/ca.pem \
--embed-certs=true \
--server=https://${K8S_API_URL}:6443 \
--kubeconfig=bootstrap.kubeconfig
```

```bash
export TOKEN=$(awk -F "," '{print $1}' /etc/kubernetes/ssl/bootstrap-token.csv)
/usr/local/bin/kubectl config set-credentials kubelet-bootstrap \
--token=${TOKEN} \
--kubeconfig=bootstrap.kubeconfig
```

```bash
/usr/local/bin/kubectl config set-context default \
--cluster=kubernetes \
--user=kubelet-bootstrap \
--kubeconfig=bootstrap.kubeconfig
```

```bash
/usr/local/bin/kubectl config use-context default --kubeconfig=bootstrap.kubeconfig
```

```bash
mv bootstrap.kubeconfig /etc/kubernetes/
scp /etc/kubernetes/bootstrap.kubeconfig ${node02ip}:/etc/kubernetes/
scp /etc/kubernetes/bootstrap.kubeconfig ${node03ip}:/etc/kubernetes/
```

**注意--hostname-override=k8s-master01 节点名称请不要一样**

```bash
mkdir -p /var/lib/kubelet
cat > kubelet.service << \EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
WorkingDirectory=/var/lib/kubelet
ExecStart=/usr/local/bin/kubelet  \
    --hostname-override=node-name   \
    --pod-infra-container-image=mirrorgooglecontainers/pause-amd64:3.1   \
    --bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig   \
    --kubeconfig=/etc/kubernetes/kubelet.kubeconfig   \
    --cert-dir=/etc/kubernetes/ssl   \
    --network-plugin=cni   \
    --cni-conf-dir=/etc/cni/net.d   \
    --cni-bin-dir=/opt/cni/bin   \
    --cluster-dns=10.96.0.2   \
    --cluster-domain=cluster.local.   \
    --hairpin-mode hairpin-veth   \
    --fail-swap-on=false   \
    --logtostderr=true   \
    --v=2   \
    --logtostderr=false   \
    --log-dir=/var/log/kubernetes   \
    --feature-gates=DevicePlugins=true
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target

EOF
for ip in ${node01ip} ${node02ip} ${node03ip}
do
  ssh ${ip} mkdir -p /var/lib/kubelet
  sed "s#node-name#${ip}#g" kubelet.service > kubelet.service.bak
  scp kubelet.service.bak ${ip}:/usr/lib/systemd/system/kubelet.service
done
```

```

```

参数介绍
- `--cluster-dns` 需要指定安装的`coredns`的ip地址
- `--hostname-override`是节点名称，最好和主机名一一对应
- `--cni-bin-dir` 指定cni的目录，使用默认即可`/opt/cni/bin`。 一旦找不到cni的插件。`kubectl get node`会发现部署完网络插件之后节点却还一直都是`NotReady`

```bash
systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet
systemctl status kubelet
```

注意：

```bash
kubelet 安装之后，使用systemctl start 的时候会报错， 说命令找不到
重启服务器之后就好了
```

# 到master节点执行

```bash
/usr/local/bin/kubectl get csr
# 同意节点加入，虚拟机测试有点慢，请耐心等待
/usr/local/bin/kubectl get csr|grep 'Pending' | awk 'NR>0{print $1}'| xargs kubectl certificate approve
/usr/local/bin/kubectl get node

# 重新加载节点
# 删除csr
#kubectl delete csr --all
# 删除节点
#kubectl delete node --all
#删除自动生成密钥
#rm -rf /etc/kubernetes/ssl/kubelet*
# 并且需要重新生成bootstrap.kubeconfig
```




## 为master打上标签

```bash
/usr/local/bin/kubectl label node k8s-master01 node-role.kubernetes.io/master=k8s-master01
/usr/local/bin/kubectl label node k8s-node01 node-role.kubernetes.io/node=k8s-node01
kubectl get node --show-labels
# 删除所有节点的标签
kubectl  label node --all kubernetes.io/role-
```

如果不让调度

```bash
kubectl  patch node ${node01ip} -p '{"spec":{"unschedulable":true}}'
# 相对应的
kubectl  patch node ${node01ip} -p '{"spec":{"unschedulable":false}}'
```
查看,出现SchedulingDisabled
```bash
[root@demo ansible]# kubectl  get node
NAME            STATUS                     ROLES    AGE   VERSION
10.10.10.5   Ready,SchedulingDisabled   master   78m   v1.16.2
```

## 注意

1. 这个部署，`kubelet`的启动有问题。 需要在系统起来之后执行
  ```bash
  systemctl stop kubelet
  systemctl start kubelet
  ```

2. `bubelet`加入节点后，会在加目录加入 `.kube`的目录，该目录是cni的主要目录，不能丢失，不然创建容器会出现如下的错误

  ```
  Events:
    Type     Reason                  Age                    From                   Message
    ----     ------                  ----                   ----                   -------
    Normal   Scheduled               <unknown>              default-scheduler      Successfully assigned profession-cvmart-project/profession-cvmart-project-1-instance-1-train-11-b5kjg to 192.168.1.80
    Warning  FailedCreatePodSandBox  6m2s                   kubelet, 192.168.1.80  Failed create pod sandbox: rpc error: code = Unknown desc = failed to set up sandbox container "d75ef828dbc4ec744684d5973a7cb05ef73f8aab1920b661887321069d9194d2" network for pod "profession-cvmart-project-1-instance-1-train-11-b5kjg": networkPlugin cni failed to set up pod "profession-cvmart-project-1-instance-1-train-11-b5kjg_profession-cvmart-project" network: stat /root/.kube/config: no such file or directory
  ```

  修复：

  ```
  拿其他的节点的.kube 目录scp过来即可。
  ```

3. 加新节点
  在master重新生成 `bootstrap.kubeconfig`
  ```bash
  export K8S_API_URL=${master01ip}
  /usr/local/bin/kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=https://${K8S_API_URL}:6443 \
  --kubeconfig=bootstrap.kubeconfig

  export TOKEN=$(awk -F "," '{print $1}' /etc/kubernetes/ssl/bootstrap-token.csv)
  /usr/local/bin/kubectl config set-credentials kubelet-bootstrap \
  --token=${TOKEN} \
  --kubeconfig=bootstrap.kubeconfig

  /usr/local/bin/kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig

  /usr/local/bin/kubectl config use-context default --kubeconfig=bootstrap.kubeconfig
  ```
  并且移动到新节点上。
  直接复制其他节点的话，会出现

  ```
  kubelet get scr
  # 会出现 No resources found.
  ```
