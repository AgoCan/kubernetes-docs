# kubectl部署

**注意： 在三台机器上都部署kube-apiserver、kube-controller-manager、kube-scheduler**

```bash
export KUBE_APISERVER="https://${master01ip}:6443"
# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER}
# 设置客户端认证参数
kubectl config set-credentials admin \
  --client-certificate=/etc/kubernetes/ssl/admin.pem \
  --embed-certs=true \
  --client-key=/etc/kubernetes/ssl/admin-key.pem
# 设置上下文参数
# 使用admin用户来管理集群。 配置项在默认的 ~/.kube/config
kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin
# 设置默认上下文
kubectl config use-context kubernetes
# 如果有需要，scp
#scp -r ~/.kube ${node02ip}:~
#scp -r ~/.kube ${node03ip}:~
```

- `admin.pem` 证书 `OU` 字段值为 `system:masters`，`kube-apiserver` 预定义的 `RoleBinding cluster-admin` 将 `Group system:masters` 与 `Role cluster-admin` 绑定，该 Role 授予了调用`kube-apiserver` 相关 `API` 的权限
- 生成的 `kubeconfig` 被保存到 `~/.kube/config` 文件

**注意：** `~/.kube/config`文件拥有对该集群的最高权限，请妥善保管。

## 增加补全命令功能

```bash
yum install -y bash-completion
source /usr/share/bash-completion/bash_completion
source <(kubectl completion bash)
echo 'source /usr/share/bash-completion/bash_completion' >> /etc/profile
echo 'source <(kubectl completion bash)' >> /etc/profile
```
