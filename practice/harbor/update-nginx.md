> 因为安全缘故，而harbor的基础镜像最新的photon只能下载到nginx的1.9.x版本，所以需要替换nginx到最新的版本

1. 第一步，先部署好harbor，或者解压harbor 手动load镜像。
```
data=$(ls harbor.*tar.gz)
cd harbor;docker load < $data
```
2. 编译自己的nginx镜像，基于任意的nginx官方镜像版本, 因为nginx的默认ID是101、 nginx的默认用户是root和docker-entrypoint.sh的原因，会导致权限报错，所以改成nginx用户

  ```
  FROM nginx:1.21.3
  RUN apt-get update && apt-get install -y cron rsyslog logrotate libvshadow-utils sudo
  RUN userdel nginx && groupadd -r -g 10000 nginx && useradd --no-log-init -r -g 10000 -u 10000 nginx
  HEALTHCHECK CMD curl --fail -s http://localhost:8080 || exit 1
  USER nginx
  ```

  ```
  docker build -t goharbor/nginx-photon:v2.2.3 .
  ```
3. 保存镜像到harbor的镜像里面

  ```
  for image in `docker images | grep gohar | awk '{print $1":"$2}'`;do echo $image >> image.txt ; done
  docker save `cat image.txt` > $data # 后面的命令可以自己根据harbor的版本进行替换 harbor.v2.3.3.tar.gz
  ```
