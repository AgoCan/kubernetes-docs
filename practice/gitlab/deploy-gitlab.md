# 利用helm3部署gitlab

官方文档：https://docs.gitlab.com/charts/

官方git: https://gitlab.com/gitlab-org/charts/gitlab

前提部署好`helm`

```bash
# 增加gitlab官方仓库
helm repo add gitlab https://charts.gitlab.io/
# 更新仓库
helm repo update
# 查看
helm search repo gitlab/gitlab

kubectl create namespace gitlab

helm install gitlab --namespace gitlab gitlab/gitlab \
--set certmanager-issuer.email=me@example.com \
--set global.edition=ce

```
设置参数指南 [官方文档](https://docs.gitlab.com/charts/installation/deployment.html)


## 镜像拉取不下来的修改方式
> 已经放弃使用helm部署gitlab。有外网的可以尽情的想用
> 再次更新，镜像除了一个ingress对应的 k8s.gcr.io，以外都可以拉取，虽然比较慢。文档继续更新

请自己查找镜像并做替换。然后使用外网的机器进行拉取镜像。如果信得过。直接使用hank997已经制作好的镜像 **镜像对应关系在文末** 。

还是推荐自己拉取制作。可控，防止木马和病毒

获取镜像并去重
```bash
kubectl get pod  -n gitlab -o yaml | grep image: | awk -F "image:" '{print $2}' | sort|uniq > /tmp/gitlab_all_iamge.txt
```

```bash
#!/bin/bash
registry_name=hank997
for i in `cat /tmp/gitlab_all_iamge.txt`
do
  docker pull $i
  new_image="hank997/helm-gitlab-`echo $i | awk -F "/" '{print $NF}'`"
  docker tag $i $new_image
  docker push $new_image
done
```

```bash
# 新部署方式，全部使用hank997镜像
helm install gitlab --version 3.2.3 --namespace gitlab gitlab/gitlab \
--set certmanager-issuer.email=me@example.com \
--set global.edition=ce \
--set nginx-ingress.defaultBackend.image.repository=registry.cn-hangzhou.aliyuncs.com/google_containers/defaultbackend \
--set nginx-ingress.defaultBackend.image.tag=1.4 
```






```
docker.io/bitnami/minideb:stretch                                                hank997/helm-gitlab-minideb:stretch
docker.io/bitnami/postgres-exporter:0.7.0-debian-9-r12                           hank997/helm-gitlab-postgres-exporter:0.7.0-debian-9-r12
docker.io/bitnami/postgresql:10.9.0                                              hank997/helm-gitlab-postgresql:10.9.0
docker.io/bitnami/redis:5.0.7-debian-9-r50                                       hank997/helm-gitlab-redis:5.0.7-debian-9-r50
docker.io/bitnami/redis-exporter:1.3.5-debian-9-r23                              hank997/helm-gitlab-redis-exporter:1.3.5-debian-9-r23
gitlab/gitlab-runner:alpine-v12.9.0                                              hank997/helm-gitlab-gitlab-runner:alpine-v12.9.0
jimmidyson/configmap-reload:v0.3.0                                               hank997/helm-gitlab-configmap-reload:v0.3.0
k8s.gcr.io/defaultbackend:1.4                                                    hank997/helm-gitlab-defaultbackend:1.4
minio/minio:RELEASE.2017-12-28T01-21-00Z                                         hank997/helm-gitlab-minio:RELEASE.2017-12-28T01-21-00Z
prom/prometheus:v2.15.2                                                          hank997/helm-gitlab-prometheus:v2.15.2
quay.io/jetstack/cert-manager-cainjector:v0.10.1                                 hank997/helm-gitlab-cert-manager-cainjector:v0.10.1
quay.io/jetstack/cert-manager-controller:v0.10.1                                 hank997/helm-gitlab-cert-manager-controller:v0.10.1
quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.21.0            hank997/helm-gitlab-nginx-ingress-controller:0.21.0
registry.gitlab.com/gitlab-org/build/cng/alpine-certificates:20171114-r3         hank997/helm-gitlab-alpine-certificates:20171114-r3
registry.gitlab.com/gitlab-org/build/cng/gitaly:v12.9.3                          hank997/helm-gitlab-gitaly:v12.9.3
registry.gitlab.com/gitlab-org/build/cng/gitlab-container-registry:v2.8.2-gitlab hank997/helm-gitlab-gitlab-container-registry:v2.8.2-gitlab
registry.gitlab.com/gitlab-org/build/cng/gitlab-exporter:6.1.0                   hank997/helm-gitlab-gitlab-exporter:6.1.0
registry.gitlab.com/gitlab-org/build/cng/gitlab-shell:v12.0.0                    hank997/helm-gitlab-gitlab-shell:v12.0.0
registry.gitlab.com/gitlab-org/build/cng/gitlab-sidekiq-ce:v12.9.3               hank997/helm-gitlab-gitlab-sidekiq-ce:v12.9.3
registry.gitlab.com/gitlab-org/build/cng/gitlab-task-runner-ce:v12.9.3           hank997/helm-gitlab-gitlab-task-runner-ce:v12.9.3
registry.gitlab.com/gitlab-org/build/cng/gitlab-webservice-ce:v12.9.3            hank997/helm-gitlab-gitlab-webservice-ce:v12.9.3
registry.gitlab.com/gitlab-org/build/cng/gitlab-workhorse-ce:v12.9.3             hank997/helm-gitlab-gitlab-workhorse-ce:v12.9.3
registry.gitlab.com/gitlab-org/build/cng/kubectl:1.13.12                         hank997/helm-gitlab-kubectl:1.13.12
```
