# FAQ

## 问题1，mtu数值问题

感谢 ucloud的工作人员，对此问题的帮助

参考文档： https://docs.projectcalico.org/v2.2/usage/configuration/mtu

**发现错误，按顺序一次次排查下去的**

假设有A B C D E 五个节点， ingress-controller对应的pod 在A节点上面

服务是 ingress -> 前端代码  -> 后端代码

1. ingress和配置好参数后，访问出现504
2. 查看镜像的问题，发现镜像都是通的
3. 有时候能访问到前端代码，但是  api 却是504或者503错误
4. 尝试把所有的pod都扔到A节点，发现都可以访问了，全部都是通的
5. 尝试 在5个节点一起curl 这个service对应的内网的80端口，发现只有pod所处的机器才会访问到Endpoint
6. 这一步骤不是是重装后发现的，一开始启动的时候，镜像是旧的，因为后端的所有配置信息都是错误的。所以任意一个节点都可以访问到，且报错502。然后set image 之后替换镜像就不能访问了


排查思路： ucloud的工作人员提供

0. 首先由我确认，镜像是没有任何问题的
1. 排查思路如发现问题的步骤
2. 然后自己启动一个nginx的，发现是可以访问的，而且做了set image 修改镜像后也没发现任何问题
3. tcpdump -nq -s 0 host xxx 抓包，发现此网卡上有http数据返回记录，执行ip route get xxx，发现是从主机tunl0 网卡出去的，于是抓包tunl0网卡，发现此网卡也有数据返回记录，此时基本排除镜像问题，容器与主机之间的网络问题
4. 同时抓取A和B主机的tunl0网卡，发现从B返回A的大数据包都没收到，其余小数据包都没问题，于是又去抓了自己的测试nginx服务，默认700多bytes也没问题，然后nginx服务返回页面大小改为1500bytes，发现也curl不通了，此时排除客户说的set image操作导致的问题，把问题定位于k8s网络方案与MTU的设置
5. 使用的是默认calico设置，MTU为GCE使用的1440，了解了一下calico MTU设置， 需要设置为network mtu - 20，20个字节是calico 需要的，此时想到ucloud mtu默认为1454而不是1460， 减20为1434， 同时测试ping -s 1407到1412是不通的，其余正常，icmp包28个字节加上数据包，也就是说1435到1440是不通的，感觉跟猜测对的上，于是修改了集群configmap里calico的mtu 值，重启所有calico pod与业务pod，使其生效，问题解决

## 问题2: 日志报错找不到网卡，node节点起不来

下面的日志 网卡找不到 `[enp2s0]`

```
[root@test15 ~]# kubectl logs  calico-node-zdtnr -n kube-system
2020-03-11 09:11:36.015 [INFO][8] startup.go 259: Early log level set to info
2020-03-11 09:11:36.015 [INFO][8] startup.go 275: Using NODENAME environment for node name
2020-03-11 09:11:36.015 [INFO][8] startup.go 287: Determined node name: 192.168.1.146
2020-03-11 09:11:36.016 [INFO][8] k8s.go 228: Using Calico IPAM
2020-03-11 09:11:36.016 [INFO][8] startup.go 319: Checking datastore connection
2020-03-11 09:11:36.062 [INFO][8] startup.go 343: Datastore connection verified
2020-03-11 09:11:36.062 [INFO][8] startup.go 98: Datastore is ready
2020-03-11 09:11:36.091 [INFO][8] startup.go 385: Initialize BGP data
2020-03-11 09:11:36.092 [WARNING][8] startup.go 631: Unable to auto-detect an IPv4 address using interface regexes [enp2s0]: no valid host interfaces found
2020-03-11 09:11:36.092 [WARNING][8] startup.go 407: Couldn't autodetect an IPv4 address. If auto-detecting, choose a different autodetection method. Otherwise provide an explicit address.
2020-03-11 09:11:36.092 [INFO][8] startup.go 213: Clearing out-of-date IPv4 address from this node IP=""
2020-03-11 09:11:36.117 [WARNING][8] startup.go 1122: Terminating
Calico node failed to start
[root@test15 ~]#
```

解决:

用`ip a`找到节点的网卡名称

修改calico.yaml的文件。

查找到 `IP_AUTODETECTION_METHOD`, 并且修改interface的网卡为节点机器的名称。

```yaml
            - name: IP_AUTODETECTION_METHOD
              value: "interface=eno1"
```
