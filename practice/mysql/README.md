# mysql

```bash
# 裸docker 启动和连接
docker run --name mysql8019 -p 3306:3306 -e MYSQL_ROOT_PASSWORD=123456 -d mysql:8.0.19
# 连接
docker run -it --network host --rm mysql:8.0.19 mysql -h127.0.0.1 -P3306 --default-character-set=utf8mb4 -uroot -p
```




参考文档： https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/
