# faq报错及解决方案
## 用户名登陆密码错误

主要是两个。一个是admin的账户密码被改了，另外一个是因为数据库连接密码错误

需要去`harbor-log`下的`/var/log/docker/`下面查看一下日志。或者`docker ps `会看到`apiserver`一直处于restart的状态

一旦是处于restart的状态，那么请用下面的方式解决默认密码（默认密码设置是harbor.yaml或者早期的harbor是 harbor.cfg）

```bash
# 进入容器内
docker exec -it harbor-db /bin/bash
# 以下操作都在容器内部
# 使用密码方式测试一下
psql -h postgresql -d postgres -U postgres
# 免密登陆
psql -U postgres -d postgres -h 127.0.0.1 -p 5432
# 修改登陆密码，登陆密码默认是root123
alter role postgres with password 'root123';
# 下面是修改修改harbor的admin密码
# 连接数据库
\c registry
# 查看admin的信息，使用单引号，双引号不认
select * from harbor_user where username='admin';
# 修改密码，其中密码的值，请自己用相同的版本号部署在本地，然后查询一下
update harbor_user set password='c37c3e7020f0493139d28a6426257b79', salt='qamm0okqhfn3vjysadwhk290cftrae92' where username='admin';
# 退出数据库，两个方法都行，或者使用快捷键ctrl+d
\q
exit
# 后续重新安装一遍harbor即可

```
