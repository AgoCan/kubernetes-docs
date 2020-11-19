# CentOS升级内核

```
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
# C8
#yum install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
# C7
yum install https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
# C6
#yum install https://www.elrepo.org/elrepo-release-6.el6.elrepo.noarch.rpm

#yum install kmod-r8168
#yum --disablerepo=\* --enablerepo=elrepo install kmod-nvidia
# 载入elrepo-kernel元数据
yum --disablerepo=\* --enablerepo=elrepo-kernel repolist
# 查看可用包
yum --disablerepo=\* --enablerepo=elrepo-kernel list kernel*
# 安装最新版本的kernel, 其中ml是稳定版本。现在安装是5.9.9版本。   lt是4.4.244版本 kernel-lt.x86_64
yum --disablerepo=\* --enablerepo=elrepo-kernel install  kernel-ml.x86_64  -y
yum --disablerepo=\* --enablerepo=elrepo-kernel install  kernel-ml-devel.x86_64  -y
# 删除旧版本工具包
yum remove kernel-tools-libs.x86_64 kernel-tools.x86_64  -y
# 安装新版本工具包
yum --disablerepo=\* --enablerepo=elrepo-kernel install kernel-ml-tools.x86_64  -y
# 查看内核插入顺序
# 说明：默认新内核是从头插入，默认启动顺序也是从0开始（当前顺序还未生效），或者使用：
awk -F \' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg
# 查看当前实际启动顺序
grub2-editenv list
# 设置默认启动
grub2-set-default 'CentOS Linux (4.20.12-1.el7.elrepo.x86_64) 7 (Core)'
grub2-editenv list
# 或者直接设置数值
grub2-set-default 0
grub2-editenv list
# 重启并检查
reboot
uname -r
```

参考：
- https://www.kernel.org/
- https://rpmfind.net/linux/rpm2html/search.php?query=kernel-devel
- http://elrepo.org/tiki/HomePage
