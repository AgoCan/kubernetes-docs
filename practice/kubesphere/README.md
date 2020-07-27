# 由于业务的需要，把笔记记录在此处

## 在kubernetes上进行部署

**前提条件，请先部署kubernetes 二进制和kubeadm皆可**

[二进制部署文档](https://kubernetes.hankbook.cn/practice/kubernetes-colony/)




[helm部署](https://kubernetes.hankbook.cn/practice/helm/helm-install.html)

**helm此文档使用的是2.16.0版本，官方说明有bug，所以不推荐使用此版本部署**

需要在kubesphere的部署节点上也放置 `helm`二进制命令，不然会报错

[nfs-storageclass部署](https://kubernetes.hankbook.cn/practice/storage/nfs/nfs-storageclass.html)  

nfs记得创建目录，切修改storageclass的默认值



部署kubesphere

```bash
kubectl apply -f https://raw.githubusercontent.com/kubesphere/ks-installer/master/kubesphere-minimal.yaml
```

查看日志

```bash
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f
```

打开应用商店

https://kubesphere.com.cn/docs/v2.1/zh-CN/installation/install-openpitrix/

创建secret

```bash
kubectl -n kubesphere-system create secret generic kubesphere-ca  \
--from-file=ca.crt=/etc/kubernetes/ssl/ca.pem  \
--from-file=ca.key=/etc/kubernetes/ssl/ca-key.pem
```

```bash
kubectl edit cm -n kubesphere-system ks-installer
```
把False改为True
```yaml
openpitrix:
      enabled: True
```


参考文档:

https://kubesphere.com.cn/docs/v2.1/zh-CN/installation/prerequisites/
