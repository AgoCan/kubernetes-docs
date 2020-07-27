# 手动部署mysql

基础环境
```
centos 7.6
2内存
2核
```

下载二进制

这里使用的是清华源
[my.cnf](https://kubernetes.hankbook.cn/manifests/example/mysql/my.cnf)  
[mysql.server](https://kubernetes.hankbook.cn/manifests/example/mysql/mysql.server)  
```bash
# 安装依赖
yum install libaio -y
# 部署mysql
wget https://mirrors.tuna.tsinghua.edu.cn/mysql/downloads/MySQL-5.7/mysql-5.7.25-linux-glibc2.12-x86_64.tar.gz
tar xf mysql-5.7.25-linux-glibc2.12-x86_64.tar.gz
mv mysql-5.7.25-linux-glibc2.12-x86_64 /usr/local/mysql-5.7.25
# 做软连接是为了一步直接拿到版本号
ln -s /usr/local/mysql-5.7.25 /usr/local/mysql
# 创建用户
useradd -M -s /sbin/nologin -r mysql
chown -R mysql.mysql /usr/local/mysql*
mkdir -p /data/mysql
chown -R mysql.mysql /data/mysql

cd /usr/local/mysql/bin
# 下载my.cnf然后进行替换，自行更改对应的配置文件
# 替换完my.cnf然后，然后重启
./mysqld --initialize --user=mysql --basedir=/usr/local/mysql --datadir=/data/mysql
echo export PATH=/usr/local/mysql/bin:$PATH >> /etc/profile
source /etc/profile
cd /usr/local/mysql/support-files
# 修改basedir和datadir，可以选择直接下载,然后使用vimdiff进行匹配
# vim mysql.server
# basedir=/usr/local/mysql
# datadir=/data/mysql
chmod +x mysql.server
mv mysql.server /etc/init.d/mysqld
/etc/init.d/mysqld start
# 默认密码在/data/mysql/error.log
grep password /data/mysql/error.log
# 在外面进行修改命令,不推荐
mysql --connect-expired-password -p'*luHfpXgR7pg' -e "alter user root@localhost identified by 'passwd';"
# 进入数据库后修改密码
> alter user root@localhost identified by 'passwd';
```

# 部署主从
主从必备，打开`binlog`日志和不同的`server-id`   
在从节点也部署一个相同的mysql

my.cnf的 `server-id` 两个配置不能一致，故把从节点的`server-id`替换

以下是mysql交互命令
```
# 添加从库账户
grant replication slave on *.* to 'rep'@'10.10.10.%' identified by '123456';
flush privileges;
# 锁库 不让数据在进行写入
flush table with read lock;
# 记录信息
show master status;
show variables like "%timeout%";
```
bash
```bash
mysqldump -uroot -ppasswd  -A -B --events --set-gtid-purged=OFF |gzip>/opt/rep.sql.gz
# 分发到从节点上
scp /opt/rep.sql.gz 10.10.10.6:~/rep.sql.gz
```
mysql
```
# 如果锁库。记得打开
unlock tables;
```

从节点bash

```
zcat rep.sql.gz |mysql -uroot -ppasswd
```

从节点mysql

```
CHANGE MASTER TO
MASTER_HOST='192.168.1.251',
MASTER_PORT=3306,
MASTER_USER='rep',
MASTER_PASSWORD='123456',
MASTER_LOG_FILE='mybinlog.000002',
MASTER_LOG_POS=1285;

start slave;
# 查看
[mysql]:show slave status\G
#出现两个yes就好了
#Slave_IO_Running: Yes
#Slave_SQL_Running: Yes
```
