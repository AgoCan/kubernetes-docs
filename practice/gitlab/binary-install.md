# 二进制部署gitlab
[官方文档](https://about.gitlab.com/install/)


安装依赖

```bash
yum install -y curl policycoreutils-python openssh-server
systemctl enable sshd
systemctl start sshd
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
systemctl reload firewalld
# 直接关闭防火墙
systemctl stop firewalld
systemctl disable firewalld
```

安装Postfix服务,如果自己搭建`SMTP`，就没必要部署了

```bash
yum install -y postfix
systemctl enable postfix
systemctl start postfix
```

然后官方推荐的是 **专业版本** 的部署方式，而且国外的源部署比较慢，这就使用清华源进行部署  


清华大学文档  https://mirror.tuna.tsinghua.edu.cn/help/gitlab-ce/

```bash
cat > /etc/yum.repos.d/gitlab-ce.repo << \EOF
[gitlab-ce]
name=Gitlab CE Repository
baseurl=https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/yum/el$releasever/
gpgcheck=0
enabled=1
EOF

yum install -y gitlab-ce
```

## 修改配置文件

修改 `/etc/gitlab/gitlab.rb`

- 修改exrernal_url：改成机器域名或者IP地址

```
external_url 'http://10.10.10.5'
```

- 修改 unicorn 端口

```
# unicorn['listen'] = 'localhost'
# unicorn['port'] = 8080
unicorn['port'] = 8090
```

- 修改nginx端口

```
# nginx['listen_port'] = nil
nginx['listen_port'] = 9999
```

查看

```
grep -Ev "^#|^$" /etc/gitlab/gitlab.rb
```

- 重载配置文件，使配置文件生效，第一次比较慢，并且会把服务给启动

```
gitlab-ctl reconfigure
```
通过访问 `http://10.10.10.5:9999` 即可访问后台管理页面


- 过程中可能会报错"GitLab Error: Error executing action create on resource 'group[gitlab-www]'" 需要修改username, 将配置文件中username改为"gitlab"

```
user['username'] = "gitlab"
user['group'] = "gitlab"
```

命令
```bash
# 重载配置文件
gitlab-ctl reconfigure  
# 查看状态
gitlab-ctl status
# 停止服务
gitlab-ctl stop
# 启动服务
gitlab-ctl start
# 查看日志
gitlab-ctl tail
# 首次登陆
```

忘记密码

```bash
# 初始化密码
gitlab-rails console production

# 后面的操作已经使在数据库，请小心操作
# 查找root用户
u=User.where(id:1).first
# 修改密码
u.password='123456'
# 再次确认
u.password_confirmation='123456'
```

挂载路径的选择

```bash
# 该路径是gitlab的默认存储路径
/var/opt/gitlab
```

参考文档:

https://www.jianshu.com/p/b788d23abbd6  
