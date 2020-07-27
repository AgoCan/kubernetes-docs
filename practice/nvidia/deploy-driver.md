# 容器使用nvidia
1. 安装docker
2. 安装nvidia的驱动
3. 安装nvidia-docker2
4. 使用命令进行启动

> 提示： 宿主机没必要安装cuda和cudnn的包，build的时候不能使用`--runtime=nvidia`，要构建镜像的时候使用`nvidia`，文档下方有解释

# 在centos部署nvidia
切换到命令行
```bash
init 3
```

安装依赖
```bash
yum -y install gcc kernel-devel
```
关闭集显
```bash
sed -i 's@blacklist nvidiafb@#blacklist nvidiafb@g' /lib/modprobe.d/dist-blacklist.conf
echo blacklist nouveau >> /lib/modprobe.d/dist-blacklist.conf
echo options nouveau modeset=0 >> /lib/modprobe.d/dist-blacklist.conf
mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.bak
/usr/sbin/dracut /boot/initramfs-$(uname -r).img $(uname -r)
```
关闭集显后需要重启服务器
```bash
reboot
```
检查集显是否关闭成功
```bash
lsmod ｜ grep nouveau
```

安装驱动
```bash
# 驱动下载地址https://www.geforce.cn/drivers
# 请选择自己需要的版本号
# 需要加上权限
chmod +x NVIDIA-Linux-x86_64-418.67.run
# 不使用命令 直接复制 上面地址也可以在浏览器直接下载
./NVIDIA-Linux-x86_64-418.67.run --no-opengl-files
```

# 安装nvidia-docker2
https://github.com/NVIDIA/nvidia-docker  
github,可以在readme就轻松找到安装内容

以下是针对centos7的部署

```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | sudo tee /etc/yum.repos.d/nvidia-docker.repo

yum install -y nvidia-container-toolkit nvidia-docker2
systemctl restart docker
```


安装之后会配置好`/etc/docker/daemon.json`
```
# 暂无机器，
```
修改后
```json
{
"insecure-registries":[],
"registry-mirrors": ["https://docker.mirrors.ustc.edu.cn/"],
"max-concurrent-downloads": 10,
"max-concurrent-uploads": 20,
"default-runtime": "nvidia",
"runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }

}
```

```bash
# 启动命令
# 方式1
nvidia-docker run -it --runtime=nvidia ubuntu:16.04 bash
# 方式2
nvidia-docker run -it -e NVIDIA_VISIBLE_DEVICES=all ubuntu:16.04 bash
# 方式3
# 在daemon.json配置了 default-runtime=“nvidia”
docker run -it -e NVIDIA_VISIBLE_DEVICES=all ubuntu:16.04 bash

# build 镜像(还需要自行测试)
nvidia-docker build -t nvidia-test:v1 .
docker build -e NVIDIA_VISIBLE_DEVICES=all -t nvidia-test:v1 .
```
