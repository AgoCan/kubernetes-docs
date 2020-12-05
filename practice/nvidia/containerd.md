# 在containerd下安装nvidia-runtime

安装`nvidia-container-toolkit`即可

修改`containerd`的配置参数
```
...
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "overlayfs"
      default_runtime_name = "runc"
      no_pivot = false
...
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runtime.v1.linux" # 将此处 runtime_type 的值改成 io.containerd.runtime.v1.linux
...
  [plugins."io.containerd.runtime.v1.linux"]
    shim = "containerd-shim"
    runtime = "nvidia-container-runtime" # 将此处 runtime 的值改成 nvidia-container-runtime
...
```
