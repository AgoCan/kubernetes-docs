* [汉克书-kubernetes指南与实践](/)
* [一、kubernetes介绍](overview/)
  * [1.kubernetes是什么](overview/whatis-k8s.md)
  * [2.kubernetes组件](overview/components.md)
  * [3.kubeadm部署kubernetes](overview/kubeadm-install.md)
  * [3.kubeadm部署高可用kubernetes](overview/kubeadm-ha-install.md)
  * [5.kubernetes-api](overview/kubernetes-api.md)
  * [CNI](overview/cni.md)
  * [CRI](overview/cri.md)
  * [CSI](overview/csi.md)
* [二、kubernetes之Pod](pods/)
  * [1. Pod概览](pods/pod-overview.md)
  * [2. Pod Preset](pods/podpreset.md)
  * [3. Pod 拓扑扩展约束](pods/pod-topology-spread-constraints.md)
  * [4. 干扰](pods/disruptions.md)
  * [5. 临时容器](pods/ephemeral-containers.md)
  * [6. 初始化init容器](pods/init-container.md)
  * [7. Pod 的生命周期](pods/pod-lifecycle.md)
* [二、访问api](api-overview/)
  * [rbac授权](api-overview/rbac.md)
* [三、kubernetes之控制器](controllers/)
  * [1. ReplicaSet](controllers/replicaset.md)
  * [2. ReplicationController](controllers/replicationcontroller.md)
  * [3. Deployment](controllers/deployment.md)
  * [4. StatefulSet](controllers/statefulset.md)
  * [5. DaemonSet](controllers/daemonset.md)
  * [5. Jobs](controllers/jobs.md)
  * [5. CronJob](controllers/cronjob.md)
* [四、kubernetes之服务发现](service-discovery/)
  * [1. service](service-discovery/service.md)
  * [2. ingress](service-discovery/ingress/)
    * [2.1 控制器](service-discovery/ingress/ingress-controller.md)
    * [2.2 部署](service-discovery/ingress/install.md)
    * [2.3 tls添加](service-discovery/ingress/tls.md)
  * [3. 网络策略](service-discovery/network-policies.md)
* [五、kubernetes之网络](networkings/)
  * [flannel](networkings/flannel/)
  * [calico](networkings/calico/)
    * [faq](networkings/calico/faq.md)
* [六、kubernetes之存储](storage/)
  * [1. secret](storage/secret.md)
  * [2. configmap](storage/configmap.md)
  * [3. volume](storage/volume.md)
  * [4. 持久化存储](storage/persistent-volume.md)
  * [5. 动态持久化存储](storage/storageclass.md)
  * [6. 本地存储](storage/local-persistent-storage.md)
* [七、kubernetes之集群资源管理](cluster-resources/)
  * [1. Node](cluster-resources/nodes.md)
  * [2. Namespace](cluster-resources/namespace.md)
  * [3. Label](cluster-resources/label.md)
  * [4. Annotation](cluster-resources/annotations.md)
  * [5. Taint和Toleration](cluster-resources/taint-and-toleration.md)
  * [6. 亲和性和反亲和性](cluster-resources/assign-pod-node.md)
  * [7. 控制节点上的CPU管理策略](cluster-resources/cpu-management-policies.md)
  * [8. 控制节点上的拓扑管理策略](cluster-resources/topology-manager.md)
