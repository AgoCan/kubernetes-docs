# flannel 二进制部署
flannel二进制部署，需要修改`docker.service`的值，会导致重启出现问题，暂时还没有解决方案，这里暂不填写内容


# calico 部署
**部署网络插件的时候，需要先把hosts和node的节点名称给配置好**
## 部署calico-cni
官方文档：  https://docs.projectcalico.org/getting-started/kubernetes/installation/integration#installing-the-calico-cni-plugins  

```bash
# 使用下面的manifests部署的时候，就不需要下载这两个命令 测试过11版本和12版本
#wget -N https://github.com/projectcalico/cni-plugin/releases/download/v3.12.0/calico-amd64
#wget -N https://github.com/projectcalico/cni-plugin/releases/download/v3.12.0/calico-ipam-amd64
#mkdir -p /opt/cni/bin/
#mv ./calico-amd64 /opt/cni/bin/calico
#mv ./calico-ipam-amd64 /opt/cni/bin/calico-ipam
#ßchmod +x /opt/cni/bin/calico /opt/cni/bin/calico-ipam
```

## 部署calico

calico需要版本要求，既查看  https://docs.projectcalico.org/getting-started/kubernetes/requirements 官方文档进行匹配  


下载yaml文件，calico的端口好有
```bash
curl https://docs.projectcalico.org/v3.11/manifests/calico.yaml -O
```

根据自己配置的 `pod-cdir` 修改，该配置在`kube-proxy`有`--cluster-cdir`(是否需要跟controller-manager的配置一致，有待考证)，个人推荐手动修改，官方脚本修改会失败，导致calico启动失败，

```bash
查看自己的pod-cdir
kubectl get ippools -o yaml
```

```bash
# 10.244.0.0/16
POD_CIDR="<your-pod-cidr>" \
sed -i -e "s?192.168.0.0/16?$POD_CIDR?g" calico.yaml
```

```bash
kubectl apply -f calico.yaml
```


## 报错信息

当`calico-kube-controllers-xxxxx` 出现`pending`的时候，

需要注意 `cni`的命令路径是否正确

查看

```bash
# 查看事件
kubectl get events -n kube-system
```

```
kubectl taint nodes k8s-master01 node.kubernetes.io/not-ready:NoSchedule-
```


详细请查看官方文档  https://docs.projectcalico.org/v3.11/getting-started/kubernetes/installation/calico
新官方文档地址  https://docs.projectcalico.org/introduction/    




参考文档：

https://docs.projectcalico.org/v3.11/getting-started/kubernetes/installation/calico
