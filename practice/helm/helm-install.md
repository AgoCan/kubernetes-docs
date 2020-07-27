# 部署helm

## 官网
官网： https://helm.sh/    
github仓库： https://github.com/helm/charts/tree/master/stable  
官方站点： https://hub.kubeapps.com/  

## 核心术语
  chart： 一个helm程序包，配置清单文件
  repository： charts仓库
  release： chart变成应用的一个实例

## 部署
https://github.com/helm/helm/releases 到这里下载helm客户端程序  

[rbac](/manifests/helm/rbac.yaml)  
先下载rbac的进行创建  
不使用rbac的话，`helm ls`会报错  
```
kubectl apply -f rbac.yaml
```

```bash
wget https://get.helm.sh/helm-v2.16.0-linux-amd64.tar.gz
tar xf helm-v2.16.0-linux-amd64.tar.gz
mv linux-amd64/helm /usr/bin/
helm init --service-account=tiller
# 替换helm源,国内源不轻易使用，仓库更新慢
#helm repo add stable https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
# 更新源
helm repo update
# 二进制安装的k8s 需要自行安装socat
yum install socat -y
# 所有机器执行拉取镜像操作
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.16.0
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.16.0 gcr.io/kubernetes-helm/tiller:v2.16.0
docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.16.0
# helm init --service-account tiller --upgrade -i registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.16.0 --stable-repo-url https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
# 测试
helm search stable/jenkins
# 查看使用帮助
helm inspect stable/jenkins

# 直接下单清单到本地
git clone https://github.com/helm/charts.git
cd charts
# 修改配置清单,一般来说，都需要修改配置文件来符合公司业务情况使用
vim stable/jenkins/values.yaml
# 安装redis
helm install --name hank-redis  stable/redis
# 缓存位置
～/.helm/cache/ # 对应的各种压缩包，tgz，解压即可
# 删除release
helm delete --purge hank-redis
# 创建一个模版
helm create myapp
# charts 介绍
# https://helm.sh/docs/developing_charts/#charts
# 查看pvc的创建
#url: /part06/extre01.md
# 安装失败的话 删除加目录的.helm
rm -rf /root/.helm
# 并且有tiller的话，删掉tiller
kubectl delete deploy -n kube-system tiller-deploy

# 更新，更新的时候如果使用了配置文件。还需要继续使用配置文件进行更新。
helm upgrade
```