* [八、kubernetes之实践](practice/)
  * [1. kubernetes集群部署](practice/kubernetes-colony/)
    * [附: 多master的ha介绍与部署](practice/kubernetes-colony/chapter12.md)
    * [1.1 二进制下载](practice/kubernetes-colony/chapter01.md)
    * [1.2 TLS证书创建和分发](practice/kubernetes-colony/chapter02.md)
    * [1.3 创建etcd集群](practice/kubernetes-colony/chapter03.md)
    * [1.4 master之api服务](practice/kubernetes-colony/chapter04.md)
    * [1.5 master之controller服务](practice/kubernetes-colony/chapter05.md)
    * [1.6 master之scheduler服务](practice/kubernetes-colony/chapter06.md)
    * [1.7 client之kubectl服务](practice/kubernetes-colony/chapter07.md)
    * [1.8 node之kubelet服务](practice/kubernetes-colony/chapter08.md)
    * [1.9 node之proxy服务](practice/kubernetes-colony/chapter09.md)
    * [1.10 网络插件部署](practice/kubernetes-colony/chapter10.md)
    * [1.11 其他组件部署](practice/kubernetes-colony/chapter11.md)
  * [2. kubeadm生产部署介绍](practice/kubeadm-colony/)
    * [2.1 配置文件的修改](practice/kubeadm-colony/chapter01.md)
  * [3. 存储storage](practice/storage/)
    * [3.1 nfs](practice/storage/nfs/nfs.md)
      * [3.1.1 nfs支持storageClass](practice/storage/nfs/nfs-storageclass.md)
  * [4. helm](practice/helm/)
    * [4.1 helm部署](practice/helm/helm-install.md)
    * [4.2 helm3部署](practice/helm/helm3-install.md)
  * [5. harbor仓库](practice/harbor/)
    * [5.1 helm部署](practice/harbor/helm-install.md)
    * [5.2 docker-compose部署](practice/harbor/chapter01.md)
    * [5.3 集群部署](practice/harbor/cluster.md)
    * [5.4 镜像备份](practice/harbor/backup.md)
    * [5.5 harbor-faq](practice/harbor/faq.md)
  * [6. 英伟达GPU插件](practice/nvidia/)
    * [1. 安装nvidia-docker](practice/nvidia/deploy-driver.md)
    * [2. containerd支持nvidia](practice/nvidia/containerd.md)
  * [7. rook](practice/rook/)
    * [7.1 rook-ceph](practice/rook/ceph/)
      * [7.1.1 部署](practice/rook/ceph/deployment.md)
      * [7.1.2 rook-cleanup](practice/rook/ceph/cleanup.md)
      * [7.1.3 faq](practice/rook/ceph/faq.md)
  * [8. 监控](practice/monitor/)
    * [8.1 metrics-server](practice/monitor/metrics-server.md)
    * [8.2 普罗米修斯prometheus](practice/monitor/prometheus/)
      * [8.2.1 prometheus部署](practice/monitor/prometheus/deploy-prometheus.md)
  * [9. 日志收集](practice/elastic/)
    * [9.1 log-pilot+ES+Kibana环境搭建](practice/elastic/deploy2.md)
    * [9.2 helm部署](practice/elastic/helm-install.md)
    * [9.2 operator部署](practice/elastic/operator.md)
  * [10. mysql](practice/mysql/)
    * [10.1 手动部署](practice/mysql/manual.md)
  * [11. gitlab](practice/gitlab/)
    * [11.1 部署](practice/gitlab/deploy-gitlab.md)
    * [11.2 yum部署](practice/gitlab/binary-install.md)
  * [12. 持续集成](practice/cicd/)
    * [12.1 部署jenkins](practice/cicd/deploy-jenkins.md)
    * [12.2 pipeline](practice/cicd/apply-k8s-plugins.md)
    * [12.3 案例](practice/cicd/example.md)
    * [12.4 git-parameter](practice/cicd/git-parameter-example.md)
  * [13. Istio](practice/istio/)
    * [13.1 部署Istio](practice/istio/istio-install.md)
  * [14. kompose](practice/kompose/)
  * [15. Tidb](practice/tidb/)
  * [16. cert-manager](practice/cert-manager/)
  * [17. kube-bench](practice/kube-bench/)
  * [18. kernel-update](practice/kernel/)
    * [18.1 CentOS](practice/kernel/CentOS.md)
  * [19. containerd](practice/containerd/)
  * [20. kaniko](practice/kaniko/)
  * [21. loki日志收集](practice/loki/)
