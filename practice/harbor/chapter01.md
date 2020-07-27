# 通过docker-compose进行部署harbor

安装docker

`docker-compose` 可以选择直接下载二进制，也可以使用`python`的方式安装

python方式安装
```
yum install python-pip python-devel gcc gcc-c++ -y
pip install docker-compose
```
直接下载二进制  
https://github.com/docker/compose  
```
wget https://github.com/docker/compose/releases/download/1.25.0/docker-compose-Linux-x86_64
chmod +x docker-compose-Linux-x86_64
mv docker-compose-Linux-x86_64 /usr/bin/docker-compose
```

上harbor的github下载离线包  
https://github.com/goharbor/harbor  
```bash
wget https://github.com/goharbor/harbor/releases/download/v1.9.3/harbor-offline-installer-v1.9.3.tgz
tar xf harbor-offline-installer-v1.9.3.tgz
cd harbor
# 修改harbor密码
sed -i 's#Harbor12345#example#g' harbor.yml
# 修改域名，修改域名需要注意，端口号无论是否修改， 域名都不带端口号，不然docker login 会出现no such host
sed -i 's#reg.mydomain.com#10.10.10.5#g' harbor.yml
# 修改数据地址
sed -i 's#data_volume: /data#data_volume: /data-data#g' harbor.yml
# 修改数据库密码
sed -i 's#root123#example#g' harbor.yml
# 安装harbor
./install.sh
```
