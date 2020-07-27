# helm3

参考文档： https://github.com/helm/helm/releases/tag/v3.0.0

## 新的特性

https://helm.sh/docs/topics/v2_v3_migration/

Helm 3具有许多新功能，但其中一些功能应在此处重点介绍：

- 提出了tiller组件
  - 用客户端/库体系结构替换客户端/服务器（helm仅二进制）
  - 现在基于每个用户提供安全性（授权给Kubernetes用户群集安全性）
  - 现在，将发布版本存储为集群中的秘密，并且发布对象元数据已更改
  - 版本是基于版本名称空间持久保存的，不再存在于Tiller名称空间中

- 更新了Chart repository
  - helm search 现在支持本地存储库搜索和针对Helm Hub的搜索查询
  ```bash
  # 添加一个库
  helm repo add stable https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
  # 分别查找jenkins
  helm search hub jenkins
  helm search repo jenkins
  ```

- Chart apiVersion更改为“ v2”以进行以下规范更改：
  - 动态链接的图表依赖关系已移至Chart.yaml （requirements.yaml已删除，需求–>依赖关系）
  - 现在可以将library charts（帮助者/普通 charts）添加为动态链接的chart依赖项
  - chart具有一个type metadata 字段，以将chart定义为 application或library chart。默认情况下是应用程序，这意味着它是可渲染和可安装的
  - Helm 2 chart（apiVersion = v1）仍可安装

- 其他变化
  - helm 安装/设置简化：
    - 仅限Helm客户端（helm二进制文件）（无分iller）
    - 按原样运行
  - local或stable默认情况下未设置存储库
  - crd-install删除钩子并替换为crds图表中的目录，该目录中定义的所有CRD将在呈现任何图表之前安装
  - test-failure挂钩注释值已删除，并test-success已弃用。使用test替代
  - 删除/替换/添加的命令：
    - delete –> uninstall: 默认情况下删除所有发行历史记录（以前需要--purge
    - fetch –> pull
    - home (removed)
    - init (removed)
    - install: 需要发行版名称或--generate-name参数
    - inspect –> show
    - reset (removed)
    - serve (removed)
    - template: -x/ --execute参数重命名为-s/--show-only
    - upgrade: 添加了参数--history-max，该参数限制了每个版本保存的最大修订版本数（0为无限制）
  - Helm 3 Go库进行了很多更改，并且与Helm 2库不兼容
  - 发布二进制文件现在托管在 get.helm.sh

## 部署
下载二进制 https://github.com/helm/helm/releases  
```bash
wget https://get.helm.sh/helm-v3.1.1-linux-amd64.tar.gz
# 只需要下载二进制即安装完成
mv linux-amd64/helm /usr/local/bin/helm
# 添加仓库
#helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo add stable https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
helm repo update  
# 查找
helm search repo jenkins
# 创建一个实例
git clone https://github.com/helm/charts.git
cd charts
kubectl create namespace cicd
# 安装模版  helm install [name] [charts] [flag]
helm install jenkins --namespace cicd stable/jenkins
```
