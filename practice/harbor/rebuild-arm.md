# 重新编译harbor

> ps: 当前不支持2.3.x的编译，因为swagger的工具没有支持arm系统的

参考文档：
- https://goharbor.io/docs/2.3.0/build-customize-contribute/compile-guide/
- https://bbs.huaweicloud.com/forum/thread-49256-1-1.html

> ps: 以下均由[汉克书](https://hankbook.cn)编写

```bash
cd /opt

git clone https://github.com/goharbor/harbor.git
cd harbor

# 切换到分支
git checkout -b hankv2.2.3 v2.2.3

cp -a make/harbor.yml.tmpl make/harbor.yml
# 替换成3.0镜像
# harbor的Dockerfile的基础镜像会导致安装的版本不一致。例如下面的photon改成4.0的话，系统就跑不起来，而nginx如果要用1.9.x版本，就得去找到单独的dockerfile进行修改
find ./ -type f -name "Dockerfile*" | xargs sed -i "s#photon:2.0#photon:3.0#g"
#
```

[5.6 替换harbor的nginx镜像](/practice/harbor/update-nginx.md)


openssl
```bash
cd /root
openssl rand -writerand .rnd
cd /opt/harbor
mkdir -p cert
cd cert
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -days 36500 -out ca.crt -subj "/CN=hankbook.cn"
openssl req -newkey rsa:2048 -nodes -sha256 -keyout server.key -out server.csr -subj "/C=CN/ST=Shenzhen/O=hankbook/OU=unicorn/CN=hankbook.cn"

# IP是否添加还需要考虑
ipaddress=$(ip a | grep 192 | awk '{print $2}' | awk -F "/" '{print $1}')
echo subjectAltName = IP:${ipaddress} > extfile.cnf
#
echo subjectAltName = DNS.1:hankbook.cn > extfile.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 36500 -extfile extfile.cnf -out server.crt

cd ..
sed -i 's#reg.mydomain.com#192.168.13.103#g' make/harbor.yml
# 暂时不替换成证书的方式，所以需要注释
sed -i 's#/your/certificate/path#/opt/harbor/cert/server.crt#g' make/harbor.yml
sed -i 's#/your/private/key/path#/opt/harbor/cert/server.key#g' make/harbor.yml
```

修改 `MakeFile`

```bash
# 替换成国内源会报错
#sed -i 's#NPM_REGISTRY=https://registry.npmjs.org#NPM_REGISTRY=http://mirrors.cloud.tencent.com/npm/#g' ./Makefile
version=v2.2.3
sed -i "s#VERSIONTAG=dev#VERSIONTAG=$version#g" ./Makefile
sed -i "s#BASEIMAGETAG=dev#BASEIMAGETAG=$version#g" ./Makefile
sed -i "s#PULL_BASE_FROM_DOCKERHUB=true#PULL_BASE_FROM_DOCKERHUB=false#g" ./Makefile
# sed -i "s#NOTARYFLAG=false#NOTARYFLAG=true#g" ./Makefile
# sed -i "s#TRIVYFLAG=false#TRIVYFLAG=true#g" ./Makefile
# sed -i "s#CHARTFLAG=false#CHARTFLAG=true#g" ./Makefile
# sed -i "s#DEVFLAG=true#DEVFLAG=false#g" ./Makefile
sed -i "s#BUILDBIN=false#BUILDBIN=true#g" ./Makefile
```

修改 `make/photon/Makefile`

```bash
# 删除 --no-cache 参数
sed -i 's#--no-cache##g' make/photon/Makefile
```

修改 `make/photon/exporter/Dockerfile`

```bash
sed -i 's#GOARCH=amd64#GOARCH=arm64#g' make/photon/exporter/Dockerfile
# 添加一个proxy
sed -i '9aENV GOPROXY="https://goproxy.io"' make/photon/exporter/Dockerfile
```

修改 `make/photon/notary/binary.Dockerfile`

```bash
# 添加一个proxy
sed -i '2aENV GOPROXY="https://goproxy.io"' make/photon/notary/binary.Dockerfile
```

修改 `make/photon/portal/Dockerfile`

```bash
#sed -i 's#npm_registry=https://registry.npmjs.org#npm_registry=http://mirrors.cloud.tencent.com/npm/#g' make/photon/portal/Dockerfile
```

修改 `make/photon/registry/Dockerfile.binary`

```bash
# 添加一个proxy
sed -i '2aENV GOPROXY="https://goproxy.io"' make/photon/registry/Dockerfile.binary
```

修改 `tools/swagger/Dockerfile`

```bash
sed -i '2aENV GOPROXY="https://goproxy.io"' tools/swagger/Dockerfile
sed -i 's#swagger_linux_amd64#swagger_linux_arm64#g' tools/swagger/Dockerfile
```

## 构建

```bash
make package_offline
```

## save镜像

```bash
# version 是一开始就定义的
docker save  `docker images | grep $version | awk '{print $1":"$2}'` goharbor/swagger:v0.21.0 | gzip > harbor.$version.tar.gz
```

## faq

下面的报错信息是因为 swagger 用的是 x86
```
Successfully tagged goharbor/swagger:v0.21.0
build swagger image successfully
generate all the files for API from api/v2.0/swagger.yaml
standard_init_linux.go:228: exec user process caused: exec format error
Makefile:322: recipe for target 'gen_apis' failed
make: *** [gen_apis] Error 1
```

下面的报错是因为env放在FROM前面了

```
compiling and building image for exporter...
Sending build context to Docker daemon  198.8MB
Error response from daemon: no build stage in current context
/root/harbor/make/photon/Makefile:256: recipe for target '_compile_and_build_exporter' failed
make[1]: *** [_compile_and_build_exporter] Error 1
make[1]: Leaving directory '/root/harbor'
Makefile:403: recipe for target 'build' failed
make: *** [build] Error 2
```
