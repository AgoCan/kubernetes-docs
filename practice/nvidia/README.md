# 此gpu主要是nvidia

github: https://github.com/nvidia

使用nvidia插件的时候，必须先给`docker`的`daemon.json`给配置好，并且安装好`nvidia-docker2`  
nvidia-device-plugins: https://github.com/NVIDIA/k8s-device-plugin

```bash
wget https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta4/nvidia-device-plugin.yml
kubectl apply -f nvidia-device-plugin.yml
```
[nvidia-device-plugin.yml](https://kubernetes.hankbook.cn/manifests/example/nvidia/nvidia-device-plugins.yaml)  

测试pod

[nvidia-pod-test.yaml](https://kubernetes.hankbook.cn/manifests/example/nvidia/nvidia-pod-test.yaml)  

**给服务器打上标签**  

```bash
# 命令   标签  类型  类型对应的名称       key=value
kubectl label node k8s01.example.com machine=gpu
kubectl get nodes --show-labels
```

**创建deployment的时候**  
```bash
kubectl  explain deployment.spec.template.spec.nodeSelector
```

或者使用污点的方式进行区别部署


orion: 虚拟化gpu

https://github.com/virtaitech/orion    
https://virtai.tech    

参考文档：  

https://kubernetes.io/zh/docs/tasks/manage-gpus/scheduling-gpus/  

https://github.com/NVIDIA/k8s-device-plugin
